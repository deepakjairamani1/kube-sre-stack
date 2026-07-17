# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "lb_hostname" {
  description = "Hostname of the Load Balancer provisioned for the ingress controller"
  value       = try(data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "lb_ip" {
  description = "IP address of the Load Balancer (if available, e.g., NLB with static IPs)"
  value       = try(data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].ip, "")
}

output "ingress_class_name" {
  description = "Name of the IngressClass created by this module"
  value       = var.ingress_class
}

output "namespace" {
  description = "Namespace where the ingress controller is deployed"
  value       = kubernetes_namespace.ingress.metadata[0].name
}

output "controller_service_name" {
  description = "Name of the ingress controller Kubernetes service"
  value       = "ingress-nginx-controller"
}
