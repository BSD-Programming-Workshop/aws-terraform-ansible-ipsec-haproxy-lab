# Phase 2: Security Hardening and Cross-Account IAM
# This sets up MFA-enforced cross-account roles and security policies

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Data source to get organization information
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "landing-zone/phase1-foundation/terraform.tfstate"
    region = var.home_region
  }
}

# Provider for management account
provider "aws" {
  alias  = "management"
  region = var.home_region
}

# Cross-account role for workload account access
resource "aws_iam_role" "cross_account_admin" {
  provider = aws.management
  name     = "CrossAccountAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.management_account_id}:root"
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "Cross Account Admin Role"
    Environment = "management"
    Purpose     = "cross-account-access"
  }
}

# Attach AdministratorAccess policy to cross-account role
resource "aws_iam_role_policy_attachment" "cross_account_admin_policy" {
  provider   = aws.management
  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Enhanced MFA policy for management account users
resource "aws_iam_policy" "enhanced_mfa_policy" {
  provider    = aws.management
  name        = "EnhancedMFAPolicy"
  description = "Enhanced MFA policy for landing zone operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary",
          "iam:ListVirtualMFADevices",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListOrganizationalUnitsForParent"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnCredentials"
        Effect = "Allow"
        Action = [
          "iam:ChangePassword",
          "iam:GetUser",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
          "iam:UpdateAccessKey",
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:DeactivateMFADevice",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:user/$${aws:username}",
          "arn:aws:iam::*:mfa/$${aws:username}"
        ]
      },
      {
        Sid    = "AllowAssumeRoleWithMFA"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.freebsd_dev_account_id}:role/CrossAccountAdminRole",
          "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.freebsd_staging_account_id}:role/CrossAccountAdminRole",
          "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.freebsd_prod_account_id}:role/CrossAccountAdminRole",
          "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.network_account_id}:role/CrossAccountAdminRole",
          "arn:aws:iam::${data.terraform_remote_state.foundation.outputs.security_tooling_account_id}:role/CrossAccountAdminRole"
        ]
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
      {
        Sid    = "AllowGetSessionToken"
        Effect = "Allow"
        Action = [
          "sts:GetSessionToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllExceptUnlessSignedInWithMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "Enhanced MFA Policy"
    Environment = "management"
    Purpose     = "mfa-enforcement"
  }
}

# Landing Zone Administrators group
resource "aws_iam_group" "landing_zone_admins" {
  provider = aws.management
  name     = "LandingZoneAdministrators"
  path     = "/"

  tags = {
    Name        = "Landing Zone Administrators"
    Environment = "management"
    Purpose     = "landing-zone-management"
  }
}

# Attach enhanced MFA policy to administrators group
resource "aws_iam_group_policy_attachment" "landing_zone_admins_mfa" {
  provider   = aws.management
  group      = aws_iam_group.landing_zone_admins.name
  policy_arn = aws_iam_policy.enhanced_mfa_policy.arn
}

# Service Control Policy to enforce MFA across organization
resource "aws_organizations_policy" "enforce_mfa_scp" {
  provider    = aws.management
  name        = "EnforceMFA"
  description = "Enforce MFA for all IAM operations across organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyActionsWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken",
          "iam:ChangePassword",
          "iam:GetAccountPasswordPolicy",
          "iam:GetAccountSummary",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
        Principal = "*"
      }
    ]
  })

  tags = {
    Name        = "Enforce MFA SCP"
    Environment = "management"
    Purpose     = "organization-security"
  }
}

# Attach SCP to workloads OU
resource "aws_organizations_policy_attachment" "workloads_enforce_mfa" {
  provider  = aws.management
  policy_id = aws_organizations_policy.enforce_mfa_scp.id
  target_id = data.terraform_remote_state.foundation.outputs.workloads_ou_id
}

# Attach SCP to shared services OU
resource "aws_organizations_policy_attachment" "shared_services_enforce_mfa" {
  provider  = aws.management
  policy_id = aws_organizations_policy.enforce_mfa_scp.id
  target_id = data.terraform_remote_state.foundation.outputs.shared_services_ou_id
}
