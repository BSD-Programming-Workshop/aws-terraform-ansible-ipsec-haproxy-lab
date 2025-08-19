# Outputs for Generic Workload Module

output "instance_ip" {
  description = "Public IP address of the workload instance"
  value       = aws_instance.workload.public_ip
}

output "private_instance_ip" {
  description = "Private IP address of the workload instance"
  value       = aws_instance.workload.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.workload_sg.id
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = local.selected_ami
}

output "operating_system" {
  description = "Operating system deployed"
  value       = var.operating_system
}

output "ansible_inventory" {
  description = "Ansible inventory for configuration"
  value = join("\n", [
    "[${var.workload_type}]",
    "${aws_instance.workload.public_ip}",
    "",
    "[${var.workload_type}:vars]",
    "ansible_user=${var.operating_system == "freebsd" ? "ec2-user" : "ec2-user"}",
    "operating_system=${var.operating_system}",
    ""
  ])
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.environment}-${var.project_name}-key ec2-user@${aws_instance.workload.public_ip}"
}
