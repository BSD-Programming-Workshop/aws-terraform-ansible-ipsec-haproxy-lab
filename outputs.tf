output "instance_ip" {
  value       = aws_instance.tsys-greenscreen.public_ip
  description = "Public IP address of the EC2 instance"
}

output "private_instance_ip" {
  value       = aws_instance.tsys-greenscreen.private_ip
  description = "Private IP address of the EC2 instance"
}

output "ansible_inventory" {
  value = join("\n", [
    "[ipsec]",
    "${aws_instance.tsys-greenscreen.public_ip}",
    ""
  ])
}

#output "ansible_inventory" {
#  value = <<EOT
#  [freebsd]
#  ${aws_instance.freebsd.public_ip} ansible_user=ec2-user
#
#  EOT
#}
#
