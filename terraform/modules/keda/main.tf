###############################################################################
# KEDA Module — Kubernetes Event-Driven Autoscaler
#
# Why KEDA over plain HPA:
#   - HPA only scales on CPU/memory (resource metrics)
#   - KEDA scales on ANY signal: Prometheus queries, SQS queue depth,
#     RabbitMQ messages, HTTP request rate, custom metrics
#   - KEDA can scale to zero (HPA minimum is 1)
#   - KEDA integrates with 50+ event sources
#
# For PiggyMetrics:
#   - Scale notification-service based on RabbitMQ queue depth
#   - Scale gateway based on HTTP RPS (not just CPU)
#   - Scale account-service based on P99 latency threshold
###############################################################################

locals {
  namespace = "keda"
}

resource "kubernetes_namespace" "keda" {
  metadata {
    name = local.namespace
    labels = {
      name       = local.namespace
      managed-by = "terraform"
    }
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  namespace  = local.namespace
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "keda-operator"
        annotations = var.enable_irsa ? {
          "eks.amazonaws.com/role-arn" = aws_iam_role.keda[0].arn
        } : {}
      }

      resources = {
        operator = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
        metricsServer = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      prometheus = {
        metricServer = {
          enabled = true
        }
        operator = {
          enabled = true
        }
      }

      podDisruptionBudget = {
        operator = {
          minAvailable = 1
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.keda]
}

###############################################################################
# IRSA for KEDA (optional — needed for SQS/CloudWatch scaling)
###############################################################################

resource "aws_iam_role" "keda" {
  count = var.enable_irsa ? 1 : 0

  name               = "${var.project}-${var.environment}-keda"
  assume_role_policy = data.aws_iam_policy_document.keda_assume[0].json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "keda_assume" {
  count = var.enable_irsa ? 1 : 0

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
      values   = ["system:serviceaccount:${local.namespace}:keda-operator"]
    }
  }
}

data "aws_iam_policy_document" "keda_permissions" {
  count = var.enable_irsa ? 1 : 0

  # SQS permissions (for queue-based scaling)
  statement {
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = ["arn:aws:sqs:${var.region}:*:${var.project}-*"]
  }

  # CloudWatch permissions (for metric-based scaling)
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "keda" {
  count = var.enable_irsa ? 1 : 0

  name   = "keda-scaling-permissions"
  role   = aws_iam_role.keda[0].id
  policy = data.aws_iam_policy_document.keda_permissions[0].json
}
