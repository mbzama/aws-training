output "default_vpc_id" {
  description = "Auto-detected default VPC ID"
  value       = data.aws_vpc.default.id
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.main.id
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.main.public_ip
}

output "ec2_connect_url" {
  description = "EC2 Instance Connect - open in AWS Console"
  value       = "https://console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#Instances:instanceId=${aws_instance.main.id}"
}

output "http_url" {
  description = "HTTP URL"
  value       = "http://${aws_instance.main.public_ip}"
}
