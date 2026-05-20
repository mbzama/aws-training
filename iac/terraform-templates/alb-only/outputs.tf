output "alb_dns_name" {
  description = "ALB DNS name - use this in your browser or DNS record"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_arn" {
  description = "ALB ARN (use to attach to EC2 / Auto Scaling stacks)"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target Group ARN (register EC2 instances or Auto Scaling group here)"
  value       = aws_lb_target_group.main.arn
}

output "alb_security_group_id" {
  description = "ALB Security Group ID (allow traffic from ALB to EC2 SG)"
  value       = aws_security_group.alb.id
}

output "alb_hosted_zone_id" {
  description = "ALB Hosted Zone ID (for Route 53 alias records)"
  value       = aws_lb.main.zone_id
}
