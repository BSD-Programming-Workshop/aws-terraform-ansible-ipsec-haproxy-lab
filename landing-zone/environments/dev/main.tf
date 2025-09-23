# Unix Development Environment
# Deploys Unix workload (FreeBSD/RHEL) to isolated dev account

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
    # key    = "landing-zone/environments/dev/terraform.tfstate"
    # region = "us-east-1"
  }
}

# Assume role in dev account
provider "aws" {
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_account_id}:role/CrossAccountAdminRole"
  }
}

# Deploy Unix workload (FreeBSD default)
module "freebsd_workload" {
  source = "../../modules/unix-workload"

  environment          = "dev"
  project_name         = var.project_name
  operating_system     = "freebsd"
  custom_ami_id        = null
  workload_type        = "ipsec-server-freebsd"
  aws_region          = var.aws_region
  availability_zone   = var.availability_zone
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  workstation_cidr    = var.workstation_cidr
  instance_type       = var.instance_type
  public_key          = var.public_key
  root_volume_size    = var.root_volume_size
  root_volume_type    = var.root_volume_type
  freebsd_ssm_parameter = var.freebsd_ssm_parameter
  metadata_http_tokens  = var.metadata_http_tokens
}

# Deploy RHEL workload (optional - set rhel_ami_id to enable)
module "rhel_workload" {
  count  = var.rhel_ami_id != null ? 1 : 0
  source = "../../modules/unix-workload"

  environment          = "dev"
  project_name         = var.project_name
  operating_system     = "rhel"
  custom_ami_id        = var.rhel_ami_id
  workload_type        = "ipsec-server-rhel"
  aws_region          = var.aws_region
  availability_zone   = var.availability_zone_rhel
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  workstation_cidr    = var.workstation_cidr
  instance_type       = var.instance_type
  public_key          = var.public_key
  root_volume_size    = var.root_volume_size
  root_volume_type    = var.root_volume_type
}
