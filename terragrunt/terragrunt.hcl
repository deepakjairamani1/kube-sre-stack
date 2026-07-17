# ---------------------------------------------------------------------------------------------------------------------
# ROOT TERRAGRUNT CONFIGURATION
# This file is the root configuration that all child terragrunt.hcl files include.
# It defines the remote state backend, provider generation, and common inputs.
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Parse the env.hcl file from the environment directory
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment  = local.env_vars.locals.environment
  aws_region   = local.env_vars.locals.aws_region
  project_name = "kube-sre-stack"
}

# ---------------------------------------------------------------------------------------------------------------------
# REMOTE STATE CONFIGURATION
# S3 backend with DynamoDB locking, parameterized by environment
# ---------------------------------------------------------------------------------------------------------------------
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "${local.project_name}-terraform-state-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "${local.project_name}-terraform-locks-${local.environment}"

    s3_bucket_tags = {
      Name        = "${local.project_name}-terraform-state-${local.environment}"
      Environment = local.environment
      ManagedBy   = "terragrunt"
    }

    dynamodb_table_tags = {
      Name        = "${local.project_name}-terraform-locks-${local.environment}"
      Environment = local.environment
      ManagedBy   = "terragrunt"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER GENERATION
# Generate the AWS provider configuration for all child modules
# ---------------------------------------------------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Environment = "${local.environment}"
          Project     = "${local.project_name}"
          ManagedBy   = "terragrunt"
        }
      }
    }
  EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# TERRAFORM VERSION CONSTRAINT
# ---------------------------------------------------------------------------------------------------------------------
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5.0"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
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
  EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# COMMON INPUTS
# These inputs are passed to all child modules
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  project     = local.project_name
  environment = local.environment
  aws_region  = local.aws_region

  tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "terragrunt"
  }
}
