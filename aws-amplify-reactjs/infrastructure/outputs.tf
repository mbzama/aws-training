# ============================================================
# Outputs
# ============================================================

output "amplify_app_id" {
  description = "Unique Amplify application ID — use this to find your app in the Console."
  value       = aws_amplify_app.app.id
}

output "amplify_default_domain" {
  description = "Auto-generated Amplify URL for testing before the custom domain is active."
  value       = "${aws_amplify_branch.main.branch_name}.${aws_amplify_app.app.default_domain}"
}

output "amplify_app_url" {
  description = "Live URL after custom domain and SSL are fully activated."
  value       = "https://${var.app_domain_name}"
}

output "amplify_next_steps" {
  description = "What to do after terraform apply to activate the custom domain."
  value       = <<-EOT
    1. Open: https://console.aws.amazon.com/amplify/home
    2. Select your app → Hosting → Custom domains → ${var.app_domain_name}
    3. Copy the two CNAME records shown (SSL validation + domain routing)
    4. Add both to your DNS provider
       - Strip the root domain suffix from the Name field (your DNS provider may append it automatically)
       - Strip trailing dots from the Value field
    5. Click 'Retry activation' in Amplify Console
    6. Wait 5-30 minutes for SSL status to show 'Active'
  EOT
}
