# Outputs for Phase 1 Foundation

output "organization_id" {
  description = "AWS Organization ID"
  value       = aws_organizations_organization.main.id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = aws_organizations_organization.main.arn
}

output "management_account_id" {
  description = "Management account ID"
  value       = aws_organizations_organization.main.master_account_id
}

# Organizational Units
output "security_ou_id" {
  description = "Security OU ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "shared_services_ou_id" {
  description = "Shared Services OU ID"
  value       = aws_organizations_organizational_unit.shared_services.id
}

# Account IDs
output "log_archive_account_id" {
  description = "Log Archive account ID"
  value       = aws_organizations_account.log_archive.id
}

output "audit_account_id" {
  description = "Audit account ID"
  value       = aws_organizations_account.audit.id
}

output "security_tooling_account_id" {
  description = "Security Tooling account ID"
  value       = aws_organizations_account.security_tooling.id
}

output "unix_dev_account_id" {
  description = "Unix Dev account ID"
  value       = aws_organizations_account.unix_dev.id
}

output "unix_staging_account_id" {
  description = "Unix Staging account ID"
  value       = aws_organizations_account.unix_staging.id
}

output "unix_prod_account_id" {
  description = "Unix Prod account ID"
  value       = aws_organizations_account.unix_prod.id
}

output "network_account_id" {
  description = "Network account ID"
  value       = aws_organizations_account.network.id
}

# Control Tower
output "control_tower_landing_zone_identifier" {
  description = "Control Tower Landing Zone identifier"
  value       = aws_controltower_landing_zone.main.identifier
}

# Account mapping for cross-account access
output "account_mapping" {
  description = "Mapping of account names to IDs for cross-account access"
  value = {
    management       = aws_organizations_organization.main.master_account_id
    log_archive      = aws_organizations_account.log_archive.id
    audit           = aws_organizations_account.audit.id
    security_tooling = aws_organizations_account.security_tooling.id
    unix_dev     = aws_organizations_account.unix_dev.id
    unix_staging = aws_organizations_account.unix_staging.id
    unix_prod    = aws_organizations_account.unix_prod.id
    network         = aws_organizations_account.network.id
  }
}
