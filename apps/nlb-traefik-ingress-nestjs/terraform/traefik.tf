# ─────────────────────────────────────────────────────────────────────────────
# Namespace – test-system
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "traefik" {
  metadata {
    name = var.traefik_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ─────────────────────────────────────────────────────────────────────────────
# Traefik – Helm Release
#
# Architecture:
#   GoDaddy CNAME → NLB (internet-facing, L4 TCP passthrough) → Traefik (L7 TLS)
#
# Key design decisions:
#   • NLB is internet-facing so GoDaddy CNAME points directly to the NLB DNS name
#   • NLB does pure TCP passthrough on ports 80 and 443 – no TLS at the NLB
#   • Traefik terminates TLS using Let's Encrypt ACME (HTTP-01 challenge on port 80)
#   • PROXY protocol propagates real client IPs through the NLB to Traefik
#   • CRD provider (kubernetesCRD) enabled for IngressRoute resources
#   • allowCrossNamespace = true lets Traefik route across namespaces
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_chart_version
  namespace  = kubernetes_namespace.traefik.metadata[0].name

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      deployment = {
        replicas = 1
      }

      # ── Service / NLB ────────────────────────────────────────────────────
      # Internet-facing NLB so GoDaddy can CNAME to its DNS name.
      # TLS is terminated at the NLB using the ACM certificate; Traefik
      # receives plain HTTP from the NLB on both entrypoints.
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-internal"                          = "false"
          "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          # PROXY protocol lets Traefik see the real client IP after NLB decryption.
          "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol" = "*"
          # ACM certificate for NLB TLS termination on port 443.
          "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"  = var.acm_certificate_arn
          "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
        }
      }

      # ── Ports ────────────────────────────────────────────────────────────
      # Both ports forward plain HTTP to Traefik — TLS is handled by the NLB.
      # websecure (443) receives decrypted traffic from the NLB; no TLS in Traefik.
      ports = {
        web = {
          port        = 8000
          exposedPort = 80
          protocol    = "TCP"
          expose      = true
        }
        websecure = {
          port        = 8443
          exposedPort = 443
          protocol    = "TCP"
          expose      = true
        }
      }

      # ── Providers ────────────────────────────────────────────────────────
      providers = {
        kubernetesCRD = {
          enabled             = true
          allowCrossNamespace = true
        }
        kubernetesIngress = {
          enabled = false
        }
      }

      # ── Dashboard ────────────────────────────────────────────────────────
      ingressRoute = {
        dashboard = {
          enabled = false
        }
      }

      # ── Resources ────────────────────────────────────────────────────────
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "300m", memory = "256Mi" }
      }

      # ── Additional arguments ─────────────────────────────────────────────
      additionalArguments = [
        "--log.level=INFO",
        "--accesslog=true",
        # Consume PROXY protocol injected by the NLB.  Traefik must unwrap it
        # before parsing HTTP/TLS — only trust IPs within the VPC CIDR.
        "--entrypoints.web.proxyProtocol.trustedIPs=${var.vpc_cidr}",
        "--entrypoints.websecure.proxyProtocol.trustedIPs=${var.vpc_cidr}",
        "--entrypoints.web.forwardedHeaders.trustedIPs=${var.vpc_cidr}",
        "--entrypoints.websecure.forwardedHeaders.trustedIPs=${var.vpc_cidr}",
      ]
    })
  ]

  depends_on = [kubernetes_namespace.traefik]
}

# ─────────────────────────────────────────────────────────────────────────────
# Wait for the NLB to be provisioned by the K8s cloud controller.
# ─────────────────────────────────────────────────────────────────────────────
resource "time_sleep" "wait_for_nlb" {
  create_duration = "${var.nlb_wait_seconds}s"

  depends_on = [helm_release.traefik]
}

# ─────────────────────────────────────────────────────────────────────────────
# Data – Traefik NLB
# The K8s cloud controller tags the NLB so we can look it up by cluster
# name and service name.  The DNS name is output for GoDaddy CNAME setup.
# ─────────────────────────────────────────────────────────────────────────────
data "aws_lb" "traefik" {
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/service-name"                = "${var.traefik_namespace}/traefik"
  }

  depends_on = [time_sleep.wait_for_nlb]
}
