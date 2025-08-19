# AWS Landing Zone with Multi-Account Unix Workloads

This project creates a secure, scalable AWS Landing Zone using Control Tower with isolated accounts for deploying Unix workloads (FreeBSD or RHEL) configured with IPSec.

## Architecture Overview

```
Root Organization (Management Account)
├── Security OU
│   ├── Log Archive Account (auto-created by Control Tower)
│   ├── Audit Account (auto-created by Control Tower)
│   └── Security Tooling Account
├── Workloads OU
│   ├── Unix Dev Account (with dedicated VPC)
│   ├── Unix Staging Account (with dedicated VPC)
│   └── Unix Prod Account (with dedicated VPC)
└── Shared Services OU
    ├── Network Account (reserved for future use)
    └── DNS Account (reserved for future use)
```

## Networking Architecture

**Current Implementation**: Each workload environment creates its own isolated VPC:
- **Dev Environment**: 10.1.0.0/16 VPC in Dev Account
- **Staging Environment**: 10.2.0.0/16 VPC in Staging Account  
- **Production Environment**: 10.3.0.0/16 VPC in Production Account

**Future Enhancement**: The Network Account is provisioned but not currently used. It's reserved for potential centralized networking services like:
- Transit Gateway for inter-VPC connectivity
- Centralized NAT Gateways
- Shared VPC endpoints
- Cross-account DNS resolution

## Prerequisites

1. **AWS Administrative User**: Create an admin IAM user following [AWS best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html)
2. **AWS CLI installed** (version 2.0+)
3. **Terraform installed** (version 1.0+)
4. **Ansible installed** with Python support
5. **7 unique email addresses** for AWS accounts (see Email Setup below)
6. **MFA device** for secure access

## Email Address Setup

AWS requires a unique email address for each account. You need **7 email addresses total**:

### **Required Email Addresses**:
1. `log-archive@yourdomain.com` - Log Archive Account (auto-created by Control Tower)
2. `audit@yourdomain.com` - Audit Account (auto-created by Control Tower)  
3. `security-tooling@yourdomain.com` - Security Tooling Account
4. `unix-dev@yourdomain.com` - Unix Dev Account
5. `unix-staging@yourdomain.com` - Unix Staging Account
6. `unix-prod@yourdomain.com` - Unix Production Account
7. `network@yourdomain.com` - Network Account

### **Proton Pass Aliases (Recommended)**:
If you use Proton Mail, create aliases in Proton Pass that all forward to your main Proton email:
- `aws-log-archive@[your-alias-domain]`
- `aws-audit@[your-alias-domain]`
- `aws-security@[your-alias-domain]`
- `aws-dev@[your-alias-domain]`
- `aws-staging@[your-alias-domain]`
- `aws-prod@[your-alias-domain]`
- `aws-network@[your-alias-domain]`

### **Alternative: Gmail Plus Addressing**:
If you use Gmail, use plus addressing:
- `yourname+aws-log-archive@gmail.com`
- `yourname+aws-audit@gmail.com`
- `yourname+aws-security@gmail.com`
- `yourname+aws-dev@gmail.com`
- `yourname+aws-staging@gmail.com`
- `yourname+aws-prod@gmail.com`
- `yourname+aws-network@gmail.com`

### **Where to Configure**:
Edit `landing-zone/phase1-foundation/terraform.tfvars` with your email addresses.

## Deployment Workflow

### Bootstrap Backend

1. **Create initial AWS CLI configuration**:
   
   First, create an administrative IAM user following [AWS best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html). This user will exist outside the Control Tower implementation and be used throughout the deployment process.
   
   Then create `~/.aws/config` with your admin user credentials:
   ```ini
   [profile bootstrap]
   region = us-west-2
   output = json
   aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
   
   [profile default]
   region = us-west-2
   output = json
   # Will be updated in Phase 3 for MFA workflow
   ```

2. **Bootstrap Terraform backend**:
   ```bash
   cd bootstrap
   export AWS_PROFILE=bootstrap
   terraform init
   terraform apply
   # Note the S3 bucket name from outputs
   cd ..
   ```

### Phase 1: Deploy Landing Zone Foundation

1. **Configure foundation variables**:
   ```bash
   cd landing-zone/phase1-foundation
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your unique email addresses
   ```

2. **Deploy AWS Organizations and accounts**:
   ```bash
   export AWS_PROFILE=bootstrap
   terraform init -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET"
   terraform apply
   # Note the account IDs from outputs - you'll need these for Phase 3
   ```

### Phase 2: Deploy Security Configuration

1. **Deploy cross-account roles and MFA policies**:
   ```bash
   cd ../phase2-security
   export AWS_PROFILE=bootstrap
   terraform init -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET"
   terraform apply
   # This creates: LandingZoneAdministrators group, MFA policies, cross-account roles
   ```

2. **Add your existing admin user to the Landing Zone group**:
   ```bash
   # Add your admin user to the new LandingZoneAdministrators group
   aws iam add-user-to-group \
     --user-name YOUR_ADMIN_USERNAME \
     --group-name LandingZoneAdministrators \
     --profile bootstrap
   ```

3. **Set up MFA device and update AWS CLI configuration**:
   
   Set up MFA device via AWS Console for your admin user, then update `~/.aws/config`:
   ```ini
   [profile bootstrap]
   region = us-west-2
   output = json
   aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
   
   [profile mfa]
   region = us-west-2
   output = json
   aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
   
   [profile default]
   region = us-west-2
   output = json
   # Temporary MFA session tokens go here (updated daily)
   ```

4. **Test MFA workflow**:
   ```bash
   # Get MFA session token with your admin user
   aws sts get-session-token \
     --serial-number arn:aws:iam::MANAGEMENT-ACCOUNT-ID:mfa/YOUR_ADMIN_USERNAME \
     --profile mfa \
     --token-code 123456
   
   # Copy returned credentials to [profile default] section
   ```

### Phase 3: Deploy Workloads to Isolated Accounts

**Note**: After Control Tower deployment, you use cross-account roles instead of direct credentials. Network and DNS accounts are created but not used in the current implementation. Each workload creates its own VPC for maximum isolation.

Choose your target environment (dev/staging/prod):

1. **Configure environment variables**:
   ```bash
   cd ../environments/dev  # or staging/prod
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with:
   # - Account ID from phase1 outputs
   # - Your SSH public key
   # - Your workstation IP/CIDR
   # - Optional: rhel_ami_id to enable RHEL instance alongside FreeBSD
   ```

2. **Deploy workload infrastructure** (uses cross-account role to target account):
   ```bash
   # Use default profile with MFA session tokens
   terraform init -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET"
   terraform apply
   # Deploys FreeBSD instance by default
   # If rhel_ami_id is set, also deploys RHEL instance in same VPC
   ```

3. **Configure with Ansible**:
   ```bash
   # Generate inventory from terraform output (includes all instances)
   terraform output -raw ansible_inventory > ../../../ansible/inventory-dev
   
   # Run ansible playbook from project root
   cd ../../../
   ansible-playbook -i ansible/inventory-dev ansible/site.yml
   # Automatically detects and configures FreeBSD and/or RHEL instances
   ```

## Multi-OS Testing in Dev Environment

The dev environment supports deploying both FreeBSD and RHEL instances simultaneously:

- **FreeBSD instance**: Always deployed (uses AWS SSM parameter for AMI)
- **RHEL instance**: Optional - set `rhel_ami_id` in `terraform.tfvars` to enable
- **Same VPC**: Both instances share networking resources
- **Different AZs**: FreeBSD in us-west-2a, RHEL in us-west-2b
- **Unified Ansible**: Single playbook configures both OS types automatically

## Operating System Support

The infrastructure supports both FreeBSD and RHEL:

- **FreeBSD**: Uses dynamic AMI lookup via AWS SSM Parameter Store
- **RHEL**: Uses custom AMI ID (required for gold images)

Configure in `terraform.tfvars`:
```hcl
# For FreeBSD
operating_system = "freebsd"
custom_ami_id    = ""

# For RHEL (when you have gold image AMI)
operating_system = "rhel"
custom_ami_id    = "ami-0123456789abcdef0"
```

## Environment Isolation

Each environment deploys to isolated AWS accounts:
- **Dev**: 10.1.0.0/16 VPC, t3.large instance
- **Staging**: 10.2.0.0/16 VPC, t3.large instance  
- **Production**: 10.3.0.0/16 VPC, t3.xlarge instance

## SSH Access

After deployment, connect to your instance:

```bash
# Get connection command from terraform output
terraform output ssh_command

# Or manually:
ssh -i ~/.ssh/your-key ec2-user@INSTANCE-IP
```

## Security Features

- **Multi-Account Isolation**: Each environment runs in a separate AWS account
- **MFA Enforcement**: All AWS operations require multi-factor authentication
- **Cross-Account Roles**: Secure access between accounts with least privilege
- **Encrypted Storage**: EBS volumes encrypted at rest
- **Network Security**: Restrictive security groups and VPC isolation
- **No Long-Lived Credentials**: All access via temporary session tokens

## Post-Deployment: Daily MFA Workflow

After completing all phases, your daily workflow uses your existing admin user with MFA session tokens:

### Daily Authentication Process

1. **Get MFA session token** (using your original admin user):
   ```bash
   aws sts get-session-token \
     --serial-number arn:aws:iam::MANAGEMENT-ACCOUNT-ID:mfa/YOUR_ADMIN_USERNAME \
     --profile mfa \
     --token-code 123456
   ```

2. **Update `~/.aws/config` with returned credentials**:
   ```ini
   [profile default]
   region = us-west-2
   output = json
   aws_access_key_id = RETURNED_ACCESS_KEY_ID
   aws_secret_access_key = RETURNED_SECRET_ACCESS_KEY
   aws_session_token = RETURNED_SESSION_TOKEN
   ```

3. **Deploy to any environment**:
   ```bash
   # Terraform automatically assumes cross-account roles
   cd landing-zone/environments/dev
   terraform plan  # Works across accounts via LandingZoneAdministrators group permissions
   ```

**Note**: Session tokens expire after 12 hours and need to be refreshed. Your admin user remains outside the Control Tower implementation but gains enhanced MFA policies and cross-account access through the `LandingZoneAdministrators` group.

## Important Notes

- **State Management**: Each component (bootstrap, phase1, phase2, environments) has its own Terraform state
- **Account Access**: Workload deployments use cross-account roles, not direct credentials
- **Environment Promotion**: Deploy to dev first, then promote configurations to staging and production

