#!/usr/bin/env bash
# Proton Drive — Ask-Before-Read confirmation prompt
# Usage: bash scripts/ask.sh "Description of action"
# Exit code: 0 = confirmed, 1 = cancelled

set -euo pipefail

MESSAGE="${1:-Proceed with this Proton Drive action?}"

printf '\n🔒 Proton Drive — Access Confirmation\n'
printf '   %s\n\n' "$MESSAGE"
read -r -p "Proceed? [y/N] " REPLY

case "$REPLY" in
  [yY]|[yY][eE][sS])
    printf 'Access granted.\n\n'
    exit 0
    ;;
  *)
    printf 'Cancelled. No data was accessed.\n'
    exit 1
    ;;
esac
