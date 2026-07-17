# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster where ingress will be deployed"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "namespace" {
  description = "Kubernetes namespace for the ingress controller"
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "Version of the ingress-nginx Helm chart"
  type        = string
  default     = "4.9.1"
}

variable "replica_count" {
  description = "Number of ingress controller replicas"
  type        = number
  default     = 2

  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "Replica count must be between 1 and 10."
  }
}

variable "ingress_class" {
  description = "Name of the IngressClass resource"
  type        = string
  default     = "nginx"
}

variable "set_as_default_ingress_class" {
  description = "Set this ingress class as the cluster default"
  type        = string
  default     = "true"
}

variable "resource_requests_cpu" {
  description = "CPU request for the ingress controller pods"
  type        = string
  default     = "250m"
}

variable "resource_requests_memory" {
  description = "Memory request for the ingress controller pods"
  type        = string
  default     = "256Mi"
}

variable "resource_limits_cpu" {
  description = "CPU limit for the ingress controller pods"
  type        = string
  default     = "500m"
}

variable "resource_limits_memory" {
  description = "Memory limit for the ingress controller pods"
  type        = string
  default     = "512Mi"
}

variable "service_annotations" {
  description = "Annotations for the ingress controller Service (e.g., AWS NLB config)"
  type        = map(string)
  default     = {}
}

variable "enable_service_monitor" {
  description = "Enable Prometheus ServiceMonitor for ingress metrics"
  type        = string
  default     = "true"
}

variable "additional_values" {
  description = "Additional Helm values in YAML format for advanced configuration"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
