output "backup_bucket_name" {
  description = "S3 bucket name for Velero backups"
  value       = aws_s3_bucket.backups.id
}

output "backup_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.backups.arn
}

output "velero_iam_role_arn" {
  description = "IAM role ARN for Velero"
  value       = aws_iam_role.velero.arn
}

output "replica_bucket_name" {
  description = "DR replica bucket name (if enabled)"
  value       = var.enable_cross_region_replication ? aws_s3_bucket.backups_replica[0].id : null
}
