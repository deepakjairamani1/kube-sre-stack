# ADR-001: EKS over ECS for Container Orchestration

## Status

Accepted

## Date

2024-01-15

## Context

We need a container orchestration platform to run 50+ microservices with the following requirements:

- Multi-team development with namespace isolation
- Fine-grained autoscaling (sub-minute node provisioning)
- Comprehensive observability with Prometheus-native tooling
- GitOps-driven deployments with full audit trail
- Cost optimization through intelligent Spot instance usage
- Portability potential (avoid hard cloud vendor lock-in)
- Rich ecosystem of CNCF tooling (service mesh, policy engines, etc.)

The two primary options on AWS are:

1. **Amazon EKS** — Managed Kubernetes control plane
2. **Amazon ECS** — AWS-native container orchestration

## Decision

We chose **Amazon EKS** as our container orchestration platform.

## Rationale

### In Favor of EKS

| Criterion | EKS | ECS |
|-----------|-----|-----|
| Ecosystem | Vast CNCF ecosystem (Prometheus, ArgoCD, Karpenter, Istio) | Limited to AWS-native integrations |
| Autoscaling | Karpenter: 30-60s provisioning, 20+ instance types | ECS Capacity Providers: slower, less flexible |
| GitOps | ArgoCD/Flux with native K8s reconciliation | Custom solutions needed (CodePipeline/CDK) |
| Observability | Prometheus + Grafana (industry standard) | CloudWatch (vendor-specific, costly at scale) |
| Multi-tenancy | Namespaces + RBAC + Network Policies | Task definitions + IAM (less granular) |
| Portability | Standard Kubernetes APIs | AWS-proprietary task definitions |
| Talent Pool | Kubernetes skills are industry standard | ECS-specific knowledge is rarer |
| Cost Control | Karpenter Spot + bin-packing + Kubecost | Fargate pricing premium or manual capacity |

### In Favor of ECS (considered but outweighed)

- **Simpler initial setup**: ECS with Fargate requires no node management
- **Tighter AWS integration**: Native ALB integration, simpler IAM
- **Lower operational overhead for small teams**: No Kubernetes complexity
- **Fargate**: True serverless containers (no node patching)

### Why we didn't choose ECS

1. **Observability cost**: CloudWatch metrics at our scale ($10K+/month) vs Prometheus (self-hosted, ~$500/month in compute)
2. **Autoscaling speed**: Karpenter provisions nodes in 30-60s; ECS capacity providers take 3-5 minutes
3. **GitOps maturity**: ArgoCD provides declarative, auditable, self-healing deployments out of the box
4. **Ecosystem lock-in**: Choosing ECS means building custom solutions for things the CNCF ecosystem provides free (policy, mesh, cost management)
5. **Team growth**: Kubernetes skills transfer across employers; ECS skills don't

## Consequences

### Positive

- Access to the full CNCF ecosystem without custom integrations
- Karpenter provides industry-leading autoscaling performance
- Team builds portable Kubernetes skills
- Prometheus-native observability at 1/20th the cost of CloudWatch at scale
- ArgoCD provides audit trail for every deployment

### Negative

- Higher initial complexity — Kubernetes has a steeper learning curve
- Node management required (partially mitigated by Karpenter)
- Must manage upgrades for Kubernetes version and add-ons
- Security surface area is larger (more components to secure)

### Mitigations for Negatives

- **Complexity**: Managed by standardized Terraform modules and ArgoCD app-of-apps
- **Node management**: Karpenter handles 95% of node lifecycle automatically
- **Upgrades**: Blue-green node groups make EKS upgrades low-risk
- **Security**: IRSA, Network Policies, and IMDSv2 enforcement reduce attack surface

## Alternatives Considered

1. **ECS + Fargate**: Rejected due to cost ($0.04/vCPU/hr vs ~$0.01 with Spot) and limited ecosystem
2. **Self-managed Kubernetes (kops/kubeadm)**: Rejected due to operational overhead of managing control plane
3. **GKE**: Rejected as the team and infrastructure are AWS-first

## References

- [CNCF Landscape](https://landscape.cncf.io/)
- [Karpenter vs. Cluster Autoscaler](https://karpenter.sh/docs/)
- [Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
