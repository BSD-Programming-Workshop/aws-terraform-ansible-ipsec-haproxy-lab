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
}

provider "aws" {
  region = var.home_region
}

# Create AWS Organization
resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "controltower.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com"
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  tags = {
    Name        = "${var.organization_name} Organization"
    Environment = "management"
    Purpose     = "root-organization"
  }
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

# Control Tower Landing Zone
resource "aws_controltower_landing_zone" "main" {
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
  iam_user_access_to_billing = "DENY"
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
  iam_user_access_to_billing = "DENY"
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
  iam_user_access_to_billing = "DENY"
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

# FreeBSD Dev Account
resource "aws_organizations_account" "freebsd_dev" {
  name                       = "FreeBSD Dev"
  email                      = var.freebsd_dev_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "FreeBSD Dev Account"
    Environment = "development"
    Purpose     = "freebsd-development"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# FreeBSD Staging Account
resource "aws_organizations_account" "freebsd_staging" {
  name                       = "FreeBSD Staging"
  email                      = var.freebsd_staging_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "FreeBSD Staging Account"
    Environment = "staging"
    Purpose     = "freebsd-staging"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# FreeBSD Prod Account
resource "aws_organizations_account" "freebsd_prod" {
  name                       = "FreeBSD Prod"
  email                      = var.freebsd_prod_email
  iam_user_access_to_billing = "DENY"
  parent_id                  = aws_organizations_organizational_unit.workloads.id

  tags = {
    Name        = "FreeBSD Prod Account"
    Environment = "production"
    Purpose     = "freebsd-production"
    Workload    = "ipsec-server"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Network Account
resource "aws_organizations_account" "network" {
  name                       = "Network"
  email                      = var.network_email
  iam_user_access_to_billing = "DENY"
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
