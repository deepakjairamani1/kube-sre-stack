# ---------------------------------------------------------------------------------------------------------------------
# PROD ENVIRONMENT CONFIGURATION
# Environment-specific variables for the production environment
# ---------------------------------------------------------------------------------------------------------------------

locals {
  environment  = "prod"
  aws_region   = "us-east-1"
  cluster_size = "large"

  # Prod-specific settings
  enable_deletion_protection = true
  enable_multi_az            = true
}
