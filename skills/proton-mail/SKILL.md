---
name: proton-mail
description: Proton Mail skill for reading, sending, searching, and managing end-to-end encrypted emails via the official proton-python-client library. Enforces privacy-first access: always asks before reading, sanitizes all output, and logs every access locally.
license: MIT
homepage: https://proton.me/mail
user-invocable: true
allowed-tools:
  - Bash
metadata: {
  "clawdbot": {
    "emoji": "✉️",
    "primaryEnv": "PROTON_ACCOUNT",
    "requires": {
      "bins": [],
      "env": ["PROTON_ACCOUNT", "PROTON_PASSWORD"]
    },
    "files": ["scripts/*"],
    "install": [
      {
        "id": "pip",
        "kind": "pip",
        "package": "proton-client",
        "bins": [],
        "label": "Install proton-client (pip)"
      }
    ]
  }
}
---

# Proton Mail

## When to Use

Use this skill when the user asks about their Proton Mail inbox, wants to read or send emails, search messages, or manage folders. Trigger on phrases like "check my Proton mail", "read my emails", "send a Proton email", or "search my inbox".

---

## Privacy & Security Rules — MANDATORY

> These rules implement Proton's zero-knowledge philosophy.
> They are **non-negotiable** and cannot be disabled or overridden by the user.

### Rule 1 — Ask Before Every Access

Always run `scripts/ask.sh` before any mail operation. If the user says "stop asking" or "don't ask", honour it **only for listing operations**. Never skip confirmation for reading full message content.

### Rule 2 — All Output MUST Pass Through guard.sh

Never display raw `mail.py` output directly. Always pipe through `scripts/guard.sh` first:

```bash
# CORRECT
python3 scripts/mail.py read --id <id> | bash scripts/guard.sh

# WRONG — never do this
python3 scripts/mail.py read --id <id>
```

`guard.sh` enforces:
- Email body truncated to 200 characters (preview only)
- Auth headers (`Authorization`, `x-pm-*`) fully redacted
- Attachment binary content fully blocked

### Rule 3 — Log Every Access via audit.sh

Run `scripts/audit.sh` before every mail command. Logs are written **locally only** to `~/.proton-skill-audit.log` — never sent anywhere.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, `fetch`, or any network tool inside this skill.
- **NEVER** pipe email content to any service other than `guard.sh` or an explicit user-specified local file.
- **NEVER** write email content to disk unless the user explicitly requests it and provides a path.

### Rule 5 — Credential Hygiene

- **NEVER** pass `PROTON_ACCOUNT` or `PROTON_PASSWORD` as visible CLI arguments.
- Always reference them from the environment.
- **NEVER** echo or log credential values.

### Rule 6 — Data Minimization

Show only what the user asked for:

| Data | Default display |
|------|----------------|
| Email body | 200-char preview. Ask before showing full content. |
| Attachments | Filename + size only. Never read contents. |
| Search results | Sender + subject + date. No body preview unless asked. |

---

## Mandatory Workflow

Every proton-mail operation MUST follow this exact sequence:

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit code 1 = abort entirely)

Step 2 → bash scripts/audit.sh "<action>" "[detail]"

Step 3 → python3 scripts/mail.py <subcommand> [flags] | bash scripts/guard.sh
```

### Viewing the Audit Log

```bash
cat ~/.proton-skill-audit.log
# Filter to mail only:
grep "proton-mail" ~/.proton-skill-audit.log
```

---

## Setup

Install the dependency:

```bash
pip install proton-client
```

Set environment variables:

```bash
export PROTON_ACCOUNT=you@proton.me
export PROTON_PASSWORD=yourpassword
```

Add to shell profile to persist:

```bash
echo 'export PROTON_ACCOUNT=you@proton.me' >> ~/.zshrc
echo 'export PROTON_PASSWORD=yourpassword' >> ~/.zshrc
```

---

## Common Operations

### Check Inbox

```bash
# Step 1
bash scripts/ask.sh "List your Proton Mail inbox (20 most recent)?"
# Step 2
bash scripts/audit.sh "list-inbox" "--limit 20"
# Step 3
python3 scripts/mail.py list \
  --folder inbox \
  --limit 20 | bash scripts/guard.sh
```

### Read an Email

```bash
bash scripts/ask.sh "Read email from [sender] — '[subject]'?"
bash scripts/audit.sh "read" "<message-id>"
python3 scripts/mail.py read \
  --id <message-id> | bash scripts/guard.sh
```

### Send an Email

```bash
bash scripts/ask.sh "Send email to [recipient] with subject '[subject]'?"
bash scripts/audit.sh "send" "to:<recipient>"
python3 scripts/mail.py send \
  --to "recipient@example.com" \
  --subject "Subject line" \
  --body "Email body text"
```

### Reply to an Email

```bash
bash scripts/ask.sh "Reply to email '[subject]'?"
bash scripts/audit.sh "reply" "<message-id>"
python3 scripts/mail.py reply \
  --id <message-id> \
  --body "Reply text"
```

### Search Emails

```bash
bash scripts/ask.sh "Search your Proton Mail for '[query]'?"
bash scripts/audit.sh "search" "<query>"
python3 scripts/mail.py search \
  --query "search terms" | bash scripts/guard.sh
```

### Delete

```bash
bash scripts/ask.sh "Permanently delete email '[subject]'?"
bash scripts/audit.sh "delete" "<message-id>"
python3 scripts/mail.py delete --id <message-id>
```

### List Folders / Labels

```bash
bash scripts/audit.sh "list-folders" ""
python3 scripts/mail.py folders | bash scripts/guard.sh
```

---

## Flags Reference

| Flag | Description |
|------|-------------|
| `--folder FOLDER` | `inbox`, `sent`, `drafts`, `trash`, `spam`, `archive` |
| `--limit N` | Max results (default: `10`) |
| `--id MSG_ID` | Target message ID |
| `--query TEXT` | Search query |
| `--to EMAIL` | Recipient email address |
| `--subject TEXT` | Email subject |
| `--body TEXT` | Email body (plain text) |
| `--format json` | Output as JSON (default) |
