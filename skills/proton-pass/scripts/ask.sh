#!/usr/bin/env bash
# Proton Pass — Ask-Before-Read confirmation prompt
# Usage: bash scripts/ask.sh "Description of action"
# Exit code: 0 = confirmed, 1 = cancelled
#
# NOTE: For Proton Pass, this confirmation is MANDATORY for credential
# retrieval and cannot be disabled by the user for security reasons.

set -euo pipefail

MESSAGE="${1:-Proceed with this Proton Pass action?}"

printf '\n🔒 Proton Pass — Security Confirmation Required\n'
printf '   %s\n\n' "$MESSAGE"
printf '   This will access encrypted credential data.\n\n'
read -r -p "Proceed? [y/N] " REPLY

case "$REPLY" in
  [yY]|[yY][eE][sS])
    printf 'Access granted.\n\n'
    exit 0
    ;;
  *)
    printf 'Cancelled. No credentials were accessed.\n'
    exit 1
    ;;
esac
