# ============================================================
# AWS Amplify Application
# ============================================================
# This file creates:
#   1. The Amplify app connected to your GitHub repository
#   2. A "main" branch with automatic deployments enabled
#   3. A custom domain pointing to &lt;app_domain_name variable&gt;
# ============================================================

# ------------------------------------------------------------
# 1. Amplify App
# ------------------------------------------------------------
resource "aws_amplify_app" "app" {
  name        = var.app_name
  repository  = var.github_repository
  oauth_token = var.github_oauth_token

  # Use the amplify.yml checked into the repository root instead of
  # specifying build commands inline.  Any change to the build process
  # only requires a Git commit — no Terraform apply needed.
  build_spec = file("${path.module}/../amplify.yml")

  # Redirect all 404 responses to index.html so that React Router's
  # client-side routing works correctly on page refresh or direct URL access.
  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }

  # Rewrite rule that normalises clean URLs (removes the .html extension)
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }

  # Environment variables available to the build container.
  # Add any REACT_APP_* variables your app needs here.
  environment_variables = {
    REACT_APP_ENV = "dev"
  }
}

# ------------------------------------------------------------
# 2. Branch — main
# ------------------------------------------------------------
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.app.id
  branch_name = "main"

  # Trigger a new Amplify build automatically on every push to this branch
  enable_auto_build = true

  # Mark this branch as the "production" branch in the Amplify Console UI
  framework = "React"
  stage     = "PRODUCTION"

  # Inherit environment variables defined on the parent app.
  # Branch-level variables override app-level ones if the key matches.
  environment_variables = {}
}

# ------------------------------------------------------------
# 3. Custom Domain — &lt;app_domain_name variable&gt;
# ------------------------------------------------------------
# AMPLIFY_MANAGED certificate: Amplify automatically requests and
# manages an ACM certificate in us-east-1 for &lt;app_domain_name variable&gt;.
#
# After applying, Amplify Console → Domain Management will show:
#   - One CNAME for SSL certificate validation  → add to GoDaddy
#   - One CNAME to point the domain to Amplify  → add to GoDaddy
#
# Once both CNAMEs are in GoDaddy, click "Retry activation" in the
# Amplify Console.  SSL status will change to Active within 30 min.
# ------------------------------------------------------------
resource "aws_amplify_domain_association" "app" {
  app_id      = aws_amplify_app.app.id
  domain_name = var.app_domain_name

  # Use Amplify-managed certificate — Amplify provisions and renews
  # the ACM cert automatically. No manual ACM resource needed.
  certificate_settings {
    type = "AMPLIFY_MANAGED"
  }

  # Map the root of the custom domain to the main branch
  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }
}
