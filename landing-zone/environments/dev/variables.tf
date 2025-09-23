# Variables for Development Environment

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "unix-workload"
}

variable "rhel_ami_id" {
  description = "RHEL AMI ID for deployment (set to enable RHEL instance)"
  type        = string
  default     = null
}

variable "availability_zone_rhel" {
  description = "Availability zone for RHEL instance (different from FreeBSD for testing)"
  type        = string
  default     = "us-east-1b"
}


variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone for resources"
  type        = string
  default     = "us-east-1a"
}

variable "dev_account_id" {
  description = "AWS Account ID for development environment"
  type        = string
  validation {
    condition     = can(regex("^\\d{12}$", var.dev_account_id))
    error_message = "dev_account_id must be a 12-digit AWS account ID. Tip: run 'terraform output unix_dev_account_id' in landing-zone/phase1-foundation to retrieve it."
  }
}

# Networking variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "workstation_cidr" {
  description = "CIDR block for workstation access"
  type        = string
}

# EC2 variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "public_key" {
  description = "Public key content for SSH access"
  type        = string
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

# Workload module pass-throughs
variable "freebsd_ssm_parameter" {
  description = "SSM Parameter for FreeBSD AMI (ZFS or UFS). Example: /aws/service/freebsd/amd64/base/zfs/14.3/RELEASE or /aws/service/freebsd/amd64/base/ufs/14.3/RELEASE"
  type        = string
  default     = "/aws/service/freebsd/amd64/base/zfs/14.3/RELEASE"
}

variable "metadata_http_tokens" {
  description = "IMDS requirement (optional|required). Some FreeBSD images need optional to bootstrap."
  type        = string
  default     = "optional"
}
