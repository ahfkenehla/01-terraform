terraform {
  # Terraform 버전 지정
  required_version = ">= 1.0.0, < 2.0.0"

  # 공급자 지정
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

	backend "s3" {
		bucket = "std01-terraform-state"
			key = "stage/services/webserver-cluster/terraform.tfstate"
			region = "ap-northeast-2"
			dynamodb_table = "std01-terraform-locks"
			encrypt = true
	}
}

provider "aws" {
  region = "ap-northeast-2"
}

# 시작 템플릿 구성
resource "aws_launch_template" "example" {
  name                   = "std01-example"
  image_id               = "ami-06eea3cd85e2db8ce" #Ubuntu 20.04 ver
  instance_type          = "t2.micro"
  key_name               = "std01-key"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(data.template_file.web_output.rendered)
  #filebase64라는 파일 코드값 입력

  lifecycle {
    create_before_destroy = true #기본값은 destroy_before_create / 삭제 안됨
  }
}

# 오토스케일링 그룹 생성
resource "aws_autoscaling_group" "example" {
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  name               = "std01-terraform-asg-example"

  desired_capacity = 1
  min_size         = 1
  max_size         = 2

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB" #EC2와 달리 unhealthy 인스턴스 자동 교체

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest" # 가장 최신버전 템플릿 사용
  }

  tag {
    key                 = "Name"
    value               = "std01-terraform-asg-example"
    propagate_at_launch = true #true가 안되면 배포가 안됨
  }
}

# 로드밸런서 생성
resource "aws_lb" "example" {
  name               = "std01-terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

# 대상그룹 생성
resource "aws_lb_target_group" "asg" {
  name     = "std01-terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id


  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 로드밸런서 리스너 구성
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# 로드밸런서 리스너 규칙
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }


  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# 인스턴스 보안그룹, 8080 오픈
resource "aws_security_group" "instance" {
  name = var.security_group_name

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 인스턴스 보안그룹, 80 오픈
resource "aws_security_group" "alb" {
  name = "std01-terraform-example-alb"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "std01-terraform-state"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "template_file" "web_output" {
  template = file("${path.module}/web.sh")
  vars = {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}
