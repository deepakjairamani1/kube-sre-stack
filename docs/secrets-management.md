# Secrets Management Architecture

## Overview

This project uses **External Secrets Operator (ESO)** to bridge AWS Secrets Manager with Kubernetes. No secrets are stored in Git — ever.

```
┌────────────────────────────────────────────────────────────────────┐
│                     SECRETS FLOW                                    │
│                                                                    │
│  ┌─────────────────┐         ┌─────────────────────────────────┐  │
│  │  AWS Secrets     │         │         KUBERNETES               │  │
│  │  Manager         │         │                                 │  │
│  │                  │  IRSA   │  ┌──────────────────────────┐   │  │
│  │  kube-sre-stack/ │◄────────│──│ External Secrets Operator│   │  │
│  │    piggymetrics/ │         │  │  (watches ExternalSecret) │   │  │
│  │      mongodb     │─────────│─▶│                          │   │  │
│  │      rabbitmq    │         │  └────────────┬─────────────┘   │  │
│  │      smtp        │         │               │                 │  │
│  │      config-svc  │         │               ▼ creates/updates │  │
│  │      account-svc │         │  ┌──────────────────────────┐   │  │
│  │      ...         │         │  │   K8s Secret (native)     │   │  │
│  └─────────────────┘         │  │   piggymetrics-mongodb-   │   │  │
│                               │  │   credentials             │   │  │
│  ┌─────────────────┐         │  └────────────┬─────────────┘   │  │
│  │  AWS KMS         │         │               │                 │  │
│  │  (encryption)    │         │               ▼ envFrom/volume  │  │
│  └─────────────────┘         │  ┌──────────────────────────┐   │  │
│                               │  │   Pod (account-service)   │   │  │
│                               │  │   MONGODB_URI=mongodb://..│   │  │
│                               │  └──────────────────────────┘   │  │
│                               └─────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

## How It Works

1. **Terraform** deploys ESO with IRSA (IAM role for the service account)
2. **ClusterSecretStore** connects ESO to AWS Secrets Manager
3. **ExternalSecret** resources specify which AWS secrets to fetch
4. **ESO** creates native K8s Secrets from AWS values
5. **Pods** consume K8s Secrets normally (envFrom, volume mounts)
6. **Refresh** happens every 1 hour — rotated credentials auto-propagate

## Secret Path Convention

```
kube-sre-stack/{environment}/piggymetrics/{service-name}
```

Example:
```
kube-sre-stack/dev/piggymetrics/mongodb     → {"username": "...", "password": "..."}
kube-sre-stack/prod/piggymetrics/mongodb    → {"username": "...", "password": "..."}
kube-sre-stack/dev/piggymetrics/rabbitmq    → {"username": "...", "password": "..."}
```

## Adding a New Secret

```bash
# 1. Create secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "kube-sre-stack/dev/piggymetrics/my-new-service" \
  --secret-string '{"api_key": "abc123", "api_secret": "xyz789"}'

# 2. Create ExternalSecret in Git
cat <<EOF > k8s/secrets/my-new-service.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-new-service
  namespace: piggymetrics
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: my-new-service-credentials
  data:
    - secretKey: API_KEY
      remoteRef:
        key: kube-sre-stack/dev/piggymetrics/my-new-service
        property: api_key
    - secretKey: API_SECRET
      remoteRef:
        key: kube-sre-stack/dev/piggymetrics/my-new-service
        property: api_secret
EOF

# 3. Commit + push → ArgoCD syncs → ESO fetches → Pod has credentials
```

## Rotation

When secrets are rotated in AWS Secrets Manager:
- ESO detects the change on next refresh (within 1 hour)
- K8s Secret is updated automatically
- Pods using `envFrom` need restart to pick up new values
- Pods using volume mounts get updated without restart (kubelet refresh)

To force immediate sync:
```bash
kubectl annotate externalsecret <name> -n piggymetrics \
  force-sync=$(date +%s) --overwrite
```

## Monitoring

Alerts fire when:
- `ExternalSecretSyncFailed` — can't fetch from AWS (5 min)
- `ExternalSecretStale` — hasn't refreshed in 2+ hours
- `ClusterSecretStoreUnhealthy` — store connectivity broken

## Security Principles

1. **No secrets in Git** — not even encrypted (unlike SealedSecrets)
2. **No static credentials** — IRSA provides temporary credentials via STS
3. **Least privilege** — ESO can only read secrets under its project path
4. **Encryption at rest** — AWS KMS encrypts all secrets in Secrets Manager
5. **Audit trail** — CloudTrail logs every secret access
6. **Namespace isolation** — ExternalSecrets are namespace-scoped
