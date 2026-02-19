#!/usr/bin/env bash
# Proton Calendar — Output Guard
#
# Sanitizes calendar output before it reaches the model context.
# Masks attendee emails, truncates descriptions, and hides private events.
#
# Usage:
#   python3 scripts/calendar.py list | bash scripts/guard.sh

set -euo pipefail

python3 - <<'PYEOF'
import sys, re, json

MAX_DESC = 150

raw = sys.stdin.read()

def mask_email(email):
    """alice@example.com → a***@example.com"""
    if "@" not in email:
        return email
    local, domain = email.split("@", 1)
    return local[0] + "***@" + domain

def redact(obj):
    if isinstance(obj, dict):
        # Hide private events entirely
        if obj.get("visibility", "").upper() == "PRIVATE" or obj.get("private") is True:
            return {
                "id": obj.get("id"),
                "title": "[PRIVATE EVENT]",
                "date": obj.get("date"),
                "time": obj.get("time"),
                "visibility": "PRIVATE",
            }
        out = {}
        for k, v in obj.items():
            lk = k.lower()
            # Mask attendee email fields
            if lk in ("email", "organizer_email") and isinstance(v, str):
                out[k] = mask_email(v)
            # Truncate description/notes
            elif lk in ("description", "notes", "body") and isinstance(v, str):
                if len(v) > MAX_DESC:
                    out[k] = v[:MAX_DESC] + f"... [TRUNCATED — {len(v) - MAX_DESC} chars hidden]"
                else:
                    out[k] = v
            # Recurse into attendees list
            elif lk == "attendees" and isinstance(v, list):
                out[k] = [redact(a) for a in v]
            else:
                out[k] = redact(v)
        return out
    elif isinstance(obj, list):
        return [redact(i) for i in obj]
    return obj

try:
    data = json.loads(raw)
    print(json.dumps(redact(data), indent=2, ensure_ascii=False))
except json.JSONDecodeError:
    # Plain text fallback — mask any email-like strings
    masked = re.sub(
        r'\b([a-zA-Z0-9._%+-])[a-zA-Z0-9._%+-]*(@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b',
        r'\1***\2',
        raw
    )
    print(masked)
PYEOF
