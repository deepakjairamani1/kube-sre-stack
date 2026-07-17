# ---------------------------------------------------------------------------------------------------------------------
# INGRESS MODULE - DEV ENVIRONMENT
# Deploys Nginx Ingress Controller with minimal resources for development
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
    cluster_name                       = "kube-sre-stack-dev"
    cluster_endpoint                   = "https://mock-endpoint.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jay1jZXJ0LWRhdGE="
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  environment    = local.env
  cluster_name   = dependency.eks.outputs.cluster_name
  replica_count  = 1
  ingress_class  = "nginx"

  # Dev: minimal resources
  resource_requests_cpu    = "100m"
  resource_requests_memory = "128Mi"
  resource_limits_cpu      = "250m"
  resource_limits_memory   = "256Mi"

  # Dev: use CLB (cheaper), no NLB annotations
  service_annotations = {}

  tags = {
    Environment = local.env
    Module      = "ingress"
  }
}
