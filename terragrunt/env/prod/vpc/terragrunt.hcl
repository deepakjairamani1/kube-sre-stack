# ---------------------------------------------------------------------------------------------------------------------
# VPC MODULE - PROD ENVIRONMENT
# Provisions the VPC with production-grade HA settings (multi-AZ, HA NAT gateways)
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
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["${local.region}a", "${local.region}b", "${local.region}c"]
  single_nat_gateway = false

  tags = {
    Environment = local.env
    Module      = "vpc"
  }
}
