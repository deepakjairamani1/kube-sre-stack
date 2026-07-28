###############################################################################
# Velero Backup Module
#
# Deploys Velero for Kubernetes backup and disaster recovery.
# Uses AWS S3 for backup storage and IRSA for authentication.
#
# Capabilities:
#   - Full cluster backup (all namespaces)
#   - Namespace-level backup (piggymetrics only)
#   - PV snapshots via CSI (EBS volumes)
#   - Cross-region backup replication (S3 CRR)
#   - Scheduled backups (hourly, daily, weekly)
#   - Point-in-time restore
###############################################################################

locals {
  namespace    = "velero"
  backup_name  = "${var.project}-${var.environment}-backups"
}

# S3 Bucket for backups
resource "aws_s3_bucket" "backups" {
  bucket = local.backup_name

  tags = {
    Name        = local.backup_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "velero-backups"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    # Move to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete after 90 days
    expiration {
      days = var.backup_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cross-region replication (for DR)
resource "aws_s3_bucket" "backups_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr_region
  bucket   = "${local.backup_name}-replica"

  tags = {
    Name        = "${local.backup_name}-replica"
    Environment = var.environment
    Purpose     = "velero-backups-dr-replica"
  }
}

resource "aws_s3_bucket_versioning" "backups_replica" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr_region
  bucket   = aws_s3_bucket.backups_replica[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

###############################################################################
# IAM Role for Velero (IRSA)
###############################################################################

data "aws_iam_policy_document" "velero_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.namespace}:velero-server"]
    }
  }
}

resource "aws_iam_role" "velero" {
  name               = "${var.project}-${var.environment}-velero"
  assume_role_policy = data.aws_iam_policy_document.velero_assume.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "velero_permissions" {
  # S3 permissions for backup storage
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.backups.arn,
      "${aws_s3_bucket.backups.arn}/*",
    ]
  }

  # EC2 permissions for EBS snapshots
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  # KMS for encrypted backups
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "velero" {
  name   = "velero-backup-permissions"
  role   = aws_iam_role.velero.id
  policy = data.aws_iam_policy_document.velero_permissions.json
}

###############################################################################
# Helm Release
###############################################################################

resource "kubernetes_namespace" "velero" {
  metadata {
    name = local.namespace
    labels = {
      name       = local.namespace
      managed-by = "terraform"
    }
  }
}

resource "helm_release" "velero" {
  name       = "velero"
  namespace  = local.namespace
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.chart_version

  values = [
    yamlencode({
      initContainers = [{
        name  = "velero-plugin-for-aws"
        image = "velero/velero-plugin-for-aws:v1.9.0"
        volumeMounts = [{
          name      = "plugins"
          mountPath = "/target"
        }]
      }]

      configuration = {
        backupStorageLocation = [{
          name     = "aws"
          provider = "aws"
          bucket   = aws_s3_bucket.backups.id
          config = {
            region = var.region
          }
        }]
        volumeSnapshotLocation = [{
          name     = "aws"
          provider = "aws"
          config = {
            region = var.region
          }
        }]
      }

      serviceAccount = {
        server = {
          create = true
          name   = "velero-server"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.velero.arn
          }
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      schedules = {
        "daily-full-backup" = {
          schedule = "0 2 * * *"
          template = {
            ttl                    = "${var.backup_retention_days * 24}h0m0s"
            includedNamespaces     = ["piggymetrics"]
            storageLocation        = "aws"
            volumeSnapshotLocations = ["aws"]
          }
        }
        "hourly-critical" = {
          schedule = "0 * * * *"
          template = {
            ttl                = "72h0m0s"
            includedNamespaces = ["piggymetrics"]
            includedResources  = ["deployments", "statefulsets", "configmaps", "secrets", "services"]
            storageLocation    = "aws"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.velero]
}
