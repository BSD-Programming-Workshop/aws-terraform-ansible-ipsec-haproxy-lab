# Outputs for Production Environment

output "instance_ip" {
  description = "Public IP address of the workload instance"
  value       = module.unix_workload.instance_ip
}

output "private_instance_ip" {
  description = "Private IP address of the workload instance"
  value       = module.unix_workload.private_instance_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.unix_workload.vpc_id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = module.unix_workload.subnet_id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.unix_workload.security_group_id
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = module.unix_workload.ami_id
}

output "operating_system" {
  description = "Operating system deployed"
  value       = module.unix_workload.operating_system
}

output "ansible_inventory" {
  description = "Ansible inventory for configuration"
  value       = module.unix_workload.ansible_inventory
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = module.unix_workload.ssh_command
}
