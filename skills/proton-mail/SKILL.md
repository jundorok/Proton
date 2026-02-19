---
name: proton-mail
description: Proton Mail CLI for reading, sending, searching, and managing end-to-end encrypted emails. Enforces privacy-first access: always asks before reading, sanitizes all output, and logs every access locally.
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
      "bins": ["proton", "python3"],
      "env": ["PROTON_ACCOUNT"]
    },
    "files": ["scripts/*"],
    "install": [
      {
        "id": "brew",
        "kind": "brew",
        "formula": "proton/tap/proton-cli",
        "bins": ["proton"],
        "label": "Install proton-cli (brew)",
        "os": ["darwin"]
      },
      {
        "id": "npm",
        "kind": "node",
        "package": "@proton/cli",
        "bins": ["proton"],
        "label": "Install via npm"
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

Always run `scripts/ask.sh` before any proton command. If the user says "stop asking" or "don't ask", honour it **only for listing operations**. Never skip confirmation for reading full message content.

### Rule 2 — All Output MUST Pass Through guard.sh

Never display raw `proton mail` output directly. Always pipe through `scripts/guard.sh` first:

```bash
# CORRECT
proton mail read --id <id> | bash scripts/guard.sh

# WRONG — never do this
proton mail read --id <id>
```

`guard.sh` enforces:
- Email body truncated to 200 characters (preview only)
- Auth headers (`Authorization`, `x-pm-*`) fully redacted
- Attachment binary content fully blocked

### Rule 3 — Log Every Access via audit.sh

Run `scripts/audit.sh` before every proton command. Logs are written **locally only** to `~/.proton-skill-audit.log` — never sent anywhere.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, `fetch`, or any network tool inside this skill.
- **NEVER** pipe email content to any service other than `guard.sh` or an explicit user-specified local file.
- **NEVER** write email content to disk unless the user explicitly requests it and provides a path.

### Rule 5 — Credential Hygiene

- **NEVER** pass `PROTON_ACCOUNT` or any token as a visible CLI argument.
- Always reference `$PROTON_ACCOUNT` from the environment.
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

Step 3 → proton mail <subcommand> [flags] | bash scripts/guard.sh
```

### Viewing the Audit Log

```bash
cat ~/.proton-skill-audit.log
# Filter to mail only:
grep "proton-mail" ~/.proton-skill-audit.log
```

---

## Setup

One-time authentication:

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

Add to shell profile to persist:

```bash
echo 'export PROTON_ACCOUNT=you@proton.me' >> ~/.zshrc
```

---

## Common Operations

### Check Inbox

```bash
# Step 1
bash scripts/ask.sh "List your Proton Mail inbox (20 most recent)?"
# Step 2
bash scripts/audit.sh "list-inbox" "--folder inbox --limit 20"
# Step 3
proton mail list \
  --account "$PROTON_ACCOUNT" \
  --folder inbox \
  --limit 20 | bash scripts/guard.sh
```

### Read an Email

```bash
bash scripts/ask.sh "Read email from [sender] — '[subject]'?"
bash scripts/audit.sh "read" "<message-id>"
proton mail read \
  --account "$PROTON_ACCOUNT" \
  --id <message-id> | bash scripts/guard.sh
```

### Send an Email

```bash
bash scripts/ask.sh "Send email to [recipient] with subject '[subject]'?"
bash scripts/audit.sh "send" "to:<recipient>"
proton mail send \
  --account "$PROTON_ACCOUNT" \
  --to "recipient@example.com" \
  --subject "Subject line" \
  --body "Email body text"
```

### Reply to an Email

```bash
bash scripts/ask.sh "Reply to email '[subject]'?"
bash scripts/audit.sh "reply" "<message-id>"
proton mail reply \
  --account "$PROTON_ACCOUNT" \
  --id <message-id> \
  --body "Reply text"
```

### Search Emails

```bash
bash scripts/ask.sh "Search your Proton Mail for '[query]'?"
bash scripts/audit.sh "search" "<query>"
proton mail search \
  --account "$PROTON_ACCOUNT" \
  --query "search terms" | bash scripts/guard.sh
```

### Archive / Delete

```bash
bash scripts/ask.sh "Archive email '[subject]'?"
bash scripts/audit.sh "archive" "<message-id>"
proton mail archive --account "$PROTON_ACCOUNT" --id <message-id>
```

```bash
bash scripts/ask.sh "Permanently delete email '[subject]'?"
bash scripts/audit.sh "delete" "<message-id>"
proton mail delete --account "$PROTON_ACCOUNT" --id <message-id>
```

### List Folders / Labels

```bash
bash scripts/audit.sh "list-folders" ""
proton mail folders --account "$PROTON_ACCOUNT" | bash scripts/guard.sh
```

---

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account (default: `$PROTON_ACCOUNT`) |
| `--folder FOLDER` | `inbox`, `sent`, `drafts`, `trash`, `spam`, `archive` |
| `--limit N` | Max results (default: `10`) |
| `--id MSG_ID` | Target message ID |
| `--query TEXT` | Search query |
| `--from DATE` | Search start date (`YYYY-MM-DD`) |
| `--to DATE` | Search end date (`YYYY-MM-DD`) |
| `--subject TEXT` | Email subject |
| `--body TEXT` | Email body (plain text) |
| `--attachment PATH` | Local file to attach |
| `--format json` | Output as JSON |
