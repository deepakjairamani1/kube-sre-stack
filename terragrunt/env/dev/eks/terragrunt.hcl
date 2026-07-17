# ---------------------------------------------------------------------------------------------------------------------
# EKS MODULE - DEV ENVIRONMENT
# Provisions EKS cluster with dev-appropriate sizing (smaller nodes, fewer replicas)
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
  source = "${path_relative_to_include()}/../../../terraform/modules/eks"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES
# EKS depends on VPC for subnet and network configuration
# ---------------------------------------------------------------------------------------------------------------------
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  environment        = local.env
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  cluster_version    = "1.29"
  enable_karpenter   = true

  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      labels         = { role = "system" }
      taints         = []
    }
  }

  tags = {
    Environment = local.env
    Module      = "eks"
  }
}
