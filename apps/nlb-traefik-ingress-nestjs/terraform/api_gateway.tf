# API Gateway v2 removed.
#
# The previous architecture routed traffic through:
#   API Gateway → VPC Link → internal NLB → Traefik
#
# The current architecture is:
#   GoDaddy CNAME → internet-facing NLB (TCP passthrough) → Traefik (TLS) → pods
#
# All AWS API Gateway v2, VPC Link, CloudWatch log group, ACM lookup, and
# custom domain resources have been removed.  See traefik.tf for the NLB
# configuration and outputs.tf for the CNAME value to set in GoDaddy.
