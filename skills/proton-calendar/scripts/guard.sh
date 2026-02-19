#!/usr/bin/env bash
# Proton Calendar — Output Guard
#
# Sanitizes `proton calendar` output before it reaches the model context.
# - Masks attendee email addresses (show only first char + domain length hint)
# - Truncates long event descriptions
# - Removes any embedded auth tokens
#
# Usage:
#   proton calendar list ... | bash scripts/guard.sh
#   proton calendar show ... | bash scripts/guard.sh

set -euo pipefail

MAX_DESC=150

python3 - <<'PYEOF'
import sys, re, json

MAX_DESC = 150

def mask_email(email):
    """alice@example.com → a***@example.com"""
    if "@" not in email:
        return email
    local, domain = email.split("@", 1)
    return local[0] + "***@" + domain

def redact(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            lk = k.lower()
            # Mask attendee email addresses
            if lk in ("email", "attendee", "attendees", "organizer"):
                if isinstance(v, str):
                    out[k] = mask_email(v)
                elif isinstance(v, list):
                    out[k] = [mask_email(e) if isinstance(e, str) else redact(e) for e in v]
                else:
                    out[k] = redact(v)
            # Truncate descriptions/notes
            elif lk in ("description", "notes", "comment", "body"):
                if isinstance(v, str) and len(v) > MAX_DESC:
                    out[k] = v[:MAX_DESC] + f"... [TRUNCATED — ask to expand]"
                else:
                    out[k] = v
            # Redact auth tokens
            elif lk in ("authorization", "token", "secret") or lk.startswith("x-pm-"):
                out[k] = "[REDACTED]"
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
    # Plain-text: mask email patterns and truncate long lines
    email_re = re.compile(r'\b([A-Za-z0-9._%+\-]+)@([A-Za-z0-9.\-]+\.[A-Za-z]{2,})\b')
    for line in raw.splitlines():
        line = email_re.sub(lambda m: mask_email(m.group(0)), line)
        if len(line) > 300:
            line = line[:300] + "... [TRUNCATED]"
        print(line)
PYEOF
