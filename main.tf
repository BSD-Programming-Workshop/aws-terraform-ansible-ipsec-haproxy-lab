resource "aws_security_group" "allow_ssh" {
  name        = "tsys-greenscreen"
  description = "security group"
  vpc_id      = "vpc-00ee69a3926f74847"

  ingress {
    description = "Allow SSH from vpc network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.named_cidrs["vpc"]]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.named_cidrs["workstation"]]
  }

  ingress {
    description = "Allow IPSec"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = [var.named_cidrs["workstation"]]
  }

  ingress {
    description = "Allow IPSec"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = [var.named_cidrs["workstation"]]
  }

  egress {
    description = "Allow outbound traffic to internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "allow-ssh" }
}

resource "aws_instance" "tsys-greenscreen" {
  ami                    = "ami-0612dcf86ac03a083"
  instance_type          = "t3.large"
  subnet_id              = "subnet-0996b63da2b9d7fcb"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name               = "roller"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/sh
              pkg install -y python311
            EOF

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "tsys-greenscreen"
  }
}

