# Architecture Documentation

## Overview

Kube-SRE-Stack is a production-grade Kubernetes platform built on AWS EKS, designed around Site Reliability Engineering principles. The platform provides a complete operational framework including automated provisioning, GitOps-driven deployments, comprehensive observability, and cost-optimized autoscaling.

## Design Principles

1. **Infrastructure as Code** — All resources are defined in Terraform with remote state and locking
2. **GitOps** — All runtime configuration is declared in Git and reconciled by ArgoCD
3. **Least Privilege** — IAM Roles for Service Accounts (IRSA) provides pod-level access control
4. **Defense in Depth** — Network isolation, encryption at rest, IMDSv2, and audit logging
5. **Cost Efficiency** — Spot instances via Karpenter, right-sizing, and cost visibility through Kubecost
6. **Observable by Default** — Every component emits metrics; SLO-based alerting reduces noise

## Component Architecture

### Network Layer (VPC)

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20)
│   ├── NAT Gateways (1 per AZ in prod, 1 shared in dev)
│   ├── Application Load Balancers
│   └── Bastion hosts (if needed)
├── Private Subnets (10.0.48.0/20, 10.0.64.0/20, 10.0.80.0/20)
│   ├── EKS Control Plane ENIs
│   ├── Managed Node Groups
│   └── Karpenter-provisioned nodes
└── Database Subnets (10.0.96.0/24, 10.0.97.0/24, 10.0.98.0/24)
    ├── RDS instances
    └── ElastiCache clusters
```

Design decisions:
- `/20` subnets for public/private provide 4,094 IPs each — sufficient for large-scale pod networking with VPC CNI
- Database subnets have no internet route — isolated by design
- VPC Flow Logs enabled for security analysis and compliance

### Compute Layer (EKS)

**Cluster Configuration:**
- Private API endpoint (public in dev only for convenience)
- Secrets encrypted with customer-managed KMS key
- Full control plane logging (API, audit, authenticator, scheduler, controller-manager)
- EKS-managed addons: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver

**Node Strategy:**

| Node Group | Purpose | Instance Type | Capacity | Scaling |
|-----------|---------|---------------|----------|---------|
| System | Control plane workloads (ArgoCD, monitoring) | m6i.xlarge | On-Demand | 3-6 nodes |
| Monitoring | Prometheus, Grafana, Loki | r6i.large | On-Demand | 2-4 nodes |
| Default (Karpenter) | Application workloads | c6i/m6i/r6i | Spot + OD | 0-200 CPU |
| Spot Compute (Karpenter) | Batch/tolerant workloads | c6i/m6i | Spot only | 0-400 CPU |

### Autoscaling (Karpenter)

Karpenter replaces Cluster Autoscaler with significant advantages:
- **Provisioning speed**: 30-60s vs. 3-5min for new nodes
- **Instance diversity**: Selects from 20+ instance types for best availability and price
- **Consolidation**: Automatically bin-packs pods and removes underutilized nodes
- **Interruption handling**: Graceful pod migration on Spot interruption via SQS

### GitOps (ArgoCD)

```
Git Repository (source of truth)
    │
    ▼
ArgoCD Application Controller
    │
    ├── Sync: k8s/observability → observability namespace
    ├── Sync: k8s/karpenter → karpenter namespace
    └── Sync: app manifests → application namespaces
```

Configuration:
- **App of Apps** pattern for hierarchical deployment management
- **Automated sync** with self-heal and pruning enabled
- **RBAC** with SSO integration for team-based access control
- **Sync waves** ensure dependencies are deployed in order

### Observability

```
Metrics Pipeline:
  Application → ServiceMonitor → Prometheus → Grafana
                                     │
                                     ▼
                              AlertManager → PagerDuty/Slack
                                     │
                                     ▼
                              Recording Rules → SLO Dashboards
```

**Key SLOs Tracked:**
- API Availability: 99.9% (allows ~43min downtime/month)
- API Latency P99: < 500ms for 99.5% of requests
- Deployment Success Rate: 99%

**Alerting Philosophy:**
- Multi-window, multi-burn-rate alerts (Google SRE book Chapter 5)
- Critical alerts: 1h + 6h burn rate exceeded → page
- Warning alerts: 6h burn rate elevated → ticket
- No alerts on symptoms without customer impact

### Cost Management

- **Kubecost** provides real-time namespace and workload cost attribution
- **Karpenter Spot** saves 60-70% on compute for fault-tolerant workloads
- **Single NAT Gateway** in non-prod saves ~$100/month per extra gateway
- **Right-sized monitoring** — dev retains 7 days, prod retains 30 days

## Security

- **Encryption at rest**: EKS secrets via KMS, EBS volumes encrypted
- **Encryption in transit**: TLS everywhere, ALB terminates external TLS
- **IMDSv2 enforced**: Prevents SSRF credential theft
- **Network policies**: Default-deny with explicit allow rules
- **IRSA**: No shared node credentials; pods assume only their required roles
- **Audit logging**: EKS control plane logs to CloudWatch for 90 days

## Disaster Recovery

| Component | RPO | RTO | Strategy |
|-----------|-----|-----|----------|
| Terraform State | 0 | 5min | S3 versioning + cross-region replication |
| EKS Cluster | N/A | 30min | Recreate from Terraform |
| Application State | GitOps | 10min | ArgoCD re-sync from Git |
| Persistent Data | 1h | 1h | EBS snapshots + RDS automated backups |

## Scaling Limits

Current architecture tested and validated for:
- 200 nodes (Karpenter managed)
- 5,000 pods
- 50,000 active users
- 10,000 requests/second
