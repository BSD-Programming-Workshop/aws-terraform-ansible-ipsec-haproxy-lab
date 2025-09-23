# AWS Landing Zone with Multi-Account Unix Workloads

This project creates a secure, scalable AWS Landing Zone using Control Tower with isolated accounts for deploying Unix workloads (FreeBSD or RHEL) configured with IPSec.

## At a glance

- `landing-zone/environments/README.md` — environment deployments
- `landing-zone/modules/unix-workload/` — reusable module

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
   This step also generates backend.hcl files for Phase 1, Phase 2, and the Dev environment with the correct S3 backend settings.

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
   terraform init -backend-config=backend.hcl
   terraform apply
   # If Control Tower throws “could not assume role,” wait 1–2 minutes for IAM propagation and re-apply
   # Note the account IDs from outputs - you'll need these for Phase 2
   ```

   Note: For this tutorial, Phase 1 creates Log Archive, Audit, Security Tooling, and Unix Dev accounts. Unix Staging, Unix Prod, and Network are deferred by default for cost control and can be enabled later.

   Enable Staging/Prod/Network later:

   1) In `landing-zone/phase1-foundation/main.tf`, remove or comment out `count = 0` on these resources:
   - `aws_organizations_account.unix_staging`
   - `aws_organizations_account.unix_prod`
   - `aws_organizations_account.network`

   2) Add their emails to `landing-zone/phase1-foundation/terraform.tfvars`.

   3) Re-apply Phase 1 from `landing-zone/phase1-foundation/`:

   ```bash
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

#### Control Tower setup: choose Terraform or Console + Import

You can create Control Tower (CT) in one of two ways. For workshops, we recommend the Console + Import path to avoid eventual-consistency hiccups.

- Option A — Terraform creates CT (advanced)
  - In `landing-zone/phase1-foundation/terraform.tfvars`, set:
    ```hcl
    enable_control_tower = true
    ```
  - Ensure the org is clean (no org-level AWS Config/CloudTrail, and do not pre-create `AWSControlTowerAdmin`).
  - Run from `landing-zone/phase1-foundation/`:
    ```bash
    terraform init -backend-config=backend.hcl
    terraform apply
    ```
  - If CT fails with an assume-role error, use Option B.

- Option B — Create CT in Console, then import into Terraform (recommended)
  1) Ensure org-level AWS Config is not enabled and trusted access for CT/Config will not be auto-enabled by Terraform. Our Phase 1 keeps `config.amazonaws.com` and `controltower.amazonaws.com` out of `aws_service_access_principals`.
  2) In the console (us-east-1), open Control Tower and run the landing zone setup wizard. Use the Phase 1-created accounts for Log Archive and Audit if prompted.
       - Important: Deselect "Set up AWS IAM Identity Center" in the wizard. We configure access in Phase 2; leaving Identity Center off avoids extra setup and cost during the workshop.
  3) After CT completes, fetch the Landing Zone ARN:
     ```bash
     aws controltower list-landing-zones --region us-east-1 --profile bootstrap
     ```
  4) Enable Terraform management in `landing-zone/phase1-foundation/terraform.tfvars`:
     ```hcl
     enable_control_tower = true
     ```
  5) Import and reconcile from `landing-zone/phase1-foundation/`:
     ```bash
     terraform init -backend-config=backend.hcl
     terraform import 'aws_controltower_landing_zone.main[0]' LZ_ARN_FROM_STEP_3
     terraform plan
     terraform apply
     ```

Notes:
- Do not pre-create `AWSControlTowerAdmin`; Control Tower creates/manages it.
- Leave org-level AWS Config disabled before setup; Control Tower enables and configures it during the wizard.

##### Console OU Import and Alignment (exact steps)

If the Control Tower wizard created a foundational OU (e.g., `Security-Foundation`), follow these steps so Terraform adopts it without renaming or moving accounts unexpectedly.

1) Set variables in `landing-zone/phase1-foundation/terraform.tfvars` (adjust names/retention as needed):

```hcl
enable_control_tower       = true
security_ou_name           = "Security-Foundation"   # Match the wizard exactly
access_management_enabled  = false                    # Leave IAM Identity Center off for the workshop

# Either keep wizard retention (e.g., 7/7) or adopt TF defaults (60/30)
log_retention_days         = 60
access_log_retention_days  = 30
```

2) Remove the old Security OU from Terraform state (does not delete it in AWS):

```bash
cd landing-zone/phase1-foundation
terraform state rm aws_organizations_organizational_unit.security
```

3) Find the OU ID of the console-created Security OU and import it:

```bash
# Get ROOT ID
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text --profile bootstrap)

# List OUs and copy the Id for the row where Name matches your wizard OU (e.g., Security-Foundation)
aws organizations list-organizational-units-for-parent \
  --parent-id "$ROOT_ID" \
  --query 'OrganizationalUnits[].[Name,Id]' \
  --output table \
  --profile bootstrap

# Import the OU to Terraform
terraform import aws_organizations_organizational_unit.security ou-REPLACE_WITH_ID
```

4) Reconcile and apply:

```bash
terraform plan
terraform apply
```

Tips:
- If the plan proposes moving the `Security Tooling` account, that's expected when aligning to the CT OU. If you prefer it in a different OU, adjust its `parent_id` in Terraform accordingly.
- If you want to keep the wizard's shorter S3 log retention (e.g., 7 days), set `log_retention_days` and `access_log_retention_days` to 7 before apply.

### Phase 2: Deploy Security Configuration

1. **Deploy cross-account roles and MFA policies**:
   ```bash
   cd ../phase2-security
   export AWS_PROFILE=bootstrap
   export AWS_DEFAULT_REGION=us-east-1
   terraform init -backend-config=backend.hcl
   terraform apply
   # This creates: LandingZoneAdministrators group, MFA policies, cross-account roles
   ```

   Note: Phase 2 automatically reads the Phase 1 state bucket from `landing-zone/phase2-security/backend.hcl`. You only need to set `terraform_state_bucket` in `terraform.tfvars` if you want to override auto-detection.

2. **Add your existing admin user to the Landing Zone group**:
   ```bash
   # Add your admin user to the new LandingZoneAdministrators group
   aws iam add-user-to-group \
     --user-name YOUR_ADMIN_USERNAME \
     --group-name LandingZoneAdministrators \
     --profile bootstrap
   ```

3. **Set up MFA device and update AWS CLI configuration**:
   
   Set up MFA device via AWS Console for your admin user (you can find this in the menu under Security Credentials), then update `~/.aws/config`:
   ```ini  
   [profile mfa]
   region = us-east-1
   output = json
   aws_access_key_id = YOUR_ADMIN_USER_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_ADMIN_USER_SECRET_ACCESS_KEY
   # Rename your bootstrap profile to mfa
  
   [profile default]
   region = us-east-1
   aws_access_key_id = YOUR_MFA_ACCESS_KEY_ID
   aws_secret_access_key = YOUR_MFA_SECRET_ACCESS_KEY
   aws_session_token = YOUR_MFA_SESSION_TOKEN
   output = json
   # Temporary MFA session tokens go here (updated daily)
   ```

4. **Test MFA workflow**:
   ```bash
   # Get MFA session token with your admin user
   aws sts get-session-token \
     --serial-number YOUR_MFA_DEVICE_ARN \
     --profile mfa \
     --token-code 123456
   
   # Copy returned credentials to [profile default] section
   ```

5. **Logout of AWS Console and login again with MFA**

   To set the AWS Console session to show MFA is enabled and not see access denied errors, logout of the AWS Console and login again with MFA. Remember, when you logged into the console earlier, you didn't have MFA configured so now that it's required, your current session will be denied because it doesn't meet the MFA requirement until you login again with MFA.

6. **Validate access by assuming into Unix Dev (CLI)**

   Before validating, unset AWS_PROFILE so the CLI uses your `[default]` profile with MFA session tokens. If `AWS_PROFILE` remains set (e.g., to `bootstrap`), the CLI may look for a profile that no longer exists.

   Bash/zsh:
   ```bash
   # Ensure profiles don't interfere and clear any old session env creds
   unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
   ```

   Fetch the Unix Dev account ID from Phase 1 outputs, then assume the role.

   Bash/zsh (robust, no heredocs):
   ```bash
   DEV_ID="$(terraform -chdir=../phase1-foundation output -raw unix_dev_account_id)"
   ARN="arn:aws:iam::${DEV_ID}:role/CrossAccountAdminRole"
   echo "Assuming: $ARN"

   read AKI SAK TOK <<<"$(aws sts assume-role \
     --role-arn "$ARN" \
     --role-session-name validate-dev \
     --duration-seconds 3600 \
     --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
     --output text)"

   export AWS_ACCESS_KEY_ID="$AKI"
   export AWS_SECRET_ACCESS_KEY="$SAK"
   export AWS_SESSION_TOKEN="$TOK"

   aws sts get-caller-identity
   ```

   You should receive temporary credentials. The last command should print the Unix Dev account ID.

   Tip: When done, unset these environment variables so your shell falls back to the MFA `[default]` profile:
   ```bash
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
   ```

### Phase 3: Deploy Workloads to Isolated Accounts

**Note**: After Control Tower deployment, you use cross-account roles instead of direct credentials. The Network account is not used in the current implementation. Each workload creates its own VPC for maximum isolation.

For this tutorial, deploy Dev only. Staging/Prod are optional and require enabling those accounts in Phase 1 first (see "Enable Staging/Prod/Network later").

1. **Subscribe and find FreeBSD AMI (one time per account)**
   - Switch to Unix Dev in the console:
     - https://signin.aws.amazon.com/switchrole?account=YOUR_DEV_ACCOUNT_ID&roleName=OrganizationAccountAccessRole&displayName=UnixDev
   - Open AWS Marketplace (region us-east-1), search "FreeBSD 14" and click Continue to subscribe.
   - Find the AMI ID in EC2 > AMIs for your region (e.g., ami-07a38014679e554b7 for us-east-1) and copy it.

2. **Configure environment variables**:
   ```bash
   cd landing-zone/environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with:
   # - Account ID from phase1 outputs (dev_account_id)
   # - Your SSH public key
   # - Your workstation IP/CIDR (use /32)
   # - custom_ami_id = <FreeBSD AMI ID from console>
   # - availability_zone = us-east-1b, instance_type = t3.micro (known-good)
   # - metadata_http_tokens = required (matches console default)
   # - root_volume_type = gp3, root_volume_size = 10+ GB
   # - Optional: rhel_ami_id to enable RHEL instance alongside FreeBSD
   ```

3. **Deploy workload infrastructure** (uses cross-account role to target account):
   ```bash
   # Use default profile with MFA session tokens
   terraform init -backend-config=backend.hcl
   terraform apply
   # Deploys FreeBSD instance by default
   # If rhel_ami_id is set, also deploys RHEL instance in same VPC
   ```

   Notes:
   - First boot runs freebsd-update and triggers one automatic reboot. Give it several minutes before SSH.
   - EC2 Serial Console is useful for debugging early boot. Enable it in the account if disabled.

4. **(Optional) Staging environment** — only if enabled in Phase 1
   ```bash
   cd ../../environments/staging
   terraform init -backend-config=backend.hcl
   # Update terraform.tfvars with staging_account_id and your keys/IP
   terraform apply
   ```

5. **(Optional) Production environment** — only if enabled in Phase 1
   ```bash
   cd ../prod
   terraform init -backend-config=backend.hcl
   # Update terraform.tfvars with prod_account_id and your keys/IP
   terraform apply
   ```

   Pre-step: SSH once to accept host key
   ```bash
   # Obtain SSH command for FreeBSD instance and connect once to accept the host key
   terraform -chdir=landing-zone/environments/dev output -raw freebsd_ssh_command
   # Copy/paste the printed SSH command to connect, accept the host key prompt, then exit
   # Note: If you used a different private key path when creating the environment, adjust the -i flag accordingly.
   # Alternatively, load your key into ssh-agent so you don't need -i each time:
   eval "$(ssh-agent -s)" && ssh-add ~/.ssh/YOUR_PRIVATE_KEY
   ssh ec2-user@$(terraform -chdir=landing-zone/environments/dev output -raw freebsd_instance_public_ip)
   ```

3. **Configure with Ansible**:
   ```bash
   # From the environment directory
   # Generate inventory and write directly to ansible/hosts (ansible.cfg points to this file by default)
   terraform output -raw ansible_inventory >> ../../../ansible/hosts

   # Run Ansible from the ansible/ directory (uses ansible.cfg defaults)
   cd ../../../ansible
   ansible-playbook playbook.yml
   # This playbook bootstraps Python on FreeBSD/RHEL, detects OS, and applies configuration
   ```

   Ansible layout notes:
   - `ansible/ansible.cfg` sets `inventory = hosts` and `remote_user = ec2-user`, so no `-i` flag is required.
   - `ansible/group_vars/all/config` provides lab-specific values used by roles. Update these before running:
     - `python_version`: leave `"3.11"` for FreeBSD 14.x
     - `lab_cidr`: your on-prem/lab CIDR used for IPsec rules (example: `10.66.6.0/24`)
     - `lab_public_ip`: your workstation or on-prem public IP (can match `workstation_cidr` in terraform.tfvars without `/32`)
     - `aws_public_ip`: the FreeBSD instance public IP. Get via Terraform output: `terraform -chdir=landing-zone/environments/dev output -raw freebsd_instance_public_ip`
     - `aws_private_ip_subnet`: the instance private IP in `/32` form (e.g., `10.1.1.123/32`). Find in EC2 console or with CLI: `aws ec2 describe-instances ... --query 'Reservations[0].Instances[0].PrivateIpAddress'`

   Secrets and PSK (Ansible Vault):
   - The IPsec secrets template reads `ipsec_secret` from `ansible/group_vars/all/secrets`.
   - An example file is provided at `ansible/group_vars/all/secrets.example`.
   - To set a PSK and keep it encrypted:
     ```bash
     cd ansible
     cp group_vars/all/secrets.example group_vars/all/secrets
     ansible-vault encrypt group_vars/all/secrets
     ansible-vault edit group_vars/all/secrets   # set: ipsec_secret: "YOUR-STRONG-PSK"
     # Run playbook with vault prompt or a password file
     ansible-playbook playbook.yml --ask-vault-pass
     # or: ansible-playbook --vault-password-file ~/.ansible/.vault_pass.txt playbook.yml
     ```

   FreeBSD strongSwan interface:
   - The role configures strongSwan to use the `stroke` interface by running:
     ```
     sysrc strongswan_interface=stroke
     ```
     before enabling the service. This matches the port message when installing `strongswan` on FreeBSD.

   Verification and troubleshooting (FreeBSD swanctl/vici):
   - Checklist before running the playbook:
     - `ansible/group_vars/all/config` has:
       - `aws_public_ip` (Terraform `freebsd_instance_public_ip`)
       - `aws_private_ip_subnet` (e.g., `10.1.1.X/32`)
       - `lab_public_ip` (your public IP)
       - `lab_cidr` (your on‑prem CIDR, e.g., `10.66.6.0/24`)
     - `ansible/group_vars/all/secrets` exists and is encrypted with Vault
       - contains: `ipsec_secret: "YOUR-STRONG-PSK"`
   - After playbook completes, on the FreeBSD host:
     ```bash
     # Service should be enabled and started
     service strongswan status

     # Load and inspect connections (swanctl/vici)
     swanctl --load-all
     swanctl --list-conns
     swanctl --list-sas

     # Confirm kernel IPsec module (usually auto-loaded)
     kldstat -m ipsec || true
     ```
   - If connections don’t appear:
     - Re-check `swanctl.conf` rendered values: `/usr/local/etc/swanctl/swanctl.conf`
     - Confirm config variables in `ansible/group_vars/all/config`
     - Ensure Vault secret exists: `ansible-vault view ansible/group_vars/all/secrets`
     - Re-run just the ipsec role: `ansible-playbook playbook.yml -t ipsec --ask-vault-pass`

   swanctl quick reference (FreeBSD):
   ```bash
   # Reload config and secrets after changes
   swanctl --load-all

   # List configured connections and active SAs
   swanctl --list-conns
   swanctl --list-sas

   # Bring a connection down/up (names from swanctl.conf, e.g., lab-tunnel)
   swanctl --terminate --ike lab-tunnel || true
   swanctl --initiate --ike lab-tunnel

   # Tail logs for troubleshooting
   tail -f /var/log/secure /var/log/messages 2>/dev/null | grep -iE 'charon|ipsec|swanctl'
   ```

   Important: configure the remote peer as well
   - This playbook configures only the FreeBSD AWS side. The on‑prem/lab peer must be configured to match:
     - Same PSK as `ipsec_secret`
     - Peer IDs as set in `swanctl.conf` (we use public IPs)
     - Local/remote traffic selectors (`aws_private_ip_subnet` ↔ `lab_cidr`)
     - Matching IKE/ESP proposals (`aes256-sha256-modp2048` in this example)
   - If your peer is a Linux strongSwan, use `swanctl.conf` there with mirrored parameters. For other devices, map these values to their UI/CLI.

## Multi-OS Testing in Dev Environment

The dev environment supports deploying both FreeBSD and RHEL instances simultaneously:

- **FreeBSD instance**: Always deployed
- **RHEL instance**: Optional - set `rhel_ami_id` in `terraform.tfvars` to enable
- **Same VPC**: Both instances share networking resources
- **Unified Ansible**: Single playbook configures both OS types automatically

## Operating System Support

The infrastructure supports both FreeBSD and RHEL:

- **FreeBSD**: Uses an explicit AMI ID (you must subscribe in AWS Marketplace, then copy the AMI ID from EC2 > AMIs)
- **RHEL**: Uses a custom AMI ID (e.g., your gold image shared to the account)

Configure in `terraform.tfvars`:
```hcl
# For FreeBSD
operating_system = "freebsd"
custom_ami_id    = "ami-xxxxxxxxxxxxxxxxx"  # Marketplace AMI ID you subscribed to

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
# Get connection command for FreeBSD from terraform output
terraform -chdir=landing-zone/environments/dev output -raw freebsd_ssh_command

# Or manually:
ssh -i ~/.ssh/YOUR_PRIVATE_KEY ec2-user@INSTANCE-IP

# Recommended: use ssh-agent so you don't have to pass -i repeatedly
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/YOUR_PRIVATE_KEY
ssh ec2-user@INSTANCE-IP
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
   terraform init -backend-config=backend.hcl
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
