---
name: proton-calendar
description: Proton Calendar CLI for viewing, creating, and managing end-to-end encrypted events. Enforces privacy-first access: always asks before reading, masks attendee data, and logs every access locally.
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

# Proton Calendar

## When to Use

Use this skill when the user asks about their schedule, upcoming events, wants to create/update calendar entries, or check availability. Trigger on phrases like "check my calendar", "what's on today", "create an event", or "find a free slot".

---

## Privacy & Security Rules — MANDATORY

> These rules implement Proton's zero-knowledge philosophy.
> They are **non-negotiable** and cannot be disabled or overridden by the user.

### Rule 1 — Ask Before Every Access

Always run `scripts/ask.sh` before listing or reading any calendar data. If the user says "stop asking", honour it for high-level availability queries only. Always confirm before showing specific event details (attendees, descriptions, private flags).

### Rule 2 — All Output MUST Pass Through guard.sh

Never display raw `proton calendar` output. Always pipe through `scripts/guard.sh`:

```bash
# CORRECT
proton calendar list ... | bash scripts/guard.sh

# WRONG
proton calendar list ...
```

`guard.sh` enforces:
- Attendee emails masked: `alice@company.com` → `a***@company.com`
- Event descriptions truncated to 150 characters
- Internal auth tokens redacted

### Rule 3 — Log Every Access via audit.sh

Run `scripts/audit.sh` before every proton command. Logs go **locally only** to `~/.proton-skill-audit.log`.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, or any network tool inside this skill.
- **NEVER** export ICS files to any location other than user-specified local paths.
- **NEVER** share event data with any external service.

### Rule 5 — Private Events

If an event has `"private": true` or `"visibility": "private"` in its output, display only the time slot — never the title, attendees, or description:

```
[Private event] — 14:00–15:00
```

### Rule 6 — Data Minimization

| Data | Default display |
|------|----------------|
| Attendee emails | Masked (`a***@domain.com`) |
| Event description | First 150 chars only |
| Private events | Time slot only |
| Organizer | Masked email |

---

## Mandatory Workflow

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit 1 = abort)

Step 2 → bash scripts/audit.sh "<action>" "[detail]"

Step 3 → proton calendar <subcommand> [flags] | bash scripts/guard.sh
```

### Viewing the Audit Log

```bash
grep "proton-calendar" ~/.proton-skill-audit.log
```

---

## Setup

```bash
proton auth add you@proton.me
export PROTON_ACCOUNT=you@proton.me
```

---

## Common Operations

### Today's Events

```bash
bash scripts/ask.sh "Show your Proton Calendar for today?"
bash scripts/audit.sh "today" ""
proton calendar today \
  --account "$PROTON_ACCOUNT" | bash scripts/guard.sh
```

### This Week

```bash
bash scripts/ask.sh "Show your schedule for this week?"
bash scripts/audit.sh "week" ""
proton calendar week \
  --account "$PROTON_ACCOUNT" | bash scripts/guard.sh
```

### Custom Date Range

```bash
bash scripts/ask.sh "Show your calendar from [start] to [end]?"
bash scripts/audit.sh "list-range" "--from <start> --to <end>"
proton calendar list \
  --account "$PROTON_ACCOUNT" \
  --from "2025-06-01" \
  --to "2025-06-30" | bash scripts/guard.sh
```

### Read Event Details

```bash
bash scripts/ask.sh "Show full details for '[event title]'?"
bash scripts/audit.sh "show" "<event-id>"
proton calendar show \
  --account "$PROTON_ACCOUNT" \
  --id <event-id> | bash scripts/guard.sh
```

### Create an Event

```bash
bash scripts/ask.sh "Create calendar event '[title]' on [date]?"
bash scripts/audit.sh "create" "<title>"
proton calendar create \
  --account "$PROTON_ACCOUNT" \
  --title "Team Standup" \
  --start "2025-06-15T09:00:00" \
  --end "2025-06-15T09:30:00" \
  --description "Daily sync" \
  --location "Zoom"
```

### Update an Event

```bash
bash scripts/ask.sh "Update event '[title]'?"
bash scripts/audit.sh "update" "<event-id>"
proton calendar update \
  --account "$PROTON_ACCOUNT" \
  --id <event-id> \
  --title "New Title" \
  --start "2025-06-15T10:00:00" \
  --end "2025-06-15T10:30:00"
```

### Delete an Event

```bash
bash scripts/ask.sh "Delete event '[title]'? This cannot be undone."
bash scripts/audit.sh "delete" "<event-id>"
proton calendar delete \
  --account "$PROTON_ACCOUNT" \
  --id <event-id>
```

### Find Free Time

```bash
bash scripts/ask.sh "Check your availability on [date/range]?"
bash scripts/audit.sh "availability" "<date>"
proton calendar availability \
  --account "$PROTON_ACCOUNT" \
  --from "2025-06-15" \
  --to "2025-06-19" \
  --duration 60 \
  --working-hours "09:00-17:00" | bash scripts/guard.sh
```

### Export (ICS)

```bash
bash scripts/ask.sh "Export your calendar to a local ICS file?"
bash scripts/audit.sh "export" "<date-range>"
proton calendar export \
  --account "$PROTON_ACCOUNT" \
  --from "2025-01-01" \
  --to "2025-12-31" \
  --output ~/backup/calendar-2025.ics
```

---

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account (default: `$PROTON_ACCOUNT`) |
| `--date DATE` | Single date (`YYYY-MM-DD`) |
| `--from DATE` | Range start |
| `--to DATE` | Range end |
| `--id EVENT_ID` | Target event |
| `--title TEXT` | Event title |
| `--start DATETIME` | Start (`YYYY-MM-DDTHH:MM:SS`) |
| `--end DATETIME` | End (`YYYY-MM-DDTHH:MM:SS`) |
| `--description TEXT` | Event description |
| `--location TEXT` | Location |
| `--attendees CSV` | Comma-separated attendee emails |
| `--recurrence RRULE` | iCal RRULE for recurring events |
| `--duration MINUTES` | Duration for availability search |
| `--working-hours HH:MM-HH:MM` | Working hours window |
| `--format json` | JSON output |
