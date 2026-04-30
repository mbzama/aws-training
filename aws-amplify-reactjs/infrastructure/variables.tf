# ============================================================
# Input Variables
# ============================================================
# Supply values via a terraform.tfvars file (never commit that file
# to source control — it contains secrets) or via environment variables:
#
#   export TF_VAR_github_oauth_token="ghp_..."
#   export TF_VAR_github_repository="https://github.com/org/repo"
#   export TF_VAR_app_name="aws-amplify-reactjs"
# ============================================================

variable "app_name" {
  description = "Human-readable name for the Amplify application. Used as a prefix for resource names and tags."
  type        = string
  default     = "aws-amplify-reactjs"
}

variable "github_repository" {
  description = "Full HTTPS URL of the GitHub repository that Amplify will monitor for deployments. Example: https://github.com/your-org/your-repo"
  type        = string
}

variable "github_oauth_token" {
  description = "GitHub personal access token (classic) with repo scope. Amplify uses this to clone the repository and register webhooks. Keep this value secret — never commit it to source control."
  type        = string
  sensitive   = true
}

variable "app_domain_name" {
  description = "Custom domain to associate with the Amplify app (e.g. myapp.example.com). Amplify will auto-provision and manage the ACM certificate."
  type        = string
}
