# Variables for Phase 2 Security Configuration

variable "home_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state storage"
  type        = string
  # This will be created in the bootstrap phase
}

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "FreeBSD-Organization"
}
