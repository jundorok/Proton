#!/usr/bin/env bash
# Proton Mail — Output Guard
#
# Sanitizes `proton mail` output before it reaches the model context.
# Prevents full email bodies and auth headers from leaking into the conversation.
#
# Usage:
#   proton mail read --id <id> | bash scripts/guard.sh
#   proton mail list ...       | bash scripts/guard.sh
#
# Exit code mirrors the pipeline's exit code.

set -euo pipefail

# ── Sensitive header redaction ────────────────────────────────────────────────
# Strip Authorization and Proton internal headers from JSON output.
# Pattern: "Authorization": "Bearer ..." or "x-pm-*": "..."
REDACT_HEADERS='s/("(?:Authorization|x-pm-[^"]+)"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"[REDACTED]"/gi'

# ── Email body truncation ─────────────────────────────────────────────────────
# JSON:       "body": "very long text ..."  → truncated at 200 chars
# Plain text: Body section after blank line → first 200 chars shown
BODY_LIMIT=200

# ── Attachment content block ──────────────────────────────────────────────────
# Never expose attachment binary/base64 content — show filename + size only.
REDACT_ATTACHMENT_DATA='s/("(?:content|data|base64)"[[:space:]]*:[[:space:]]*)"[^"]{20,}"/\1"[ATTACHMENT CONTENT BLOCKED — download explicitly to view]"/gi'

# ── Process stdin through all filters ─────────────────────────────────────────
python3 - <<'PYEOF'
import sys, re, json

MAX_BODY = 200
raw = sys.stdin.read()

# Try to parse as JSON and redact inline
try:
    data = json.loads(raw)

    def redact(obj):
        if isinstance(obj, dict):
            out = {}
            for k, v in obj.items():
                lk = k.lower()
                # Redact auth headers
                if lk in ("authorization",) or lk.startswith("x-pm-"):
                    out[k] = "[REDACTED]"
                # Truncate body field
                elif lk in ("body", "html", "text"):
                    if isinstance(v, str) and len(v) > MAX_BODY:
                        out[k] = v[:MAX_BODY] + f"... [TRUNCATED — {len(v) - MAX_BODY} chars hidden. Ask to expand.]"
                    else:
                        out[k] = v
                # Block raw attachment data
                elif lk in ("content", "data", "base64", "raw"):
                    if isinstance(v, str) and len(v) > 50:
                        out[k] = "[ATTACHMENT CONTENT BLOCKED — use 'proton mail save-attachment' to download]"
                    else:
                        out[k] = v
                else:
                    out[k] = redact(v)
            return out
        elif isinstance(obj, list):
            return [redact(i) for i in obj]
        return obj

    print(json.dumps(redact(data), indent=2, ensure_ascii=False))

except json.JSONDecodeError:
    # Plain-text output: truncate body section after the first blank line
    lines = raw.splitlines()
    in_body = False
    body_chars = 0
    truncated = False
    out = []
    for line in lines:
        if not in_body:
            # Detect transition to body (blank line after headers)
            if line.strip() == "" and any(l.lower().startswith("subject:") for l in out):
                in_body = True
            out.append(line)
        else:
            if body_chars >= MAX_BODY:
                if not truncated:
                    remaining = sum(len(l) for l in lines[len(out):])
                    out.append(f"... [TRUNCATED — {remaining} chars hidden. Ask to expand.]")
                    truncated = True
            else:
                out.append(line)
                body_chars += len(line)
    print("\n".join(out))
PYEOF
