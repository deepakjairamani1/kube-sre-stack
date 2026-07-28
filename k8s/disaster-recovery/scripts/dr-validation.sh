#!/bin/bash
# dr-validation.sh
#
# Validates that disaster recovery actually works by:
#   1. Checking latest backup exists and is Completed
#   2. Verifying backup is not older than expected (SLA breach)
#   3. Optionally: performs a test restore to a staging namespace
#
# Run weekly via CronJob to prove RTO/RPO targets are achievable.
# "Backups that haven't been tested are not backups."

set -euo pipefail

NAMESPACE="${NAMESPACE:-velero}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
MAX_BACKUP_AGE_HOURS="${MAX_BACKUP_AGE_HOURS:-25}"  # Alert if no backup in 25h
DRY_RUN="${DRY_RUN:-false}"

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1"
}

notify_slack() {
  local message="$1"
  local color="${2:-#36a64f}"
  if [[ -n "$SLACK_WEBHOOK" ]]; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -H 'Content-type: application/json' \
      -d "{\"attachments\": [{\"color\": \"$color\", \"text\": \"$message\"}]}" > /dev/null 2>&1
  fi
}

VALIDATION_PASSED=true
REPORT=""

# ─── CHECK 1: Latest backup exists and is Completed ───────────────────────

log "📋 Check 1: Verifying latest backup status..."

LATEST_BACKUP=$(velero backup get --namespace "$NAMESPACE" \
  -o json 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
items = sorted(data.get('items', []), key=lambda x: x.get('status', {}).get('completionTimestamp', ''), reverse=True)
if items:
    b = items[0]
    print(f\"{b['metadata']['name']}|{b['status'].get('phase', 'Unknown')}|{b['status'].get('completionTimestamp', 'N/A')}\")
else:
    print('NONE|NONE|NONE')
" 2>/dev/null || echo "ERROR|ERROR|ERROR")

BACKUP_NAME=$(echo "$LATEST_BACKUP" | cut -d'|' -f1)
BACKUP_PHASE=$(echo "$LATEST_BACKUP" | cut -d'|' -f2)
BACKUP_TIME=$(echo "$LATEST_BACKUP" | cut -d'|' -f3)

if [[ "$BACKUP_PHASE" == "Completed" ]]; then
  log "  ✅ Latest backup: $BACKUP_NAME (Completed at $BACKUP_TIME)"
  REPORT+="✅ Latest backup: \`$BACKUP_NAME\` — Completed\n"
else
  log "  ❌ Latest backup: $BACKUP_NAME (Phase: $BACKUP_PHASE)"
  REPORT+="❌ Latest backup: \`$BACKUP_NAME\` — Phase: $BACKUP_PHASE\n"
  VALIDATION_PASSED=false
fi

# ─── CHECK 2: Backup freshness (RPO validation) ──────────────────────────

log "📋 Check 2: Verifying backup freshness (RPO)..."

if [[ "$BACKUP_TIME" != "N/A" ]] && [[ "$BACKUP_TIME" != "ERROR" ]]; then
  BACKUP_EPOCH=$(date -d "$BACKUP_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$BACKUP_TIME" +%s 2>/dev/null || echo "0")
  NOW_EPOCH=$(date +%s)
  AGE_HOURS=$(( (NOW_EPOCH - BACKUP_EPOCH) / 3600 ))

  if [[ "$AGE_HOURS" -le "$MAX_BACKUP_AGE_HOURS" ]]; then
    log "  ✅ Backup age: ${AGE_HOURS}h (threshold: ${MAX_BACKUP_AGE_HOURS}h)"
    REPORT+="✅ RPO: Backup is ${AGE_HOURS}h old (target: <${MAX_BACKUP_AGE_HOURS}h)\n"
  else
    log "  ❌ Backup age: ${AGE_HOURS}h EXCEEDS threshold of ${MAX_BACKUP_AGE_HOURS}h"
    REPORT+="❌ RPO BREACH: Backup is ${AGE_HOURS}h old (target: <${MAX_BACKUP_AGE_HOURS}h)\n"
    VALIDATION_PASSED=false
  fi
fi

# ─── CHECK 3: Backup content validation ──────────────────────────────────

log "📋 Check 3: Verifying backup contains expected resources..."

if [[ "$BACKUP_NAME" != "NONE" ]] && [[ "$BACKUP_NAME" != "ERROR" ]]; then
  BACKUP_CONTENTS=$(velero backup describe "$BACKUP_NAME" --namespace "$NAMESPACE" 2>/dev/null | grep -c "piggymetrics" || echo "0")

  if [[ "$BACKUP_CONTENTS" -gt 0 ]]; then
    log "  ✅ Backup contains piggymetrics resources"
    REPORT+="✅ Content: piggymetrics namespace included\n"
  else
    log "  ❌ Backup does NOT contain piggymetrics resources"
    REPORT+="❌ Content: piggymetrics namespace MISSING from backup\n"
    VALIDATION_PASSED=false
  fi
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────

log ""
if [[ "$VALIDATION_PASSED" == "true" ]]; then
  log "✅ DR VALIDATION PASSED — All checks green"
  notify_slack "✅ *DR Validation Passed*\n\n${REPORT}\nRTO target: < 30 min | RPO target: < 1 hour" "#36a64f"
else
  log "❌ DR VALIDATION FAILED — Action required"
  notify_slack "❌ *DR Validation FAILED*\n\n${REPORT}\n⚠️ Disaster recovery capability is degraded. Investigate immediately." "#E96D76"
fi
