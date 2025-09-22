# Variables for Staging Environment

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "unix-workload"
}

variable "operating_system" {
  description = "Operating system to deploy (freebsd, rhel)"
  type        = string
  default     = "freebsd"
}

variable "custom_ami_id" {
  description = "Custom AMI ID for RHEL gold images (required when using rhel)"
  type        = string
  default     = ""
}

variable "workload_type" {
  description = "Type of workload being deployed"
  type        = string
  default     = "ipsec-server"
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

variable "staging_account_id" {
  description = "AWS Account ID for staging environment"
  type        = string
  validation {
    condition     = can(regex("^\\d{12}$", var.staging_account_id))
    error_message = "staging_account_id must be a 12-digit AWS account ID. Tip: run 'terraform output unix_staging_account_id' in landing-zone/phase1-foundation. If it is null, enable the Staging account in Phase 1 (see README 'Enable Staging/Prod/Network later')."
  }
}

# Networking variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.2.1.0/24"
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
