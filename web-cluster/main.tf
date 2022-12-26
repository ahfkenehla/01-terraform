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
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_launch_template" "example" {
  name                   = "std01-example"
  image_id               = "ami-06eea3cd85e2db8ce" #Ubuntu 20.04 ver
  instance_type          = "t2.micro"
  key_name               = "std01-key"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = "${base64encode(data.template_file.web_output.rendered)}"
  #filebase64라는 파일 코드값 입력

  lifecycle {
    create_before_destroy = true #기본값은 destroy_before_create / 삭제 안됨
  }
}

resource "aws_autoscaling_group" "example" {
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  name               = "std01-terraform-asg-example"

  desired_capacity = 1
  min_size         = 1
  max_size         = 2

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "std01-terraform-asg-example"
    propagate_at_launch = true #true가 안되면 배포가 안됨
  }
}

resource "aws_security_group" "instance" {
  name = var.security_group_name

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
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

data "template_file" "web_output" {
  template = file("${path.module}/web.sh")
  vars = {
    server_port = var.server_port
  }
}
