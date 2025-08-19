# AWS Landing Zone with Control Tower

This directory contains the Terraform configuration for a complete AWS Landing Zone implementation using AWS Control Tower.

## Architecture Overview

```
Root Organization (Management Account)
├── Security OU
│   ├── Log Archive Account (auto-created by Control Tower)
│   ├── Audit Account (auto-created by Control Tower)
│   └── Security Tooling Account
├── Workloads OU
│   ├── FreeBSD Dev Account
│   ├── FreeBSD Staging Account
│   └── FreeBSD Prod Account
└── Shared Services OU
    ├── Network Account
    └── DNS Account
```

## Deployment Phases

### Phase 1: Foundation
- AWS Organizations setup
- Control Tower enablement
- Organizational Units (OUs) creation
- AWS account provisioning

### Phase 2: Security Hardening
- Cross-account IAM roles
- MFA enforcement policies
- Service Control Policies (SCPs)

### Phase 3: Workload Deployment
- FreeBSD infrastructure modules
- Environment-specific deployments (dev/staging/prod)
- Ansible configuration management

### Phase 4: Operations
- Centralized logging and monitoring
- Environment promotion pipelines
- Backup and disaster recovery
- Cost optimization

## Modular Architecture

The landing zone uses a modular approach for scalability and maintainability:

```
landing-zone/
├── phase1-foundation/     # AWS Organizations and accounts
├── phase2-security/       # Cross-account roles and policies
├── modules/
│   └── unix-workload/     # Reusable OS-agnostic infrastructure
└── environments/
    ├── dev/               # Development environment
    ├── staging/           # Staging environment
    └── prod/              # Production environment
```

### Unix Workload Module

The `modules/unix-workload/` contains reusable Terraform code for:
- VPC and networking infrastructure
- Security groups with IPSec and SSH access
- OS-agnostic EC2 instance (FreeBSD or RHEL)
- Dynamic AMI lookup for FreeBSD via AWS SSM Parameter Store
- Support for RHEL gold images via custom AMI ID
- Encrypted EBS volumes and IMDSv2 enforcement

### Environment Isolation

Each environment deploys to isolated AWS accounts with unique VPC CIDRs:
- **Dev**: 10.1.0.0/16 - t3.large instance, 20GB storage
- **Staging**: 10.2.0.0/16 - t3.large instance, 20GB storage  
- **Production**: 10.3.0.0/16 - t3.xlarge instance, 40GB storage

## Prerequisites

1. **Root Account Access**: Admin access to the account that will become the management account
2. **Email Addresses**: Unique email addresses for each AWS account to be created
3. **Domain**: Optional - for centralized DNS management
4. **MFA Device**: For secure access to management functions

## Security Model

- **Management Account**: Only for billing and organization management
- **Security Accounts**: Centralized logging, auditing, and security tooling
- **Workload Accounts**: Isolated environments for applications
- **Cross-Account Roles**: MFA-enforced access with least privilege
- **No Long-Lived Credentials**: All access via temporary session tokens

## Quick Start

1. **Bootstrap Backend** (from project root):
   ```bash
   cd bootstrap
   terraform init && terraform apply
   cd ..
   ```

2. **Deploy Foundation**:
   ```bash
   cd landing-zone/phase1-foundation
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your email addresses
   terraform init && terraform apply
   ```

3. **Deploy Security**:
   ```bash
   cd ../phase2-security
   terraform init && terraform apply
   ```

4. **Deploy Workloads** (for each environment):
   ```bash
   # Development environment
   cd ../environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with account IDs from phase1 outputs
   terraform init && terraform apply
   
   # Staging environment
   cd ../staging
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with account IDs from phase1 outputs
   terraform init && terraform apply
   
   # Production environment
   cd ../prod
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with account IDs from phase1 outputs
   terraform init && terraform apply
   ```

5. **Configure with Ansible** (for each deployed environment):
   ```bash
   # From project root, get inventory from terraform output
   cd landing-zone/environments/dev
   terraform output -raw ansible_inventory > ../../../ansible/inventory-dev
   
   # Run ansible playbook
   cd ../../../
   ansible-playbook -i ansible/inventory-dev ansible/site.yml
   ```

## Environment Promotion Workflow

To promote changes through environments:

1. **Develop and Test**: Make changes in dev environment
2. **Validate**: Run tests and validation in dev
3. **Promote to Staging**: Apply same configuration to staging
4. **Production Deployment**: Deploy validated configuration to production

Each environment maintains its own Terraform state and can be deployed independently while using the same underlying module.
