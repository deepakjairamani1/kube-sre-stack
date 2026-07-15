###############################################################################
# Observability Module - Prometheus, Grafana, AlertManager via Helm
#
# Deploys the kube-prometheus-stack which includes:
# - Prometheus (metrics collection and alerting)
# - Grafana (visualization and dashboards)
# - AlertManager (alert routing and notification)
# - Node Exporter (host-level metrics)
# - kube-state-metrics (Kubernetes object metrics)
#
# Optionally deploys Kubecost for cost monitoring.
###############################################################################

locals {
  namespace = "observability"
}

###############################################################################
# Namespace
###############################################################################

resource "kubernetes_namespace" "observability" {
  metadata {
    name = local.namespace

    labels = {
      name        = local.namespace
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

###############################################################################
# Prometheus + Grafana (kube-prometheus-stack)
###############################################################################

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "56.6.2"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  timeout = 600

  values = [
    yamlencode({
      # Global settings
      fullnameOverride = "prometheus"

      # Prometheus configuration
      prometheus = {
        prometheusSpec = {
          retention         = "${var.prometheus_retention_days}d"
          retentionSize     = var.environment == "prod" ? "45GB" : "15GB"
          replicas          = var.environment == "prod" ? 2 : 1
          scrapeInterval    = "30s"
          evaluationInterval = "30s"

          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.environment == "prod" ? "50Gi" : "20Gi"
                  }
                }
              }
            }
          }

          # Resource limits
          resources = {
            requests = {
              memory = var.environment == "prod" ? "4Gi" : "1Gi"
              cpu    = var.environment == "prod" ? "2" : "500m"
            }
            limits = {
              memory = var.environment == "prod" ? "8Gi" : "2Gi"
              cpu    = var.environment == "prod" ? "4" : "1"
            }
          }

          # Additional scrape configs for custom service discovery
          additionalScrapeConfigs = [
            {
              job_name = "kubernetes-pods"
              kubernetes_sd_configs = [{
                role = "pod"
              }]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action        = "keep"
                  regex         = "true"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                  action        = "replace"
                  target_label  = "__metrics_path__"
                  regex         = "(.+)"
                },
                {
                  source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                  action        = "replace"
                  regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                  replacement   = "$1:$2"
                  target_label  = "__address__"
                }
              ]
            }
          ]
        }
      }

      # Grafana configuration
      grafana = {
        replicas       = var.environment == "prod" ? 2 : 1
        adminPassword  = var.grafana_admin_password

        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name      = "default"
              orgId     = 1
              folder    = "SRE"
              type      = "file"
              disableDeletion = true
              editable  = false
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }]
          }
        }

        persistence = {
          enabled          = true
          storageClassName = "gp3"
          size             = "10Gi"
        }

        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "100m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }

        # Enable useful Grafana plugins
        plugins = [
          "grafana-piechart-panel",
          "grafana-clock-panel",
          "grafana-polystat-panel"
        ]
      }

      # AlertManager configuration
      alertmanager = {
        alertmanagerSpec = {
          replicas = var.environment == "prod" ? 3 : 1
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp3"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }

      # Node Exporter
      nodeExporter = {
        enabled = true
      }

      # kube-state-metrics
      kubeStateMetrics = {
        enabled = true
      }

      # Default PrometheusRules for SRE alerting
      defaultRules = {
        create = true
        rules = {
          alertmanager                = true
          etcd                        = false # Managed by EKS
          configReloaders             = true
          general                     = true
          k8s                         = true
          kubeApiserverAvailability   = true
          kubeApiserverBurnrate       = true
          kubeApiserverHistogram      = true
          kubeApiserverSlos           = true
          kubeControllerManager       = false # Managed by EKS
          kubelet                     = true
          kubeProxy                   = false # Managed by EKS
          kubePrometheusGeneral       = true
          kubePrometheusNodeRecording = true
          kubernetesApps              = true
          kubernetesResources         = true
          kubernetesStorage           = true
          kubernetesSystem            = true
          kubeSchedulerAlerting       = false # Managed by EKS
          kubeSchedulerRecording      = false # Managed by EKS
          network                     = true
          node                        = true
          nodeExporterAlerting        = true
          nodeExporterRecording       = true
          prometheus                  = true
          prometheusOperator          = true
        }
      }
    })
  ]

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
}

###############################################################################
# Kubecost (optional, for cost visibility)
###############################################################################

resource "helm_release" "kubecost" {
  count = var.enable_kubecost ? 1 : 0

  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  version    = "2.1.0"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  timeout = 300

  values = [
    yamlencode({
      prometheus = {
        # Use existing Prometheus from kube-prometheus-stack
        kube-state-metrics = { disabled = true }
        nodeExporter       = { enabled = false }
      }
      global = {
        prometheus = {
          enabled  = false
          fqdn    = "http://prometheus-prometheus.${local.namespace}.svc:9090"
        }
      }
      kubecostMetrics = {
        emitPodAnnotations  = true
        emitNamespaceAnnotations = true
      }
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}
