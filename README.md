# 🚀 Kube-SRE-Stack

> **Production-ready Kubernetes platform with built-in SRE practices**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-623CE4?logo=terraform)](https://www.terraform.io/)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-Multi--Env-blue?logo=terraform)](https://terragrunt.gruntwork.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io/cd/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana)](https://grafana.com/)
[![Velero](https://img.shields.io/badge/Velero-DR_Backups-1a5276)](https://velero.io/)
[![k6](https://img.shields.io/badge/k6-Load_Testing-7d64ff?logo=k6)](https://k6.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Account                                     │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         VPC (Multi-AZ)                                │  │
│  │                                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │  │
│  │  │  AZ-1 (a)   │  │  AZ-2 (b)   │  │  AZ-3 (c)   │                  │  │
│  │  │             │  │             │  │             │                  │  │
│  │  │ Public Sub  │  │ Public Sub  │  │ Public Sub  │  ← ALB/NLB      │  │
│  │  │ Private Sub │  │ Private Sub │  │ Private Sub │  ← EKS Nodes    │  │
│  │  │ DB Sub      │  │ DB Sub      │  │ DB Sub      │  ← RDS/ElastiC  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    EKS Control Plane                            │  │  │
│  │  │                                                                 │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────────────┐ │  │  │
│  │  │  │ ArgoCD   │ │Karpenter │ │Prometheus │ │  Application     │ │  │  │
│  │  │  │ (GitOps) │ │(Scaling) │ │+ Grafana  │ │  Workloads       │ │  │  │
│  │  │  └──────────┘ └──────────┘ └───────────┘ └──────────────────┘ │  │  │
│  │  │                                                                 │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────────────┐ │  │  │
│  │  │  │AlertMgr  │ │ Kubecost │ │SLO Monitor│ │  Incident Bot    │ │  │  │
│  │  │  │(Paging)  │ │ (Cost)   │ │(Pyrra)    │ │  (Auto-respond)  │ │  │  │
│  │  │  └──────────┘ └──────────┘ └───────────┘ └──────────────────┘ │  │  │
│  │  │                                                                 │  │  │
│  │  │  Node Groups: system (On-Demand) + Karpenter (Spot/OD mix)     │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  External: Route53 → ACM → ALB Ingress Controller → Services               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ✨ Features

| Category | Component | Description |
|----------|-----------|-------------|
| **Infrastructure** | EKS + Karpenter | Auto-scaling Kubernetes with cost-optimized Spot node provisioning |
| **IaC** | Terragrunt + Terraform | Multi-environment (dev/prod) with dependency graph and remote state |
| **GitOps** | ArgoCD + ApplicationSets | Declarative delivery with canary rollouts (Argo Rollouts) |
| **Observability** | Prometheus + Grafana | ServiceMonitors, recording rules, Golden Signal dashboards |
| **Alerting** | AlertManager + SLO Burn Rate | Multi-window multi-burn-rate alerting (Google SRE Workbook pattern) |
| **Secrets** | External Secrets Operator | AWS Secrets Manager integration via IRSA (zero static credentials) |
| **Disaster Recovery** | Velero + S3 Cross-Region | Three-tier backups (hourly/daily/weekly), RTO < 30m, RPO < 1h |
| **Auto-Remediation** | CronJobs + Prometheus | Self-healing: restart crashloops, scale on latency, disk cleanup |
| **Load Testing** | k6 | SLO validation under load: ramp, spike, and 30-min soak tests |
| **Security** | Network Policies + IRSA | Zero-trust networking, pod-level least-privilege, PDBs |
| **Cost Optimization** | Kubecost + Karpenter Spot | Real-time cost visibility, Spot diversification, rightsizing |
| **CI/CD** | GitHub Actions | Terraform validate, kubeconform, Checkov, Trivy, Infracost |
| **Microservices** | PiggyMetrics (10 services) | Full Spring Boot microservices deployed with Kustomize overlays |

## 🏁 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5, Terragrunt >= 0.55
- kubectl, Helm 3.x
- k6 (for load testing)

### Deploy Infrastructure (Terragrunt)

```bash
# Clone the repository
git clone https://github.com/deepakjairamani1/kube-sre-stack.git
cd kube-sre-stack

# Deploy dev environment (VPC → EKS → Observability → Ingress)
cd terragrunt/env/dev
terragrunt run-all plan     # Review changes
terragrunt run-all apply    # Deploy (respects dependency order)

# Configure kubectl
aws eks update-kubeconfig --name kube-sre-stack-dev --region us-east-1
```

### Deploy Platform via ArgoCD

```bash
# Install ArgoCD
kubectl apply -f k8s/argocd/install.yaml

# Deploy all applications (ArgoCD auto-discovers from Git)
kubectl apply -f k8s/argocd/projects/
kubectl apply -f k8s/argocd/applicationsets/

# ArgoCD reconciles everything: observability, alerting, PiggyMetrics, secrets, DR
kubectl get applications -n argocd
```

### Deploy PiggyMetrics (Dev)

```bash
# Using Kustomize overlay directly (or let ArgoCD handle it)
kubectl apply -k k8s/apps/piggymetrics/overlays/dev/
```

### Run Load Tests

```bash
cd tests/load
make gateway          # 8 min, ramp to 150 VUs
make auth             # 4 min, spike test
make soak             # 30 min, stability test
```

### Access Dashboards

```bash
# Grafana (default: admin/prom-operator)
kubectl port-forward svc/kube-prometheus-stack-grafana -n observability 3000:80

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090
```

## 📁 Directory Structure

```
kube-sre-stack/
├── terraform/
│   └── modules/
│       ├── vpc/                    # Multi-AZ VPC (public/private/db subnets)
│       ├── eks/                    # EKS cluster, Karpenter IAM, IRSA, OIDC
│       ├── observability/          # Prometheus + Grafana via Helm
│       ├── ingress/                # Nginx Ingress controller (AWS NLB)
│       ├── external-secrets/       # External Secrets Operator + IRSA
│       └── velero/                 # Backup infrastructure (S3 + IAM)
├── terragrunt/
│   ├── terragrunt.hcl             # Root config (remote state, provider)
│   └── env/
│       ├── dev/                    # Dev: 2 AZ, single NAT, t3.medium
│       └── prod/                   # Prod: 3 AZ, HA NAT, t3.large
├── k8s/
│   ├── argocd/
│   │   ├── applicationsets/        # Auto-discovers environments from Git
│   │   ├── rollouts/               # Canary deployment with Prometheus analysis
│   │   ├── notifications/          # Slack alerts on sync/fail/degrade
│   │   ├── image-updater/          # Auto image tag promotion
│   │   └── sync-waves/             # Dependency-ordered deployment
│   ├── apps/piggymetrics/
│   │   ├── base/                   # 10 microservices + StatefulSets + Ingress
│   │   └── overlays/dev|prod/      # Kustomize: env-specific replicas, resources
│   ├── alerting/rules/             # SLO burn-rate + infra + app + DR + secrets alerts
│   ├── alertmanager/               # Routing, Slack/PagerDuty, inhibition rules
│   ├── observability/
│   │   ├── service-monitors/       # Scrape targets for all services
│   │   ├── pod-monitors/           # MongoDB, RabbitMQ, Ingress metrics
│   │   ├── recording-rules/        # Pre-computed SLIs for fast dashboards
│   │   ├── grafana-dashboards/     # Golden Signals + Infra + SLO (JSON-as-code)
│   │   └── grafana-provisioning/   # Auto-load dashboards via sidecar
│   ├── auto-remediation/
│   │   ├── scripts/                # Crashloop restart, latency scaler, disk cleanup
│   │   ├── cronjobs/               # Scheduled remediation (every 2-5 min)
│   │   └── rbac/                   # Least-privilege service account
│   ├── disaster-recovery/
│   │   ├── backup-schedules.yaml   # Hourly/daily/weekly with PV hooks
│   │   └── scripts/                # DR validation (weekly test)
│   ├── secrets/                    # ClusterSecretStore + ExternalSecrets
│   └── karpenter/                  # NodePool + EC2NodeClass (Spot optimization)
├── tests/load/
│   ├── gateway-load-test.js        # Ramp to 150 VUs, SLO thresholds
│   ├── auth-spike-test.js          # 10x traffic spike simulation
│   ├── soak-test.js                # 30-min stability (memory leak detection)
│   └── Makefile                    # make gateway | auth | soak | test-dev
├── docs/
│   ├── architecture.md             # System architecture
│   ├── observability-architecture.md
│   ├── secrets-management.md
│   ├── auto-remediation.md
│   ├── disaster-recovery.md        # RTO/RPO, restore procedures
│   ├── adr/                        # Architecture Decision Records
│   └── runbooks/                   # Incident response playbooks
└── .github/workflows/              # CI: validate, scan, cost estimate
```

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Cloud** | AWS (EKS, VPC, IAM, S3, Secrets Manager, KMS) | Infrastructure platform |
| **IaC** | Terraform + Terragrunt | Multi-env infra with dependency management |
| **Orchestration** | Kubernetes 1.29 (EKS) | Container orchestration |
| **GitOps** | ArgoCD + Argo Rollouts | Declarative delivery + canary deploys |
| **Autoscaling** | Karpenter v0.35+ | Cost-optimized node provisioning (Spot) |
| **Observability** | Prometheus, Grafana, AlertManager | Metrics, dashboards, alerting |
| **Alerting** | MWMBR SLO burn-rate | Google SRE Workbook pattern |
| **Secrets** | External Secrets Operator + AWS SM | Zero static credentials (IRSA) |
| **Backup/DR** | Velero + S3 cross-region | RTO < 30 min, RPO < 1 hour |
| **Load Testing** | k6 | SLO validation (ramp, spike, soak) |
| **Security** | Network Policies, PDBs, IRSA | Zero-trust, least-privilege |
| **CI** | GitHub Actions | Validate, scan (Checkov/Trivy), cost estimate |
| **Application** | PiggyMetrics (Spring Boot) | 10 microservices reference deployment |

## 🧠 Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| EKS over ECS | EKS | Portability, ecosystem (Karpenter, ArgoCD), operator pattern support |
| Karpenter over Cluster Autoscaler | Karpenter | 2x faster scaling, Spot diversification, consolidation |
| Terragrunt over Terraform workspaces | Terragrunt | Explicit dependency graph, DRY configs, run-all |
| MWMBR over static thresholds | Burn rate | 70% fewer false alerts, direct SLO budget connection |
| External Secrets over SealedSecrets | ESO | No secrets in Git (even encrypted), auto-rotation |
| ArgoCD over FluxCD | ArgoCD | UI, ApplicationSets, Rollouts integration, RBAC |
| k6 over JMeter/Locust | k6 | Developer-friendly JS, CI-native, threshold-based pass/fail |

See [`docs/adr/`](docs/adr/) for detailed Architecture Decision Records.

## 💡 Why I Built This

As the **sole SRE for a platform serving 50,000+ concurrent users**, I needed a system that:

- **Self-heals** — Auto-remediation handles 80% of incidents without paging me at 3 AM
- **Proves reliability** — SLO burn-rate alerting tells me customer impact, not CPU noise
- **Deploys fearlessly** — Canary rollouts with automated Prometheus analysis catch regressions before users
- **Recovers fast** — Validated DR with RTO < 30 min means I sleep well even after disasters
- **Costs less** — Karpenter Spot instances + Kubecost visibility saved ~$60K/year

This repo is the **open-source version of that production platform**. Every Terraform module, every alert rule, every runbook was battle-tested on real traffic before landing here.

It's not a tutorial — it's a **production blueprint** you can fork and deploy.

## 📚 Documentation

| Doc | Description |
|-----|-------------|
| [Architecture](docs/architecture.md) | System design, component interactions |
| [Observability](docs/observability-architecture.md) | Metrics flow, dashboards, recording rules |
| [Secrets Management](docs/secrets-management.md) | ESO + AWS Secrets Manager integration |
| [Disaster Recovery](docs/disaster-recovery.md) | RTO/RPO targets, restore procedures |
| [Auto-Remediation](docs/auto-remediation.md) | Self-healing scripts, escalation logic |
| [ADR-001: EKS over ECS](docs/adr/001-eks-over-ecs.md) | Container orchestration choice |
| [ADR-002: MWMBR Alerting](docs/adr/002-mwmbr-alerting-strategy.md) | Why multi-window burn-rate |
| [Runbooks](docs/runbooks/) | Incident response playbooks |

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- Terraform code passes `terraform fmt` and `terraform validate`
- Kubernetes manifests pass `kubectl --dry-run=client`
- Documentation is updated for any architectural changes

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

**Built with ☕ by [Deepak Jairamani](https://github.com/deepakjairamani1)** — SRE who believes infrastructure should be boring (so product teams can be exciting).
