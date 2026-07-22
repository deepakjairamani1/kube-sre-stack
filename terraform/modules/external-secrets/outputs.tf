output "iam_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}

output "namespace" {
  description = "Namespace where ESO is installed"
  value       = local.namespace
}

output "service_account_name" {
  description = "Service account name used by ESO"
  value       = "external-secrets"
}
