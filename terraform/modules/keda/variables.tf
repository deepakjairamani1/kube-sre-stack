variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "chart_version" {
  type    = string
  default = "2.13.1"
}

variable "enable_irsa" {
  description = "Enable IRSA for AWS scaler access (SQS, CloudWatch)"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL"
  type        = string
  default     = ""
}
