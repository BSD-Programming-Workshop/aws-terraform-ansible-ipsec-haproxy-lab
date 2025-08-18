# FreeBSD EC2 with IPSec Configuration

This Terraform project creates a FreeBSD EC2 instance on AWS and configures it with IPSec using Ansible.

## Prerequisites

1. **AWS CLI configured** with your credentials:
   ```bash
   aws configure
   ```

2. **Terraform installed** (version 1.0+)

3. **Ansible installed** with Python support

## Setup

1. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

2. **Get your current IP** (for workstation access):
   ```bash
   curl ifconfig.me
   ```

## Deployment

1. **Format and validate**:
   ```bash
   terraform fmt
   terraform validate
   ```

2. **Initialize and plan**:
   ```bash
   terraform init
   terraform plan
   ```

3. **Deploy infrastructure**:
   ```bash
   terraform apply
   ```

4. **Configure with Ansible**:
   ```bash
   ansible-playbook -i <(terraform output -raw ansible_inventory) ansible/playbook.yml
   ```

## Outputs

- `instance_ip`: Public IP of the FreeBSD instance
- `private_instance_ip`: Private IP within VPC
- `ansible_inventory`: Formatted inventory for Ansible

## Security Notes

- AWS credentials are managed via AWS CLI or environment variables
- Security group restricts access to your workstation IP only
- IPSec ports (500, 4500 UDP) are configured for VPN access

