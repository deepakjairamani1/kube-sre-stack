# ---------------------------------------------------------------------------------------------------------------------
# DEV ENVIRONMENT CONFIGURATION
# Environment-specific variables for the development environment
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment  = "dev"
  aws_region   = "us-east-1"
  cluster_size = "small"

  # Dev-specific settings
  enable_deletion_protection = false
  enable_multi_az            = false
}
