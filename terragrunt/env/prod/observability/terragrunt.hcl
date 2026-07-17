# ---------------------------------------------------------------------------------------------------------------------
# OBSERVABILITY MODULE - PROD ENVIRONMENT
# Deploys monitoring stack with production retention and storage for full observability
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
  source = "${path_relative_to_include()}/../../../terraform/modules/observability"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES
# Observability stack depends on EKS cluster being available
# ---------------------------------------------------------------------------------------------------------------------
dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name     = "kube-sre-stack-prod"
    cluster_endpoint = "https://mock-endpoint.eks.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  environment               = local.env
  cluster_name              = dependency.eks.outputs.cluster_name
  prometheus_retention_days  = 30
  grafana_admin_password    = "changeme-prod"  # Override via environment variable TF_VAR_grafana_admin_password
  enable_kubecost           = true

  tags = {
    Environment = local.env
    Module      = "observability"
  }
}
