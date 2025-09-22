# Variables for AWS Organizations and Control Tower setup

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "FreeBSD-Organization"
}

variable "home_region" {
  description = "Primary AWS region for Control Tower"
  type        = string
  default     = "us-east-1"
}

variable "governed_regions" {
  description = "List of regions governed by Control Tower"
  type        = list(string)
  default     = ["us-east-1"]
}

variable "enable_control_tower" {
  description = "If true, Terraform will create the Control Tower landing zone. If false, set up via console and import later."
  type        = bool
  default     = false
}

variable "security_ou_name" {
  description = "Name for the Security (foundational) OU. Set to the exact name created by the CT wizard (e.g., 'Security-Foundation')."
  type        = string
  default     = "Security"
}

variable "access_management_enabled" {
  description = "Whether CT Access Management (IAM Identity Center) should be enabled in the landing zone manifest."
  type        = bool
  default     = false
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

# AWS Budget configuration (for cost alerts)
variable "budget_email" {
  description = "Email address to receive AWS Budget alerts"
  type        = string
}

variable "budget_amount" {
  description = "Monthly cost threshold in USD for the budget alert"
  type        = number
  default     = 20
}
