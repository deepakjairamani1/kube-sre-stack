# ---------------------------------------------------------------------------------------------------------------------
# NGINX INGRESS CONTROLLER MODULE
# Deploys the ingress-nginx controller via Helm chart with configurable replicas,
# resource limits, and AWS load balancer annotations.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NAMESPACE
# Create a dedicated namespace for the ingress controller
# ---------------------------------------------------------------------------------------------------------------------
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "ingress-nginx"
      "app.kubernetes.io/managed-by" = "terraform"
      "environment"                  = var.environment
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# HELM RELEASE - NGINX INGRESS CONTROLLER
# Deploys the ingress-nginx chart with environment-appropriate configuration
# ---------------------------------------------------------------------------------------------------------------------
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true
  wait            = true

  # Controller configuration
  set {
    name  = "controller.replicaCount"
    value = var.replica_count
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = var.ingress_class
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = var.set_as_default_ingress_class
  }

  # Resource requests and limits
  set {
    name  = "controller.resources.requests.cpu"
    value = var.resource_requests_cpu
  }

  set {
    name  = "controller.resources.requests.memory"
    value = var.resource_requests_memory
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = var.resource_limits_cpu
  }

  set {
    name  = "controller.resources.limits.memory"
    value = var.resource_limits_memory
  }

  # Service type
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Pod disruption budget for HA
  set {
    name  = "controller.minAvailable"
    value = var.replica_count > 1 ? 1 : 0
  }

  # Metrics for observability
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = var.enable_service_monitor
  }

  # Anti-affinity for HA deployments
  dynamic "set" {
    for_each = var.replica_count > 1 ? [1] : []
    content {
      name  = "controller.topologySpreadConstraints[0].maxSkew"
      value = "1"
    }
  }

  dynamic "set" {
    for_each = var.replica_count > 1 ? [1] : []
    content {
      name  = "controller.topologySpreadConstraints[0].topologyKey"
      value = "topology.kubernetes.io/zone"
    }
  }

  dynamic "set" {
    for_each = var.replica_count > 1 ? [1] : []
    content {
      name  = "controller.topologySpreadConstraints[0].whenUnsatisfiable"
      value = "DoNotSchedule"
    }
  }

  dynamic "set" {
    for_each = var.replica_count > 1 ? [1] : []
    content {
      name  = "controller.topologySpreadConstraints[0].labelSelector.matchLabels.app\\.kubernetes\\.io/component"
      value = "controller"
    }
  }

  # Service annotations (e.g., AWS NLB configuration)
  dynamic "set" {
    for_each = var.service_annotations
    content {
      name  = "controller.service.annotations.${replace(set.key, ".", "\\.")}"
      value = set.value
    }
  }

  # Additional values via YAML for complex configurations
  values = var.additional_values != "" ? [var.additional_values] : []
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCE
# Fetch the LoadBalancer hostname after deployment
# ---------------------------------------------------------------------------------------------------------------------
data "kubernetes_service" "ingress_nginx" {
  depends_on = [helm_release.ingress_nginx]

  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress.metadata[0].name
  }
}
