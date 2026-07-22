###############################################################################
# External Secrets Operator Module
#
# Installs ESO via Helm and configures it to read from AWS Secrets Manager.
# Uses IRSA (IAM Roles for Service Accounts) — no static credentials needed.
#
# Flow:
#   1. ESO watches for ExternalSecret resources in K8s
#   2. ESO reads the referenced secret from AWS Secrets Manager
#   3. ESO creates/updates a native K8s Secret with the value
#   4. Pods reference the K8s Secret as normal (envFrom, volume mounts)
#
# Why ESO over alternatives:
#   - Secrets stay in AWS Secrets Manager (single source of truth)
#   - K8s Secrets auto-rotate when AWS secret rotates
#   - No secrets in Git (not even encrypted — unlike SealedSecrets)
#   - IRSA means zero static credentials anywhere
###############################################################################

locals {
  namespace = "external-secrets"
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = local.namespace
    labels = {
      name        = local.namespace
      managed-by  = "terraform"
      environment = var.environment
    }
  }
}

# Helm release for External Secrets Operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  namespace  = local.namespace
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  values = [
    yamlencode({
      installCRDs = true

      serviceAccount = {
        create = true
        name   = "external-secrets"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
        }
      }

      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "256Mi"
        }
      }

      # Webhook for validation
      webhook = {
        resources = {
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
      }

      # Cert controller for webhook TLS
      certController = {
        resources = {
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "50m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.external_secrets]
}

###############################################################################
# IAM Role for External Secrets (IRSA)
###############################################################################

data "aws_iam_policy_document" "external_secrets_assume" {
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
      values   = ["system:serviceaccount:${local.namespace}:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project}-${var.environment}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "external-secrets"
  }
}

# Policy: Read-only access to Secrets Manager
data "aws_iam_policy_document" "secrets_access" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/${var.environment}/*"
    ]
  }

  # Allow decryption with KMS (if secrets are KMS-encrypted)
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.kms_key_arn]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "secrets_access" {
  name   = "secrets-manager-read"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.secrets_access.json
}
