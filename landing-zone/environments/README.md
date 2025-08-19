# Environment-Specific Deployments

This directory contains environment-specific configurations for deploying Unix workloads (FreeBSD or RHEL) across isolated AWS accounts.

## Directory Structure

```
environments/
├── dev/          # Development environment
├── staging/      # Staging environment  
├── prod/         # Production environment
└── README.md     # This file
```

## Environment Isolation

Each environment deploys to a separate AWS account with its own VPC CIDR ranges:

- **Dev**: 10.1.0.0/16 (Account from phase1 outputs)
- **Staging**: 10.2.0.0/16 (Account from phase1 outputs)  
- **Production**: 10.3.0.0/16 (Account from phase1 outputs)

## Deployment Workflow

### Prerequisites

1. **Landing Zone Foundation**: Deploy phase1-foundation to create AWS accounts
2. **Security Configuration**: Deploy phase2-security to set up cross-account roles
3. **Backend Setup**: Configure S3 backend for each environment

### Environment Deployment Steps

For each environment (dev/staging/prod):

1. **Navigate to environment directory**:
   ```bash
   cd landing-zone/environments/dev  # or staging/prod
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with actual account IDs and settings
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init -backend-config="bucket=your-terraform-state-bucket" \
                  -backend-config="key=landing-zone/environments/dev/terraform.tfstate" \
                  -backend-config="region=us-west-2"
   ```

4. **Deploy infrastructure**:
   ```bash
   terraform plan
   terraform apply
   ```

5. **Configure with Ansible**:
   ```bash
   # Get ansible inventory from terraform output
   terraform output -raw ansible_inventory > inventory
   
   # Run ansible playbook (from project root)
   ansible-playbook -i landing-zone/environments/dev/inventory ansible/site.yml
   ```

## Cross-Account Access

Each environment assumes the `CrossAccountAdminRole` in its respective account. Ensure you have:

1. **MFA-enabled session** in the management account
2. **Proper IAM permissions** to assume cross-account roles
3. **Account IDs** from phase1 foundation outputs

## Environment Promotion

To promote changes through environments:

1. **Test in Dev**: Deploy and validate in development account
2. **Promote to Staging**: Apply same configuration to staging account
3. **Production Deployment**: Deploy validated configuration to production

## Monitoring and Logging

Each environment includes:
- **CloudTrail**: Enabled via Control Tower
- **AWS Config**: Compliance monitoring
- **VPC Flow Logs**: Network traffic monitoring
- **Instance Monitoring**: CloudWatch metrics and logs

## Security Features

- **Account Isolation**: Each environment in separate AWS account
- **Encrypted Storage**: EBS volumes encrypted at rest
- **Network Security**: Restrictive security groups
- **Access Control**: Cross-account roles with MFA enforcement
- **Compliance**: Service Control Policies enforced organization-wide
