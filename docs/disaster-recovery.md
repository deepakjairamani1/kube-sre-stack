# Disaster Recovery Architecture

## RTO/RPO Targets

| Metric | Target | How We Achieve It |
|--------|--------|-------------------|
| **RPO** (data loss tolerance) | < 1 hour | Hourly backups of critical resources |
| **RTO** (recovery time) | < 30 minutes | Automated restore + ArgoCD reconciliation |

## Backup Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKUP TIERS                                   │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  HOURLY (every 1h, retain 3d)                             │  │
│  │  • K8s resources: Deployments, StatefulSets, Services     │  │
│  │  • No PV snapshots (fast, cheap)                          │  │
│  │  • RPO: 1 hour                                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  DAILY (2 AM UTC, retain 30d)                             │  │
│  │  • Full namespace (piggymetrics)                          │  │
│  │  • EBS volume snapshots (MongoDB data)                    │  │
│  │  • MongoDB fsync pre-hook for consistency                 │  │
│  │  • Transition to Glacier after 30d                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  WEEKLY (Sunday 3 AM UTC, retain 90d)                     │  │
│  │  • All platform namespaces                                │  │
│  │  • Full PV snapshots                                      │  │
│  │  • ArgoCD config, observability, ingress included         │  │
│  │  • Cross-region replication (if enabled)                  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Restore Procedures

### Scenario 1: Single Service Failure (RTO: 5 min)

ArgoCD self-heals. No manual action needed.
```bash
# Verify ArgoCD detected the drift
kubectl get application piggymetrics-prod -n argocd -o jsonpath='{.status.sync.status}'
# Expected: "Synced" (ArgoCD auto-fixed it)
```

### Scenario 2: Namespace Accidentally Deleted (RTO: 10 min)

```bash
# 1. List available backups
velero backup get -n velero | grep piggymetrics

# 2. Restore from latest backup
velero restore create --from-backup piggymetrics-daily-YYYYMMDD \
  --include-namespaces piggymetrics \
  --restore-volumes=true

# 3. Monitor restore progress
velero restore describe <restore-name> -n velero

# 4. Verify services are running
kubectl get pods -n piggymetrics
kubectl get svc -n piggymetrics
```

### Scenario 3: Data Corruption (RTO: 15 min)

```bash
# 1. Scale down the affected service (prevent further writes)
kubectl scale deployment account-service -n piggymetrics --replicas=0

# 2. Restore MongoDB from snapshot (point-in-time)
velero restore create --from-backup piggymetrics-daily-YYYYMMDD \
  --include-namespaces piggymetrics \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --selector app.kubernetes.io/name=mongodb \
  --restore-volumes=true

# 3. Wait for PVs to attach
kubectl get pvc -n piggymetrics -w

# 4. Scale service back up
kubectl scale deployment account-service -n piggymetrics --replicas=2

# 5. Verify data integrity
kubectl exec mongodb-0 -n piggymetrics -- mongosh --eval "db.adminCommand('dbHash')"
```

### Scenario 4: Full Cluster Loss (RTO: 30 min)

```bash
# 1. Provision new EKS cluster via Terragrunt
cd terragrunt/env/prod
terragrunt run-all apply

# 2. Install Velero on new cluster
# (Terraform module handles this, or manual Helm install pointing to same S3 bucket)

# 3. Restore platform infrastructure first
velero restore create --from-backup cluster-weekly-YYYYMMDD \
  --include-namespaces argocd,observability,ingress-nginx,external-secrets,velero

# 4. Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 5. ArgoCD reconciles all applications automatically
# (ApplicationSets redeploy piggymetrics from Git)

# 6. Restore data volumes (MongoDB)
velero restore create --from-backup piggymetrics-daily-YYYYMMDD \
  --include-namespaces piggymetrics \
  --restore-volumes=true

# 7. Verify
kubectl get pods -A | grep -v Running
```

## DR Validation

Weekly automated validation proves:
- ✅ Latest backup exists and is Completed
- ✅ Backup is fresh (< 25 hours old)
- ✅ Backup contains expected resources
- ✅ Slack report: green/red for visibility

## Architecture Diagram

```
┌─────────────────┐         ┌─────────────────┐
│  Primary Region │         │    DR Region     │
│   (us-east-1)   │         │   (us-west-2)   │
│                 │         │                 │
│  ┌───────────┐  │   S3    │  ┌───────────┐  │
│  │    EKS    │  │  CRR    │  │  (Standby) │  │
│  │  Cluster  │  │ ──────▶ │  │  S3 Bucket │  │
│  └─────┬─────┘  │         │  └───────────┘  │
│        │        │         │                 │
│  ┌─────▼─────┐  │         │  In case of     │
│  │  Velero   │  │         │  regional        │
│  │  (Backup) │──│─────────│──failure:        │
│  └─────┬─────┘  │         │  1. Spin up EKS  │
│        │        │         │  2. Point Velero  │
│  ┌─────▼─────┐  │         │     to replica   │
│  │ S3 Bucket │  │         │  3. Restore      │
│  │ (Primary) │  │         │                 │
│  └───────────┘  │         │  RTO: ~30 min    │
└─────────────────┘         └─────────────────┘
```

## Alerts

| Alert | Trigger | Severity |
|-------|---------|----------|
| `VeleroBackupFailed` | Backup phase != Completed | Critical |
| `VeleroBackupStale` | No successful backup in 25h | Critical |
| `VeleroBackupPartialFailure` | Some resources failed | Warning |
| `DRValidationFailed` | Weekly validation check failed | Critical |
