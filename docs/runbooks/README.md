# Runbooks Index

Operational runbooks for incident response and common scenarios.

| Alert | Runbook | Severity |
|-------|---------|----------|
| SLOAvailabilityFastBurn | [slo-fast-burn.md](slo-fast-burn.md) | Critical |
| NodeHighCPU | [node-high-cpu.md](node-high-cpu.md) | Warning/Critical |
| NodeHighMemory | [node-high-memory.md](node-high-memory.md) | Warning/Critical |
| KubePodCrashLooping | [pod-crash-loop.md](pod-crash-loop.md) | Warning |
| HighHTTPErrorRate | [high-error-rate.md](high-error-rate.md) | Warning/Critical |
| TrafficDropSudden | [traffic-drop.md](traffic-drop.md) | Critical |

## Runbook Standards

- Every alert MUST have a linked runbook
- Runbooks follow: Triage → Diagnose → Mitigate → Post-incident
- Keep commands copy-pasteable (no placeholders where possible)
- Update runbook after every incident that reveals a gap
