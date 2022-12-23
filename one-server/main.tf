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

resource "aws_instance" "example" {
  ami           = "ami-06eea3cd85e2db8ce"
  instance_type = "t2.micro"

  tags = {
    Name = "std01-example"
  }

}

output "public-ip" {
	value = aws_instance.example.public_ip
}
