# Generic Linux/Unix Workload Module
# This module contains OS-agnostic infrastructure for deployment across environments
# Supports FreeBSD, RedHat Enterprise Linux, and other Unix-like systems

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Data sources for different OS AMIs
data "aws_ssm_parameter" "freebsd_ami" {
  count = var.operating_system == "freebsd" ? 1 : 0
  name  = var.freebsd_ssm_parameter
}

# For RedHat, we'll use a variable since you need to share gold images with your account
# data "aws_ami" "rhel_ami" {
#   count       = var.operating_system == "rhel" ? 1 : 0
#   most_recent = true
#   owners      = ["309956199498"] # Red Hat
#   
#   filter {
#     name   = "name"
#     values = ["RHEL-9.*-x86_64-*"]
#   }
# }

locals {
  # Select AMI based on OS choice
  selected_ami = var.custom_ami_id != "" ? var.custom_ami_id : (var.operating_system == "freebsd" ? data.aws_ssm_parameter.freebsd_ami[0].value : var.custom_ami_id)
  
  # OS-specific user data
  user_data_scripts = {
    freebsd = <<-EOF
              #!/bin/sh
              pkg install -y python311
              echo "hostname=\"${var.environment}-${var.project_name}-freebsd\"" >> /etc/rc.conf
            EOF
    rhel = <<-EOF
           #!/bin/bash
           yum update -y
           yum install -y python3
           hostnamectl set-hostname ${var.environment}-${var.project_name}-rhel
           EOF
  }
}

# VPC and networking infrastructure
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-${var.project_name}-vpc"
    Environment = var.environment
    Project     = var.project_name
    Workload    = var.workload_type
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-${var.project_name}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-subnet"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associate route table with public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group for workload instance
resource "aws_security_group" "workload_sg" {
  name        = "${var.environment}-${var.project_name}-${var.operating_system}-sg"
  description = "Security group for ${var.operating_system} instance with SSH and IPSec access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow SSH from workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.workstation_cidr]
  }

  ingress {
    description = "Allow IPSec IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = [var.workstation_cidr]
  }

  ingress {
    description = "Allow IPSec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = [var.workstation_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-${var.operating_system}-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# SSH Key Pair
resource "aws_key_pair" "workload" {
  key_name   = "${var.environment}-${var.project_name}-key"
  public_key = var.public_key

  tags = {
    Name        = "${var.environment}-${var.project_name}-key-pair"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Generic EC2 Instance
resource "aws_instance" "workload" {
  ami                    = local.selected_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.workload_sg.id]
  key_name               = aws_key_pair.workload.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = local.user_data_scripts[var.operating_system]

  metadata_options {
    http_tokens   = var.metadata_http_tokens
    http_endpoint = "enabled"
  }

  # Match console behavior: allow opting into unlimited CPU credits for T-family
  dynamic "credit_specification" {
    for_each = var.enable_unlimited_cpu_credits ? [1] : []
    content {
      cpu_credits = "unlimited"
    }
  }

  tags = {
    Name        = "${var.environment}-${var.project_name}-${var.operating_system}"
    Environment = var.environment
    Project     = var.project_name
    OS          = var.operating_system
    Workload    = var.workload_type
  }
}
