#!/usr/bin/env bash
# Proton Drive — Output Guard
#
# Sanitizes `proton drive` output before it reaches the model context.
# - Strips file content fields entirely (only metadata is safe to surface)
# - Redacts share tokens / signed URLs
# - Caps overly long path strings
#
# Usage:
#   proton drive ls  ... | bash scripts/guard.sh
#   proton drive get ... | bash scripts/guard.sh

set -euo pipefail

python3 - <<'PYEOF'
import sys, re, json

BLOCKED_CONTENT_KEYS = {
    "content", "data", "body", "raw", "base64",
    "filedata", "file_data", "bytes", "stream"
}
REDACT_TOKEN_KEYS = {
    "token", "sharetoken", "share_token", "signedurl", "signed_url",
    "downloadurl", "download_url", "authorization", "secret"
}

def redact(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            lk = k.lower().replace("-", "").replace("_", "")
            if lk in BLOCKED_CONTENT_KEYS:
                out[k] = "[FILE CONTENT BLOCKED — use 'proton drive get --output <path>' to download locally]"
            elif lk in REDACT_TOKEN_KEYS or k.lower().startswith("x-pm-"):
                out[k] = "[REDACTED]"
            else:
                out[k] = redact(v)
        return out
    elif isinstance(obj, list):
        return [redact(i) for i in obj]
    elif isinstance(obj, str) and len(obj) > 500:
        # Cap suspiciously long strings (could be base64-encoded content)
        return obj[:100] + f"... [TRUNCATED — {len(obj) - 100} chars. Possible encoded content blocked.]"
    return obj

raw = sys.stdin.read()

try:
    data = json.loads(raw)
    print(json.dumps(redact(data), indent=2, ensure_ascii=False))
except json.JSONDecodeError:
    # Plain text: block any base64-looking blobs (long alphanum strings)
    b64_re = re.compile(r'[A-Za-z0-9+/=]{200,}')
    for line in raw.splitlines():
        line = b64_re.sub('[POSSIBLE ENCODED CONTENT BLOCKED]', line)
        print(line)
PYEOF
