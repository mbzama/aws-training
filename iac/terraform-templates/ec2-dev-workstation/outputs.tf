output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.workstation.id
}

output "public_ip" {
  description = "Public IP (EIP if enabled, else instance public IP)"
  value       = var.create_eip ? aws_eip.workstation[0].public_ip : aws_instance.workstation.public_ip
}

output "private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.workstation.private_ip
}

output "ami_id" {
  description = "AMI used for the instance"
  value       = data.aws_ami.ubuntu_22_arm64.id
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${var.create_eip ? aws_eip.workstation[0].public_ip : aws_instance.workstation.public_ip}"
}

output "rdp_connection" {
  description = "RDP endpoint"
  value       = "${var.create_eip ? aws_eip.workstation[0].public_ip : aws_instance.workstation.public_ip}:3389"
}
