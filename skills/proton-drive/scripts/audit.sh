#!/usr/bin/env bash
# Proton Drive — Access Audit Logger
#
# Usage: bash scripts/audit.sh <action> [detail]

set -euo pipefail

ACTION="${1:-unknown}"
DETAIL="${2:-}"
ACCOUNT="${PROTON_ACCOUNT:-[PROTON_ACCOUNT not set]}"
TIMESTAMP="$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
LOG_FILE="$HOME/.proton-skill-audit.log"
SERVICE="proton-drive"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

printf '%s\t%s\t%s\t%s\t%s\n' \
    "$TIMESTAMP" "$ACCOUNT" "$SERVICE" "$ACTION" "$DETAIL" >> "$LOG_FILE"

printf '  [audit] proton-drive › %s recorded in ~/.proton-skill-audit.log\n' \
    "$ACTION" >&2
