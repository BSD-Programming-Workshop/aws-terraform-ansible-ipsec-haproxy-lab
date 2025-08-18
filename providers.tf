terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # AWS credentials should be configured via:
  # - AWS CLI: aws configure
  # - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
  # - IAM roles (recommended for EC2/ECS)
  # - AWS credentials file: ~/.aws/credentials
}

