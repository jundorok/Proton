#!/usr/bin/env bash
# Proton Calendar — Access Audit Logger
#
# Appends a structured, local-only audit entry to ~/.proton-skill-audit.log
# NEVER sends data to any external service.
#
# Usage:
#   bash scripts/audit.sh <action> [detail]
#
# Examples:
#   bash scripts/audit.sh "list-events" "--from 2026-02-01 --to 2026-02-28"
#   bash scripts/audit.sh "create"      "Team standup"
#   bash scripts/audit.sh "delete"      "<event-id>"

set -euo pipefail

ACTION="${1:-unknown}"
DETAIL="${2:-}"
ACCOUNT="${PROTON_ACCOUNT:-[PROTON_ACCOUNT not set]}"
TIMESTAMP="$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOG_FILE="$HOME/.proton-skill-audit.log"
SERVICE="proton-calendar"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

printf '%s\t%s\t%s\t%s\t%s\n' \
    "$TIMESTAMP" "$ACCOUNT" "$SERVICE" "$ACTION" "$DETAIL" >> "$LOG_FILE"

printf '  [audit] proton-calendar › %s recorded in ~/.proton-skill-audit.log\n' \
    "$ACTION" >&2
