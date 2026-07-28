variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "chart_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "5.4.0"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for backup encryption"
  type        = string
}

variable "backup_retention_days" {
  description = "Days to retain backups before deletion"
  type        = number
  default     = 90
}

variable "enable_cross_region_replication" {
  description = "Enable S3 cross-region replication for DR"
  type        = bool
  default     = false
}
