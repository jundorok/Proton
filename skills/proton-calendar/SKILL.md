---
name: proton-calendar
description: Proton Calendar skill for viewing and managing encrypted calendar events via Playwright web automation. Supports listing, creating, updating, and deleting events through calendar.proton.me. Enforces privacy-first access with confirmation prompts, attendee email masking, and local audit logging.
license: MIT
homepage: https://proton.me/calendar
user-invocable: true
allowed-tools:
  - Bash
metadata: {
  "clawdbot": {
    "emoji": "📅",
    "primaryEnv": "PROTON_ACCOUNT",
    "requires": {
      "bins": [],
      "env": ["PROTON_ACCOUNT", "PROTON_PASSWORD"]
    },
    "files": ["scripts/*"],
    "install": [
      {
        "id": "playwright",
        "kind": "pip",
        "package": "playwright",
        "bins": ["playwright"],
        "label": "Install Playwright (pip)"
      },
      {
        "id": "chromium",
        "kind": "script",
        "script": "playwright install chromium",
        "bins": [],
        "label": "Install Chromium browser"
      }
    ]
  }
}
---

# Proton Calendar

## When to Use

Use this skill when the user asks to view, create, update, or delete calendar events in Proton Calendar. Trigger on phrases like "check my calendar", "what's on my schedule", "add an event", "create a meeting", "reschedule", or "delete this event".

---

## How It Works

This skill uses **Playwright** (headless Chromium) to automate `calendar.proton.me` directly in the browser — the same way a human would use it. This enables full read and write access without any unofficial API hacking.

- **Reads** events by intercepting the calendar's network responses
- **Writes** (create/update/delete) by filling forms and clicking buttons
- **Session caching** at `~/.proton-calendar-session.json` avoids repeated logins

---

## Privacy & Security Rules — MANDATORY

> These rules implement Proton's zero-knowledge philosophy.
> They are **non-negotiable** and cannot be disabled or overridden by the user.

### Rule 1 — Ask Before Every Access

Always run `scripts/ask.sh` before any calendar operation. If the user says "stop asking" or "don't ask", honour it **only for listing operations**. Never skip confirmation for write operations (create/update/delete).

### Rule 2 — All Output MUST Pass Through guard.sh

Never display raw `calendar.py` output directly. Always pipe through `scripts/guard.sh` first:

```bash
# CORRECT
python3 scripts/calendar.py list | bash scripts/guard.sh

# WRONG — never do this
python3 scripts/calendar.py list
```

`guard.sh` enforces:
- Attendee emails masked to `a***@domain.com`
- Descriptions truncated to 150 characters
- PRIVATE events shown as `[PRIVATE EVENT]` with no details

### Rule 3 — Log Every Access via audit.sh

Run `scripts/audit.sh` before every calendar command. Logs are written **locally only** to `~/.proton-skill-audit.log` — never sent anywhere.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, or any additional network tool inside this skill.
- **NEVER** write calendar content to disk unless the user explicitly requests it.
- The Playwright browser session only communicates with `*.proton.me` domains.

### Rule 5 — Credential Hygiene

- **NEVER** pass `PROTON_ACCOUNT` or `PROTON_PASSWORD` as visible CLI arguments.
- Always reference them from the environment.
- **NEVER** echo or log credential values.

---

## Mandatory Workflow

Every calendar operation MUST follow this exact sequence:

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit code 1 = abort entirely)

Step 2 → bash scripts/audit.sh "<action>" "[detail]"

Step 3 → python3 scripts/calendar.py <subcommand> [flags] | bash scripts/guard.sh
```

> **Note:** For `create`, `update`, and `delete`, confirmation in Step 1 is **always required** and cannot be skipped.

### Viewing the Audit Log

```bash
grep "proton-calendar" ~/.proton-skill-audit.log
```

---

## Setup

Install Playwright and Chromium:

```bash
pip install playwright
playwright install chromium
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

> **First run:** Playwright will log in and cache the session at `~/.proton-calendar-session.json`. Subsequent runs reuse the session automatically.

> **2FA:** If your account uses two-factor authentication, the first login may time out. Disable 2FA temporarily for automated access, or pre-seed a valid session file manually.

---

## Common Operations

### List Events (this week)

```bash
bash scripts/ask.sh "List your Proton Calendar events?"
bash scripts/audit.sh "list-events" ""
python3 scripts/calendar.py list | bash scripts/guard.sh
```

### List Events (date range)

```bash
bash scripts/ask.sh "List your calendar events from 2026-02-01 to 2026-02-28?"
bash scripts/audit.sh "list-events" "--from 2026-02-01 --to 2026-02-28"
python3 scripts/calendar.py list \
  --from 2026-02-01 \
  --to 2026-02-28 | bash scripts/guard.sh
```

### Get a Single Event

```bash
bash scripts/ask.sh "Get details for event '[title]'?"
bash scripts/audit.sh "get-event" "<event-id>"
python3 scripts/calendar.py get \
  --id <event-id> | bash scripts/guard.sh
```

### Create an Event

```bash
bash scripts/ask.sh "Create calendar event '[title]' on [date]?"
bash scripts/audit.sh "create" "<title>"
python3 scripts/calendar.py create \
  --title "Team Standup" \
  --date 2026-02-20 \
  --time 09:00 \
  --duration 30 \
  --description "Daily sync" \
  --location "Zoom" | bash scripts/guard.sh
```

### Create an All-Day Event

```bash
bash scripts/ask.sh "Create all-day event '[title]' on [date]?"
bash scripts/audit.sh "create" "<title>"
python3 scripts/calendar.py create \
  --title "Company Holiday" \
  --date 2026-03-01 \
  --all-day | bash scripts/guard.sh
```

### Update an Event

```bash
bash scripts/ask.sh "Update event '[title]' — change time to [new time]?"
bash scripts/audit.sh "update" "<event-id>"
python3 scripts/calendar.py update \
  --id <event-id> \
  --time 10:00 \
  --duration 60 | bash scripts/guard.sh
```

### Delete an Event

```bash
bash scripts/ask.sh "Permanently delete event '[title]'? This cannot be undone."
bash scripts/audit.sh "delete" "<event-id>"
python3 scripts/calendar.py delete \
  --id <event-id> | bash scripts/guard.sh
```

---

## Flags Reference

| Subcommand | Flag | Description |
|------------|------|-------------|
| `list` | `--from YYYY-MM-DD` | Start of date range |
| `list` | `--to YYYY-MM-DD` | End of date range |
| `get` | `--id ID` | Event ID |
| `create` | `--title TEXT` | Event title (required) |
| `create` | `--date YYYY-MM-DD` | Event date (required) |
| `create` | `--time HH:MM` | Start time (24h) |
| `create` | `--duration MINUTES` | Duration in minutes |
| `create` | `--description TEXT` | Event description |
| `create` | `--location TEXT` | Event location |
| `create` | `--all-day` | Mark as all-day event |
| `update` | `--id ID` | Event ID (required) |
| `update` | `--title TEXT` | New title |
| `update` | `--date YYYY-MM-DD` | New date |
| `update` | `--time HH:MM` | New start time |
| `update` | `--duration MINUTES` | New duration |
| `update` | `--description TEXT` | New description |
| `update` | `--location TEXT` | New location |
| `delete` | `--id ID` | Event ID (required) |
