# Phase 1: AWS Organizations and Control Tower Foundation
# This creates the foundational AWS Organizations structure and enables Control Tower

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
  
  backend "s3" {
    # Backend configuration provided via -backend-config
    # bucket         = "terraform-state-project-wray06ia"
    # key            = "phase1-foundation/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks-project"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.home_region
}

# Compute trusted access principals based on whether Terraform manages Control Tower
locals {
  base_principals = [
    "cloudtrail.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com"
  ]
  ct_principals = [
    "controltower.amazonaws.com",
    "config.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com"
  ]
  computed_principals = var.enable_control_tower ? concat(local.base_principals, local.ct_principals) : local.base_principals
}

# Create AWS Organization
resource "aws_organizations_organization" "main" {
  # Manage trusted access principals conditionally.
  # - When enable_control_tower = false (console setup/import path): keep CT/Config principals out to avoid conflicts
  # - When enable_control_tower = true  (Terraform-managed CT): include CT/Config/StackSets principals to prevent drift
  aws_service_access_principals = local.computed_principals

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
}

# Security OU
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = {
    Name        = "Security OU"
    Environment = "management"
    Purpose     = "security-accounts"
  }
}

# Workloads OU
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = {
    Name        = "Workloads OU"
    Environment = "management"
    Purpose     = "application-accounts"
  }
}

# Shared Services OU
resource "aws_organizations_organizational_unit" "shared_services" {
  name      = "SharedServices"
  parent_id = aws_organizations_organization.main.roots[0].id

  tags = {
    Name        = "Shared Services OU"
    Environment = "management"
    Purpose     = "shared-infrastructure"
  }
}

# Ensure Control Tower Service-Linked Role exists (required for landing zone creation)
resource "aws_iam_service_linked_role" "control_tower" {
  aws_service_name = "controltower.amazonaws.com"
}

# Control Tower Landing Zone
resource "aws_controltower_landing_zone" "main" {
  count = var.enable_control_tower ? 1 : 0
  manifest_json = jsonencode({
    governedRegions = var.governed_regions
    organizationStructure = {
      security = {
        name = aws_organizations_organizational_unit.security.name
      }
    }
    centralizedLogging = {
      accountId = aws_organizations_account.log_archive.id
      configurations = {
        loggingBucket = {
          retentionConfiguration = {
            retentionPeriod = var.log_retention_days
          }
        }
        accessLoggingBucket = {
          retentionConfiguration = {
            retentionPeriod = var.access_log_retention_days
          }
        }
      }
    }
    securityRoles = {
      accountId = aws_organizations_account.audit.id
    }
    accessManagement = {
      enabled = true
    }
  })

  version = "3.3"

  tags = {
    Name        = "${var.organization_name} Landing Zone"
    Environment = "management"
    Purpose     = "control-tower"
  }
}

# Log Archive Account (created by Control Tower but we need to reference it)
resource "aws_organizations_account" "log_archive" {
  name                       = "Log Archive"
  email                      = var.log_archive_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.security.id

  tags = {
    Name        = "Log Archive Account"
    Environment = "security"
    Purpose     = "centralized-logging"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Audit Account (created by Control Tower but we need to reference it)
resource "aws_organizations_account" "audit" {
  name                       = "Audit"
  email                      = var.audit_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.security.id

  tags = {
    Name        = "Audit Account"
    Environment = "security"
    Purpose     = "compliance-auditing"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Security Tooling Account
resource "aws_organizations_account" "security_tooling" {
  name                       = "Security Tooling"
  email                      = var.security_tooling_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.security.id

  tags = {
    Name        = "Security Tooling Account"
    Environment = "security"
    Purpose     = "security-tools"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Unix Dev Account
resource "aws_organizations_account" "unix_dev" {
  name                       = "Unix Dev"
  email                      = var.unix_dev_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "Unix Dev Account"
    Environment = "development"
    Purpose     = "unix-development"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Unix Staging Account
resource "aws_organizations_account" "unix_staging" {
  count                      = 0  # Deferred for tutorial cost control
  name                       = "Unix Staging"
  email                      = var.unix_staging_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "Unix Staging Account"
    Environment = "staging"
    Purpose     = "unix-staging"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Unix Prod Account
resource "aws_organizations_account" "unix_prod" {
  count                      = 0  # Deferred for tutorial cost control
  name                       = "Unix Prod"
  email                      = var.unix_prod_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "Unix Prod Account"
    Environment = "production"
    Purpose     = "unix-production"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Network Account
resource "aws_organizations_account" "network" {
  count                      = 0  # Deferred for tutorial cost control
  name                       = "Network"
  email                      = var.network_email
  # iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.shared_services.id

  tags = {
    Name        = "Network Account"
    Environment = "shared"
    Purpose     = "centralized-networking"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Monthly cost budget with email alerts (management account)
resource "aws_budgets_budget" "monthly_cost" {
  name         = "MonthlyCostBudget"
  budget_type  = "COST"
  limit_amount = var.budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }
}
