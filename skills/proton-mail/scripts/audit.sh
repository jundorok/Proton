#!/usr/bin/env bash
# Proton Mail — Access Audit Logger
#
# Appends a structured, local-only audit entry to ~/.proton-skill-audit.log
# NEVER sends data to any external service.
#
# Usage:
#   bash scripts/audit.sh <action> [detail]
#
# Examples:
#   bash scripts/audit.sh "list-inbox" "--limit 20"
#   bash scripts/audit.sh "read"       "<message-id>"
#   bash scripts/audit.sh "send"       "to:alice@example.com"

set -euo pipefail

ACTION="${1:-unknown}"
DETAIL="${2:-}"
ACCOUNT="${PROTON_ACCOUNT:-[PROTON_ACCOUNT not set]}"
TIMESTAMP="$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOG_FILE="$HOME/.proton-skill-audit.log"
SERVICE="proton-mail"

# Ensure log file exists (create parent dirs if needed)
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Write tab-separated audit entry
# Format: timestamp  account  service  action  detail
printf '%s\t%s\t%s\t%s\t%s\n' \
    "$TIMESTAMP" "$ACCOUNT" "$SERVICE" "$ACTION" "$DETAIL" >> "$LOG_FILE"

# Notify on stderr (does not pollute command output)
printf '  [audit] proton-mail › %s recorded in ~/.proton-skill-audit.log\n' \
    "$ACTION" >&2
