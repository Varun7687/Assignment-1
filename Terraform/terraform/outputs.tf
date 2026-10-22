output "status_page_url" {
  description = "Public status-page URL."
  value       = "http://${aws_instance.status_page.public_ip}/status/"
}

output "instance_id" {
  value = aws_instance.status_page.id
}

output "public_ipv4" {
  value = aws_instance.status_page.public_ip
}

output "security_group_id" {
  value = aws_security_group.status_page.id
}

output "website_volume_id" {
  value = aws_ebs_volume.website.id
}

output "ssh_commands" {
  description = "Use each team account's matching local private key."
  value       = "ssh -i <asha-private-key> asha@${aws_instance.status_page.public_ip} | ssh -i <ravi-private-key> ravi@${aws_instance.status_page.public_ip}"
}

output "admin_ssh_command" {
  description = "Replace the placeholder with the local path to the existing key pair's private key."
  value       = "ssh -i <path-to-existing-private-key> ec2-user@${aws_instance.status_page.public_ip}"
}

output "admin_key_pair_name" {
  description = "Existing AWS key pair selected for EC2 administrator SSH access."
  value       = data.aws_key_pair.admin.key_name
}
