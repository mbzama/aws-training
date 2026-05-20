# ============================================================
# ACM Certificate — managed by Amplify
# ============================================================
# With certificate_settings { type = "AMPLIFY_MANAGED" } in amplify.tf,
# Amplify automatically requests and manages an ACM certificate in
# us-east-1 for &lt;app_domain_name&gt;.
#
# You do NOT need to create a manual ACM resource here.
# Amplify will show the required CNAME validation record in:
#   Amplify Console → App → Hosting → Custom domains
#
# Steps after terraform apply:
#   1. Open Amplify Console → your app → Hosting → Custom domains
#   2. Click "&lt;app_domain_name&gt;" → you will see two CNAME records:
#
#      a) SSL certificate validation CNAME (looks like):
#         Name:  _abc123.&lt;app_domain_name&gt;
#         Value: _xyz789.acm-validations.aws.
#
#      b) Domain routing CNAME:
#         Name:  &lt;app_domain_name&gt;   (or just "app-dev" as host in GoDaddy)
#         Value: <branch>.d3xxxxxxx.amplifyapp.com
#
#   3. Add BOTH CNAMEs to GoDaddy DNS (DNS Management → Add Record → CNAME)
#      For the Name field in GoDaddy, use only the subdomain part:
#        e.g. "_abc123.app-dev" (strip ".example.com" from the end)
#
#   4. Click "Retry activation" in Amplify Console
#   5. Wait 5–30 minutes for SSL status to show "Active"
# ============================================================
