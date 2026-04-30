# ─────────────────────────────────────────────────────────────────────────────
# EKS Outputs
# ─────────────────────────────────────────────────────────────────────────────
output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Identity Provider (for IRSA)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# Networking Outputs
# ─────────────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (worker nodes)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (NAT Gateway)"
  value       = aws_subnet.public[*].id
}

# ─────────────────────────────────────────────────────────────────────────────
# Traefik / NLB Outputs
# ─────────────────────────────────────────────────────────────────────────────
output "traefik_nlb_dns" {
  description = "Internet-facing NLB DNS name — use this as the CNAME target in GoDaddy"
  value       = data.aws_lb.traefik.dns_name
}

output "traefik_nlb_arn" {
  description = "ARN of the internet-facing Traefik NLB"
  value       = data.aws_lb.traefik.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# GoDaddy DNS Setup
# ─────────────────────────────────────────────────────────────────────────────
output "godaddy_cname_instructions" {
  description = "Instructions for configuring CNAME records in GoDaddy DNS"
  value       = <<-EOT
    In GoDaddy DNS, add the following CNAME records pointing to the NLB:

      ${var.ui_host}   CNAME  ${data.aws_lb.traefik.dns_name}
      ${var.app_host}  CNAME  ${data.aws_lb.traefik.dns_name}

    Traffic flow after DNS propagation:
      HTTPS → NLB (TLS termination via ACM cert) → Traefik (HTTP routing) → pods

    The ACM certificate handles TLS; no Let's Encrypt or pod-level certs needed.
  EOT
}

output "example_requests" {
  description = "Example curl commands to test the full traffic flow"
  value       = <<-EOT
    # UI (Next.js):
    curl https://${var.ui_host}/web

    # API (NestJS):
    curl https://${var.app_host}/api/users
    curl https://${var.app_host}/api/products
  EOT
}
