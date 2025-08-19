# Variables for AWS Organizations and Control Tower setup

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "FreeBSD-Organization"
}

variable "home_region" {
  description = "Primary AWS region for Control Tower"
  type        = string
  default     = "us-west-2"
}

variable "governed_regions" {
  description = "List of regions governed by Control Tower"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudTrail logs"
  type        = number
  default     = 365
}

variable "access_log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 90
}

# Email addresses for AWS accounts (must be unique)
variable "log_archive_email" {
  description = "Email address for Log Archive account"
  type        = string
  # Example: "aws-log-archive@yourdomain.com"
}

variable "audit_email" {
  description = "Email address for Audit account"
  type        = string
  # Example: "aws-audit@yourdomain.com"
}

variable "security_tooling_email" {
  description = "Email address for Security Tooling account"
  type        = string
  # Example: "aws-security-tooling@yourdomain.com"
}

variable "unix_dev_email" {
  description = "Email address for Unix Dev account"
  type        = string
  # Example: "aws-dev@yourdomain.com"
}

variable "unix_staging_email" {
  description = "Email address for Unix Staging account"
  type        = string
  # Example: "aws-staging@yourdomain.com"
}

variable "unix_prod_email" {
  description = "Email address for Unix Prod account"
  type        = string
  # Example: "aws-prod@yourdomain.com"
}

variable "network_email" {
  description = "Email address for Network account"
  type        = string
  # Example: "aws-network@yourdomain.com"
}
