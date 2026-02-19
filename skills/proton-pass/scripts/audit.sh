#!/usr/bin/env bash
# Proton Pass — Access Audit Logger  [MANDATORY — cannot be skipped]
#
# Every credential access MUST be logged, regardless of session state.
# Usage: bash scripts/audit.sh <action> [detail]

set -euo pipefail

ACTION="${1:-unknown}"
DETAIL="${2:-}"
ACCOUNT="${PROTON_ACCOUNT:-[PROTON_ACCOUNT not set]}"
TIMESTAMP="$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOG_FILE="$HOME/.proton-skill-audit.log"
SERVICE="proton-pass"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

printf '%s\t%s\t%s\t%s\t%s\n' \
    "$TIMESTAMP" "$ACCOUNT" "$SERVICE" "$ACTION" "$DETAIL" >> "$LOG_FILE"

# Always notify for credential access — intentionally more visible
printf '\n  [audit] 🔑 proton-pass › %s — logged to ~/.proton-skill-audit.log\n\n' \
    "$ACTION" >&2
