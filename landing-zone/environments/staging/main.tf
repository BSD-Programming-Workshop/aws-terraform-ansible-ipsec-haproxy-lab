# Unix Staging Environment
# Deploys Unix workload (FreeBSD/RHEL) to isolated staging account

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"

  backend "s3" {
    # Backend configuration will be provided via backend config file
    # bucket = "your-terraform-state-bucket"
    # key    = "landing-zone/environments/staging/terraform.tfstate"
    # region = "us-west-2"
  }
}

# Assume role in staging account
provider "aws" {
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.staging_account_id}:role/CrossAccountAdminRole"
  }
}

# Deploy Unix workload using module
module "unix_workload" {
  source = "../../modules/unix-workload"

  environment          = "staging"
  project_name         = var.project_name
  operating_system     = var.operating_system
  custom_ami_id        = var.custom_ami_id
  workload_type        = var.workload_type
  aws_region          = var.aws_region
  availability_zone   = var.availability_zone
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  workstation_cidr    = var.workstation_cidr
  instance_type       = var.instance_type
  public_key          = var.public_key
  root_volume_size    = var.root_volume_size
  root_volume_type    = var.root_volume_type
}
