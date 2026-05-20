#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# cleanup.sh  —  Destroy the full EKS + Traefik + apps stack
#
# Two-stage destroy:
#
#   Stage 1: Destroy all Kubernetes and Helm resources.
#            Removing the Traefik LoadBalancer Service triggers the K8s cloud
#            controller to delete the internet-facing AWS NLB.  This must happen
#            before the VPC is destroyed, otherwise AWS returns a
#            DependencyViolation error because the NLB's ENIs are still attached.
#
#   Stage 2: Full terraform destroy for all remaining AWS resources
#            (EKS cluster, node group, VPC, IAM roles, etc.)
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [init] Initialising Terraform (downloads providers, connects to backend)..."
terraform init

echo ""
echo "==> [import] Building Terraform state from live AWS resources..."
bash "$SCRIPT_DIR/import.sh"

echo ""
echo "==> [stage 1] Destroying Kubernetes workloads and Traefik (triggers NLB deletion)..."
terraform destroy \
  -target=kubernetes_manifest.mock_api_ingress_route \
  -target=kubernetes_manifest.mock_web_ingress_route \
  -target=kubernetes_deployment.mock_api \
  -target=kubernetes_deployment.mock_web \
  -target=kubernetes_service.mock_api \
  -target=kubernetes_service.mock_web \
  -target=helm_release.traefik \
  -target=kubernetes_namespace.mock_api \
  -target=kubernetes_namespace.mock_web \
  -target=kubernetes_namespace.traefik \
  -auto-approve

# The NLB is deleted asynchronously by the K8s cloud controller after the
# LoadBalancer Service is removed.  Wait before destroying the VPC.
echo ""
echo "==> Waiting 60s for the AWS NLB to be fully deprovisioned..."
sleep 60

echo ""
echo "==> [stage 2] Destroying remaining AWS resources (EKS, VPC, IAM)..."
terraform destroy -auto-approve

echo ""
echo "==> Cleanup complete."
