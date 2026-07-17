# ---------------------------------------------------------------------------------------------------------------------
# VPC MODULE - DEV ENVIRONMENT
# Provisions the VPC with dev-appropriate settings (cost-optimized, single NAT)
# ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders()
}

# Read environment-specific variables
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.environment
  region   = local.env_vars.locals.aws_region
}

terraform {
  source = "${path_relative_to_include()}/../../../terraform/modules/vpc"
}

inputs = {
  environment        = local.env
  vpc_cidr           = "10.0.0.0/20"
  availability_zones = ["${local.region}a", "${local.region}b"]
  single_nat_gateway = true

  tags = {
    Environment = local.env
    Module      = "vpc"
  }
}
