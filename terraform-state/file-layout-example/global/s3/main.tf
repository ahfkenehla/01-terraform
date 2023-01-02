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

resource "aws_s3_bucket" "terraform_state" {
  bucket = "std01-terraform-state"

  # 버킷의 삭제를 허용하지 않는다.
  #  lifecycle {
  #    prevent_destroy = true
  #  }
  force_destroy = true
}
# 코드 이력을 관리하기 위해 상태 파일의 버전 관리를 활성화한다. 
resource "aws_s3_bucket_versioning" "terraform_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 서버측 암호화를 활성화한다.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-encryption" {
  bucket = aws_s3_bucket.terraform_state.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 다이나모 DB 테이블 생성
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "std01-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
