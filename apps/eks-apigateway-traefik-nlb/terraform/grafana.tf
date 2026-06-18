# ─────────────────────────────────────────────────────────────────────────────
# Grafana Alloy – log collection → Grafana Cloud Loki
# ─────────────────────────────────────────────────────────────────────────────

locals {
  alloy_config = <<-ALLOY
    // Discover all pods running in the cluster
    discovery.kubernetes "pods" {
      role = "pod"
    }

    // Extract useful metadata as Loki stream labels
    discovery.relabel "pods" {
      targets = discovery.kubernetes.pods.targets

      rule {
        source_labels = ["__meta_kubernetes_namespace"]
        target_label  = "namespace"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_name"]
        target_label  = "pod"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_container_name"]
        target_label  = "container"
      }
      rule {
        source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
        target_label  = "app"
      }
    }

    // Tail pod logs via the Kubernetes API — no host-path mounts or privileged
    // container required because loki.source.kubernetes streams directly from
    // the kubelet log endpoint.
    loki.source.kubernetes "pods" {
      targets    = discovery.relabel.pods.output
      forward_to = [loki.write.grafana_cloud.receiver]
    }

    // Push to Grafana Cloud Loki.
    // URL / credentials are injected at runtime via env vars backed by a
    // Kubernetes Secret (never baked into the ConfigMap).
    loki.write "grafana_cloud" {
      endpoint {
        url = env("GRAFANA_CLOUD_LOKI_URL")

        basic_auth {
          username = env("GRAFANA_CLOUD_LOKI_USERNAME")
          password = env("GRAFANA_CLOUD_LOKI_PASSWORD")
        }
      }

      external_labels = {
        cluster = "${var.cluster_name}",
        env     = "${var.environment}",
      }
    }
  ALLOY
}

# ─────────────────────────────────────────────────────────────────────────────
# Namespace
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "alloy" {
  metadata {
    name = var.alloy_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ─────────────────────────────────────────────────────────────────────────────
# Secret – Grafana Cloud credentials
# Values come from variables in secrets.auto.tfvars (gitignored).
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_secret" "grafana_cloud" {
  metadata {
    name      = "grafana-cloud-credentials"
    namespace = kubernetes_namespace.alloy.metadata[0].name
  }

  data = {
    loki_url      = var.grafana_cloud_loki_url
    loki_username = var.grafana_cloud_loki_username
    loki_password = var.grafana_cloud_loki_password
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Grafana Alloy – Helm Release
#
# Key design decisions:
#   • DaemonSet — one Alloy pod per node so every workload's logs are covered
#   • loki.source.kubernetes — Kubernetes API-based log tailing; no privileged
#     container or host-path mounts
#   • Credentials flow: tfvars → k8s Secret → env vars → River config env()
# ─────────────────────────────────────────────────────────────────────────────
resource "helm_release" "alloy" {
  name       = "alloy"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = kubernetes_namespace.alloy.metadata[0].name

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      controller = {
        type = "daemonset"
      }

      alloy = {
        configMap = {
          content = local.alloy_config
        }

        extraEnv = [
          {
            name = "GRAFANA_CLOUD_LOKI_URL"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.grafana_cloud.metadata[0].name
                key  = "loki_url"
              }
            }
          },
          {
            name = "GRAFANA_CLOUD_LOKI_USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.grafana_cloud.metadata[0].name
                key  = "loki_username"
              }
            }
          },
          {
            name = "GRAFANA_CLOUD_LOKI_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = kubernetes_secret.grafana_cloud.metadata[0].name
                key  = "loki_password"
              }
            }
          }
        ]
      }
    })
  ]

  depends_on = [kubernetes_namespace.alloy]
}
