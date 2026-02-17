---
name: proton-mail
description: Proton Mail CLI for reading, sending, searching, and managing end-to-end encrypted emails. Asks for explicit confirmation before accessing any email content.
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
      "bins": ["proton"],
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

Use this skill when the user asks to check their Proton Mail inbox, read or send emails, search messages, or manage folders and labels. Trigger on phrases like "check my Proton mail", "read my emails", "send a Proton email", or "search my inbox".

## Setup

One-time authentication (run once per account):

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

To persist across sessions, add to your shell profile:

```bash
echo 'export PROTON_ACCOUNT=you@proton.me' >> ~/.zshrc
```

## Ask-Before-Read Behavior

**Default: ALWAYS ask before accessing email content.**

This behavior is enabled by default. Before any read operation, confirm with the user using `scripts/ask.sh`.

### When to ask

| Action | Confirmation prompt |
|--------|-------------------|
| List inbox | "Check your Proton Mail inbox for [N] messages?" |
| Read a message | "Read email from [sender] — '[subject]'?" |
| Search emails | "Search your Proton Mail for '[query]'?" |
| List a folder | "Open your [folder] folder?" |

### Disabling confirmation

If the user says any of the following, skip the confirmation prompt for the rest of the session:
- "stop asking", "don't ask", "just do it", "disable confirmations", "yes to all"

Run the confirm helper:

```bash
bash scripts/ask.sh "Check your inbox? (20 most recent messages)"
# Exit 0 = confirmed, exit 1 = cancelled
```

## Common Operations

### List Inbox

```bash
proton mail list \
  --account "$PROTON_ACCOUNT" \
  --folder inbox \
  --limit 20
```

### List a Specific Folder

```bash
# Folders: inbox, sent, drafts, trash, spam, archive
proton mail list \
  --account "$PROTON_ACCOUNT" \
  --folder sent \
  --limit 10
```

### Read an Email

```bash
proton mail read \
  --account "$PROTON_ACCOUNT" \
  --id <message-id>
```

### Send an Email

```bash
proton mail send \
  --account "$PROTON_ACCOUNT" \
  --to "recipient@example.com" \
  --subject "Subject line" \
  --body "Email body text"
```

To attach a file:

```bash
proton mail send \
  --account "$PROTON_ACCOUNT" \
  --to "recipient@example.com" \
  --subject "Files attached" \
  --body "See attached." \
  --attachment "/path/to/file.pdf"
```

### Reply to an Email

```bash
proton mail reply \
  --account "$PROTON_ACCOUNT" \
  --id <message-id> \
  --body "Reply text"
```

### Search Emails

```bash
proton mail search \
  --account "$PROTON_ACCOUNT" \
  --query "meeting notes"
```

Search with date range:

```bash
proton mail search \
  --account "$PROTON_ACCOUNT" \
  --query "invoice" \
  --from "2025-01-01" \
  --to "2025-12-31"
```

### Archive an Email

```bash
proton mail archive --account "$PROTON_ACCOUNT" --id <message-id>
```

### Delete an Email

```bash
proton mail delete --account "$PROTON_ACCOUNT" --id <message-id>
```

### Move to Folder

```bash
proton mail move \
  --account "$PROTON_ACCOUNT" \
  --id <message-id> \
  --folder archive
```

### List All Folders / Labels

```bash
proton mail folders --account "$PROTON_ACCOUNT"
proton mail labels --account "$PROTON_ACCOUNT"
```

### Mark as Read / Unread

```bash
proton mail mark-read  --account "$PROTON_ACCOUNT" --id <message-id>
proton mail mark-unread --account "$PROTON_ACCOUNT" --id <message-id>
```

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account to use (default: `$PROTON_ACCOUNT`) |
| `--folder FOLDER` | Mailbox folder: `inbox`, `sent`, `drafts`, `trash`, `spam`, `archive` |
| `--limit N` | Max results to return (default: `10`) |
| `--id MSG_ID` | Target a specific message by ID |
| `--query TEXT` | Search query string |
| `--from DATE` | Search start date (`YYYY-MM-DD`) |
| `--to DATE` | Search end date (`YYYY-MM-DD`) |
| `--to EMAIL` | Recipient address (send context) |
| `--subject TEXT` | Email subject |
| `--body TEXT` | Email body (plain text) |
| `--attachment PATH` | Local file to attach |
| `--format json` | Output as JSON for scripting |

## Examples

```bash
# Check for unread messages
proton mail list --account "$PROTON_ACCOUNT" --folder inbox --unread

# Get the 5 most recent emails as JSON
proton mail list --account "$PROTON_ACCOUNT" --limit 5 --format json

# Full-text search
proton mail search --account "$PROTON_ACCOUNT" --query "from:boss@company.com subject:urgent"
```
