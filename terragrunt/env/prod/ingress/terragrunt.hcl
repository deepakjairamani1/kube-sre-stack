# ---------------------------------------------------------------------------------------------------------------------
# INGRESS MODULE - PROD ENVIRONMENT
# Deploys Nginx Ingress Controller with HA configuration and AWS NLB
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

# Read environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
}

terraform {
  source = "${path_relative_to_include()}/../../../terraform/modules/ingress"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES
# Ingress controller depends on EKS cluster
# ---------------------------------------------------------------------------------------------------------------------
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name                       = "kube-sre-stack-prod"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jay1jZXJ0LWRhdGE="
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  environment    = local.env
  cluster_name   = dependency.eks.outputs.cluster_name
  replica_count  = 3
  ingress_class  = "nginx"

  # Prod: HA resources
  resource_requests_cpu    = "500m"
  resource_requests_memory = "512Mi"
  resource_limits_cpu      = "1000m"
  resource_limits_memory   = "1Gi"

  # Prod: Use AWS NLB for better performance and static IPs
  service_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
    "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
  }

  tags = {
    Environment = local.env
    Module      = "ingress"
  }
}
