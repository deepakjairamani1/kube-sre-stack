# 🚀 Kube-SRE-Stack

> **Production-ready Kubernetes platform with built-in SRE practices**

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazonaws)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io/cd/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?logo=grafana)](https://grafana.com/)
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
| **Infrastructure** | EKS + Karpenter | Auto-scaling Kubernetes with intelligent node provisioning |
| **GitOps** | ArgoCD | Declarative, Git-driven continuous delivery |
| **Observability** | Prometheus + Grafana | Full-stack metrics, alerting, and visualization |
| **SLO Management** | Custom Dashboards | Track error budgets, availability, and latency SLOs |
| **Cost Optimization** | Kubecost + Spot | Real-time cost visibility with aggressive Spot usage |
| **Incident Response** | AlertManager + Runbooks | Automated escalation with self-healing capabilities |
| **Security** | IAM Roles for SA | Pod-level least-privilege access via IRSA |
| **Networking** | Multi-AZ VPC | Production-grade network isolation and redundancy |

## 🏁 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- kubectl
- Helm 3.x

### Deploy Infrastructure

```bash
# Clone the repository
git clone https://github.com/deepakjairamani1/kube-sre-stack.git
cd kube-sre-stack

# Initialize and deploy dev environment
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
aws eks update-kubeconfig --name kube-sre-dev --region us-west-2
```

### Deploy Platform Components

```bash
# Install ArgoCD
kubectl apply -f k8s/argocd/install.yaml

# ArgoCD will reconcile the remaining components from Git
kubectl apply -f k8s/argocd/application.yaml

# Verify
kubectl get applications -n argocd
```

### Access Dashboards

```bash
# Grafana (default: admin/prom-operator)
kubectl port-forward svc/grafana -n observability 3000:80

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Prometheus
kubectl port-forward svc/prometheus-server -n observability 9090:80
```

## 📁 Directory Structure

```
kube-sre-stack/
├── terraform/
│   ├── environments/
│   │   ├── dev/              # Dev environment (smaller instances, single NAT)
│   │   └── prod/             # Prod environment (HA, multi-NAT, larger nodes)
│   └── modules/
│       ├── vpc/              # Multi-AZ VPC with public/private/db subnets
│       ├── eks/              # EKS cluster, managed node groups, IRSA
│       └── observability/    # Helm-based observability stack deployment
├── k8s/
│   ├── argocd/               # ArgoCD installation and app definitions
│   ├── observability/        # Prometheus values, Grafana dashboards
│   └── karpenter/            # Node provisioning and scaling policies
├── docs/
│   ├── architecture.md       # Detailed architecture documentation
│   └── adr/                  # Architecture Decision Records
├── .gitignore
├── LICENSE
└── README.md
```

## 🛠️ Tech Stack

- **Cloud**: AWS (EKS, VPC, IAM, EC2, S3, DynamoDB)
- **IaC**: Terraform ~> 1.5 with remote state (S3 + DynamoDB locking)
- **Container Orchestration**: Kubernetes 1.29 on EKS
- **GitOps**: ArgoCD 2.x
- **Autoscaling**: Karpenter v0.35+ (replaces Cluster Autoscaler)
- **Observability**: Prometheus, Grafana, AlertManager, Loki
- **SLO Management**: Custom dashboards + Pyrra
- **Cost Management**: Kubecost
- **Networking**: AWS VPC CNI, Calico Network Policies
- **Secrets**: External Secrets Operator + AWS Secrets Manager
- **Ingress**: AWS Load Balancer Controller

## 💡 Why I Built This

This project mirrors a **real production platform I designed and operated**, serving **50,000+ active users** across multiple microservices. It demonstrates:

- **End-to-end platform thinking** — from Terraform modules to Grafana dashboards
- **Cost-conscious engineering** — Karpenter Spot instances reduced compute costs by 65%
- **SRE discipline** — SLO-based alerting that pages on customer impact, not noise
- **GitOps maturity** — every change goes through Git, every deployment is auditable
- **Operational readiness** — runbooks, incident response, and self-healing built in

The architecture decisions (see `docs/adr/`) reflect real tradeoffs I navigated: EKS over ECS for portability, Karpenter over Cluster Autoscaler for speed, ArgoCD over Flux for UI and multi-tenancy.

This isn't a demo — it's a **production blueprint** you can fork, customize, and deploy.

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

**Built with ☕ by [Deepak Jairamani](https://github.com/deepakjairamani)**
