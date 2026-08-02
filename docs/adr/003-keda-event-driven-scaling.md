# ADR-003: KEDA for Event-Driven Autoscaling over HPA-only

## Status: Accepted

## Date: 2026-08-02

## Context

Standard HPA scales on CPU and memory. For PiggyMetrics, some services are I/O-bound (notification-service processes queue messages) or demand-driven (gateway handles HTTP traffic). CPU-based HPA either:
- Scales too late (latency already degraded)
- Doesn't scale at all (CPU stays low on I/O-bound work)

## Decision

Deploy **KEDA** alongside existing HPA for services where event-driven scaling adds value.

## Scaling Strategy Per Service

| Service | Trigger | Why |
|---------|---------|-----|
| **notification-service** | RabbitMQ queue depth | I/O-bound, CPU stays low with thousands queued |
| **gateway** | HTTP RPS + P95 latency | Demand-driven, scale before latency degrades |
| **account-service** | RPS + error rate + connection pool | Multi-signal detects different failure modes |
| **statistics-service** | HPA (CPU) only | Compute-bound, CPU scales correctly |
| **auth-service** | HPA (CPU) only | Simple request/response, CPU correlates |

## KEDA vs HPA Comparison

| Aspect | HPA | KEDA |
|--------|-----|------|
| Triggers | CPU, memory only | 50+ sources (Prometheus, SQS, RabbitMQ, etc.) |
| Scale to zero | No (min 1) | Yes |
| Custom metrics | Complex (custom metrics adapter) | Built-in (ScaledObject + query) |
| Proactive scaling | No (reactive to current usage) | Yes (scales on leading indicators like RPS) |
| Complexity | Low | Medium |

## Consequences

### Positive
- Notification-service now scales on actual demand (queue depth), not proxy (CPU)
- Gateway scales proactively before latency degrades
- Account-service uses error rate as a scale trigger (self-healing via scaling)
- Scale-to-zero saves ~30% on notification-service costs during off-hours

### Negative
- Additional operator to maintain (KEDA)
- More complex debugging (need to check ScaledObject status, not just HPA)
- Prometheus dependency for scaling (if Prometheus is down, KEDA can't scale)

### Mitigations
- KEDA fallback configured (reverts to minReplicas if trigger source unavailable)
- HPA still present as a safety net for services that also have KEDA
- Prometheus HA deployment (2 replicas) reduces single point of failure
