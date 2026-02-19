#!/usr/bin/env bash
# Proton Pass — Output Guard  [CRITICAL SECURITY COMPONENT]
#
# Redacts ALL credential values from `proton pass` output.
# Passwords, TOTP codes, CVV numbers, and PINs MUST NEVER appear
# in the model's conversation context.
#
# Usage:
#   proton pass list ... | bash scripts/guard.sh
#   proton pass get  ... | bash scripts/guard.sh   ← always pipe through this
#
# If a password is needed: use `proton pass copy` (clipboard, auto-cleared in 30s)
# instead of `proton pass get --field password`.

set -euo pipefail

python3 - <<'PYEOF'
import sys, re, json

# Fields whose values must always be fully redacted
ALWAYS_REDACT = {
    "password", "passwd", "pass",
    "totp", "otp", "otpauth", "secret",
    "cvv", "cvc", "cvc2",
    "pin", "securitycode", "security_code",
    "privatekey", "private_key", "privatekey",
    "encryptedkey", "encrypted_key",
}

REDACT_MSG = "[REDACTED — use 'proton pass copy --item <name>' to copy to clipboard]"

def redact(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            lk = k.lower().replace("-", "").replace("_", "").replace(" ", "")
            if lk in ALWAYS_REDACT:
                out[k] = REDACT_MSG
            else:
                out[k] = redact(v)
        return out
    elif isinstance(obj, list):
        return [redact(i) for i in obj]
    return obj

raw = sys.stdin.read()

try:
    data = json.loads(raw)
    print(json.dumps(redact(data), indent=2, ensure_ascii=False))
except json.JSONDecodeError:
    # Plain-text redaction via regex
    patterns = [
        # key: value  (plain text output)
        (re.compile(
            r'^(\s*(?:password|passwd|totp|otp|cvv|cvc|pin|secret|private[_\s]?key)'
            r'\s*:\s*)(.+)$',
            re.IGNORECASE | re.MULTILINE
        ), r'\1' + REDACT_MSG),
        # "key": "value"  (JSON-like in plain text)
        (re.compile(
            r'("(?:password|passwd|totp|otp|cvv|cvc|pin|secret|private[_\-]?key)"'
            r'\s*:\s*)"[^"]*"',
            re.IGNORECASE
        ), r'\1"' + REDACT_MSG + '"'),
    ]
    result = raw
    for pattern, replacement in patterns:
        result = pattern.sub(replacement, result)
    print(result, end="")
PYEOF
