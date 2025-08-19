# Variables for Generic Workload Module

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "unix-workload"
}

variable "operating_system" {
  description = "Operating system to deploy (freebsd, rhel)"
  type        = string
  default     = "freebsd"
  
  validation {
    condition     = contains(["freebsd", "rhel"], var.operating_system)
    error_message = "Operating system must be either 'freebsd' or 'rhel'."
  }
}

variable "custom_ami_id" {
  description = "Custom AMI ID to use (required for RHEL gold images)"
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
  default     = "us-west-2"
}

variable "availability_zone" {
  description = "Availability zone for resources"
  type        = string
  default     = "us-west-2a"
}

# Networking variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
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
