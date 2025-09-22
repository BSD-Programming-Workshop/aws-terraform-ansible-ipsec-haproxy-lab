# Variables for Phase 2 Security Configuration

variable "home_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state storage"
  type        = string
  # Optional: If unset, Phase 2 will auto-read bucket from backend.hcl in this directory
  default     = ""
}

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "FreeBSD-Organization"
}
