# Output values from the workload modules

# FreeBSD outputs
output "freebsd_vpc_id" {
  description = "ID of the VPC"
  value       = module.freebsd_workload.vpc_id
}

output "freebsd_instance_public_ip" {
  description = "Public IP address of the FreeBSD instance"
  value       = module.freebsd_workload.instance_ip
}

output "freebsd_ssh_command" {
  description = "SSH command to connect to the FreeBSD instance"
  value       = module.freebsd_workload.ssh_command
}

# RHEL outputs (conditional)
output "rhel_instance_public_ip" {
  description = "Public IP address of the RHEL instance"
  value       = var.rhel_ami_id != null ? module.rhel_workload[0].instance_ip : null
}

output "rhel_ssh_command" {
  description = "SSH command to connect to the RHEL instance"
  value       = var.rhel_ami_id != null ? module.rhel_workload[0].ssh_command : null
}

# Combined Ansible inventory
output "ansible_inventory" {
  description = "Combined Ansible inventory for all instances"
  value = var.rhel_ami_id != null ? "${module.freebsd_workload.ansible_inventory}\n${module.rhel_workload[0].ansible_inventory}" : module.freebsd_workload.ansible_inventory
}
