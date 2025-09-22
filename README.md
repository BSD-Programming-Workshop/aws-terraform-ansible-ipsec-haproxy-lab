# AWS Landing Zone with Multi-Account Unix Workloads

This project creates a secure, scalable AWS Landing Zone using Control Tower with isolated accounts for deploying Unix workloads (FreeBSD or RHEL) configured with IPSec.

## EuroBSDCon Tutorial Guide

For a condensed student handout used during the EuroBSDCon session, see:

- `docs/eurobsdcon-tutorial.md`

## At a glance

- `landing-zone/environments/README.md` — environment deployments
- `landing-zone/modules/unix-workload/` — reusable module
- `docs/eurobsdcon-slides.md` — slide deck (Marp)

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
    └── Network Account (reserved for future use)
```

## Networking Architecture

**Current Implementation**: Each workload environment creates its own isolated VPC:
- **Dev Environment**: 10.1.0.0/16 VPC in Dev Account
- **Staging Environment**: 10.2.0.0/16 VPC in Staging Account  
- **Production Environment**: 10.3.0.0/16 VPC in Production Account

**Future Enhancement**: The Network Account is not currently used. It's reserved for potential centralized networking services like:
- Transit Gateway for inter-VPC connectivity
- Centralized NAT Gateways
- Shared VPC endpoints
- Cross-account DNS resolution

## Prerequisites

1. **AWS Administrative User**: Create an admin IAM user following [AWS best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html)
2. **AWS CLI installed** (version 2.0+)
3. **Terraform installed** (version 1.0+)
4. **Ansible installed** with Python support
5. **4 unique email addresses** for AWS accounts for this tutorial (Log Archive, Audit, Security Tooling, Unix Dev). If you later enable Staging, Prod, and Network, you'll need 3 additional emails (total 7). See Email Setup below.
6. **MFA device** for secure access

## Email Address Setup

AWS requires a unique email address for each account.

For this tutorial (cost-controlled), Phase 1 creates only:
- Log Archive, Audit, Security Tooling, Unix Dev

So you need **4 email addresses** now. If you later enable Staging, Prod, and Network, add 3 more unique emails (total 7).

### **Required Email Addresses (Tutorial Scope)**:
1. `log-archive@yourdomain.com` - Log Archive Account (Control Tower logging)
2. `audit@yourdomain.com` - Audit Account (Control Tower security)
3. `security-tooling@yourdomain.com` - Security Tooling Account
4. `unix-dev@yourdomain.com` - Unix Dev Account

### **Additional Emails (Enable Later if Needed)**:
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
Note: Staging, Prod, and Network accounts are deferred by default for this tutorial; you can enable them later and add their emails then.

## Deployment Workflow

### Bootstrap Backend

1. **Create initial AWS CLI configuration**:
   
   First, create an administrative IAM user following [AWS best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html). This user will exist outside the Control Tower implementation and be used throughout the deployment process.

   Then create an Access Key ID and Secret Access Key for this user for the Command Line Interface (CLI) use case.
   
   Then create `~/.aws/config` with your admin user credentials:
   ```ini
   [profile bootstrap]
   region = us-east-1
   output = json
   aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
   
   [profile default]
   region = us-east-1
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
   
   **Note**: The `governed_regions` includes a list of regions. We're using only `us-east-1` (the primary region). This is because:
   - AWS Control Tower requires `us-east-1` for many global services (IAM, CloudFront, Route 53)
   - Centralized logging and compliance features work better with `us-east-1` governed
   - No additional cost - just extends guardrails and policies to listed regions

2. **Deploy AWS Organizations and accounts**:
   ```bash
   export AWS_PROFILE=bootstrap
   export AWS_DEFAULT_REGION=us-east-1
   terraform init \
     -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET" \
     -backend-config="key=phase1-foundation/terraform.tfstate" \
     -backend-config="dynamodb_table=YOUR-DYNAMODB-TABLE" \
     -backend-config="encrypt=true"
   terraform apply
   # Note the account IDs from outputs - you'll need these for Phase 2
   ```

   Note: For this tutorial, Phase 1 creates Log Archive, Audit, Security Tooling, and Unix Dev accounts. Unix Staging, Unix Prod, and Network are deferred by default for cost control and can be enabled later.

   Enable Staging/Prod/Network later:

   1) In `landing-zone/phase1-foundation/main.tf`, remove or comment out `count = 0` on these resources:
   - `aws_organizations_account.unix_staging`
   - `aws_organizations_account.unix_prod`
   - `aws_organizations_account.network`

   2) Add their emails to `landing-zone/phase1-foundation/terraform.tfvars`.

   3) Re-apply Phase 1 from `landing-zone/phase1-foundation/` with the same backend settings:

   ```bash
   terraform init \
     -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET" \
     -backend-config="key=phase1-foundation/terraform.tfstate" \
     -backend-config="dynamodb_table=YOUR-DYNAMODB-TABLE" \
     -backend-config="encrypt=true"
   terraform apply
   ```

### Phase 2: Deploy Security Configuration

1. **Deploy cross-account roles and MFA policies**:
   ```bash
   cd ../phase2-security
   export AWS_PROFILE=bootstrap
   terraform init \
     -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET" \
     -backend-config="key=phase2-security/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=YOUR-DYNAMODB-TABLE" \
     -backend-config="encrypt=true"
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
  region = us-east-1
  output = json
  aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
  aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
  
  [profile mfa]
  region = us-east-1
  output = json
  aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
  aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
  
  [profile default]
  region = us-east-1
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
   terraform init \
     -backend-config="bucket=YOUR-TERRAFORM-STATE-BUCKET" \
     -backend-config="key=environments/dev/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -backend-config="dynamodb_table=YOUR-DYNAMODB-TABLE" \
     -backend-config="encrypt=true"
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
- **Different AZs**: FreeBSD in us-east-1a, RHEL in us-east-1b
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

### Tip: RHEL Gold Images via Red Hat Portal

If you use Red Hat gold images, the AMI IDs must be shared to your specific AWS account ID(s) and region(s) from the Red Hat portal.

- Set `custom_ami_id` (or `rhel_ami_id` in the dev environment) in the environment's `terraform.tfvars`.
- Ensure the AMI is shared with the exact account ID you are deploying to (e.g., `unix_dev_account_id`).
- Verify the AMI exists in `us-east-1` (or your selected region).
- Red Hat documentation for this feature is sparse; coordinate with Red Hat support if needed to enable the AMI sharing to your AWS account.

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
  
## Access Model (No Per-Account Passwords Needed)

For day-to-day operations and for this workshop, you do not need passwords for each member account. You operate from the management account using an IAM user with MFA, then assume cross-account roles into member accounts.

- You authenticate to the management account with MFA.
- Terraform (and AWS CLI) then assumes `CrossAccountAdminRole` in target accounts as needed.
- No IAM users or passwords are required in the member accounts.

This model reduces credential sprawl and keeps control centralized while maintaining least-privilege via role assumptions.

### Console: Switch Role into Member Accounts

You can switch roles directly in the AWS Console from the management account:

1. Sign in to the management account console with your IAM user and MFA.
2. In the top-right user menu, choose `Switch Role`.
3. Enter:
   - Account: target account ID (e.g., from Phase 1 outputs: `unix_dev_account_id`, `unix_staging_account_id`, `unix_prod_account_id`)
   - Role: `CrossAccountAdminRole`
   - Optional: Display name and color
4. Click `Switch Role`.

Quick-switch bookmarks (replace ACCOUNT_ID):

```
https://signin.aws.amazon.com/switchrole?account=ACCOUNT_ID&roleName=CrossAccountAdminRole&displayName=Unix-Dev
https://signin.aws.amazon.com/switchrole?account=ACCOUNT_ID&roleName=CrossAccountAdminRole&displayName=Unix-Staging
https://signin.aws.amazon.com/switchrole?account=ACCOUNT_ID&roleName=CrossAccountAdminRole&displayName=Unix-Prod
```

Notes:

- MFA is required by policy and trust. Ensure you signed in with MFA.
- We enforce `aws:MultiFactorAuthAge < 3600` in the trust policy. If your MFA session is older than ~1 hour, re-auth with MFA and try again.

Get account IDs from Terraform outputs:

```bash
# Run in the phase1 state directory (this state holds the account IDs):
cd landing-zone/phase1-foundation

# If needed, re-init with the same backend settings you used during apply
# (bucket/key/dynamodb_table/region). Then:
terraform output unix_dev_account_id
terraform output unix_staging_account_id
terraform output unix_prod_account_id
```

## Cost Controls and Teardown

Keep costs predictable for workshops and personal sandboxes.

- **Use Dev only for demos**: Skip staging/prod until needed.
- **Small instances**: In `landing-zone/environments/*/terraform.tfvars`, set:
  - `instance_type = "t3.micro"`
  - `root_volume_size = 8` or `10`
- **RHEL gold images**: If you have prepaid RHEL AMI IDs from your Red Hat portal, use them as needed.
- **Short-lived environments**: Create during the workshop; destroy immediately after.
- **Avoid expensive networking**: This repo does not create NAT Gateways or NLBs by default. Continue to avoid them for cost control.
- **S3 lifecycle for state**: The bootstrap state bucket expires noncurrent versions after 30 days and aborts incomplete uploads after 7 days to limit storage costs.

### Control Tower log lifecycle (optional)

After Phase 1, you can transition Control Tower log bucket objects to Glacier after 7 days. Do this from a shell after switching role into the Log Archive account.

```bash
export BUCKET="aws-controltower-logs-ACCOUNT_ID-us-east-1"  # Replace with your actual bucket name

cat > lifecycle.json <<'JSON'
{
  "Rules": [
    {
      "ID": "transition-to-glacier-7d",
      "Status": "Enabled",
      "Filter": {},
      "Transitions": [
        { "Days": 7, "StorageClass": "GLACIER" }
      ]
    }
  ]
}
JSON

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration file://lifecycle.json

# Verify
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET"
```

### Optional: Root User Hardening (Post-Lab)

Each AWS account has a root user tied to its unique email address. Root is not used in normal operations, but should be hardened after the lab:

1. Set a long, random root password (use the password reset flow to the account email/alias).
2. Enable MFA on the root user (hardware MFA preferred).
3. Record recovery contacts and security questions where applicable.
4. Store secrets securely in a password manager (e.g., Proton Pass, 1Password, Bitwarden).
5. Do not use root for daily work; continue to use the management IAM user + MFA and assume roles.

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
  region = us-east-1
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


## Cost Controls and Teardown

Keep costs predictable for workshops and personal sandboxes.

- **Use Dev only for demos**: Skip staging/prod until needed.
- **Small instances**: In `landing-zone/environments/*/terraform.tfvars`, set:
  - `instance_type = "t3.micro"`
  - `root_volume_size = 8` or `10`
- **RHEL gold images**: If you have prepaid RHEL AMI IDs from your Red Hat portal, use them as needed.
- **Short-lived environments**: Create during the workshop; destroy immediately after.
- **Avoid expensive networking**: This repo does not create NAT Gateways or NLBs by default. Continue to avoid them for cost control.
- **S3 lifecycle for state**: The bootstrap state bucket expires noncurrent versions after 30 days and aborts incomplete uploads after 7 days to limit storage costs.

### Teardown after the session

Run from the environment directory you deployed (e.g., `landing-zone/environments/dev`):

```bash
terraform destroy
