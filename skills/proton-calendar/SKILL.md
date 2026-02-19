---
name: proton-calendar
description: Proton Calendar CLI for viewing, creating, and managing end-to-end encrypted calendar events and schedules. Asks for explicit confirmation before reading calendar data.
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

# Proton Calendar

## When to Use

Use this skill when the user asks about their schedule, wants to see upcoming events, find available time, create or update calendar events, or manage their Proton Calendar. Trigger on phrases like "check my calendar", "what's on my schedule", "create an event", "find a free slot", or "what do I have today/this week".

## Setup

One-time authentication (run once per account):

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

## Ask-Before-Read Behavior

**Default: ALWAYS ask before accessing calendar data.**

Before listing or reading any calendar events, confirm with the user using `scripts/ask.sh`.

### When to ask

| Action | Confirmation prompt |
|--------|-------------------|
| Show today's events | "Show your calendar for today?" |
| Show week/month | "Show your schedule for [this week / this month]?" |
| Show specific date range | "Show your calendar from [start] to [end]?" |
| Read event details | "Show details for '[event name]'?" |
| Check availability | "Check your availability for [date/range]?" |

### Disabling confirmation

If the user says "stop asking", "don't ask", "just do it", or "disable confirmations", skip the prompt for the rest of the session.

Run the confirm helper:

```bash
bash scripts/ask.sh "Show your calendar for this week?"
# Exit 0 = confirmed, exit 1 = cancelled
```

## Common Operations

### Today's Events

```bash
proton calendar today --account "$PROTON_ACCOUNT"
```

### This Week

```bash
proton calendar week --account "$PROTON_ACCOUNT"
```

### Custom Date Range

```bash
proton calendar list \
  --account "$PROTON_ACCOUNT" \
  --from "2025-06-01" \
  --to "2025-06-30"
```

### Show a Specific Day

```bash
proton calendar list \
  --account "$PROTON_ACCOUNT" \
  --date "2025-06-15"
```

### Read Event Details

```bash
proton calendar show \
  --account "$PROTON_ACCOUNT" \
  --id <event-id>
```

### Create an Event

```bash
proton calendar create \
  --account "$PROTON_ACCOUNT" \
  --title "Team Standup" \
  --start "2025-06-15T09:00:00" \
  --end "2025-06-15T09:30:00" \
  --description "Daily team sync" \
  --location "Zoom"
```

Add attendees:

```bash
proton calendar create \
  --account "$PROTON_ACCOUNT" \
  --title "Project Review" \
  --start "2025-06-15T14:00:00" \
  --end "2025-06-15T15:00:00" \
  --attendees "alice@example.com,bob@example.com"
```

Recurring event:

```bash
proton calendar create \
  --account "$PROTON_ACCOUNT" \
  --title "Weekly 1:1" \
  --start "2025-06-16T10:00:00" \
  --end "2025-06-16T10:30:00" \
  --recurrence "RRULE:FREQ=WEEKLY;BYDAY=MO"
```

### Update an Event

```bash
proton calendar update \
  --account "$PROTON_ACCOUNT" \
  --id <event-id> \
  --title "Updated Title" \
  --start "2025-06-15T10:00:00" \
  --end "2025-06-15T10:30:00"
```

### Delete an Event

```bash
proton calendar delete \
  --account "$PROTON_ACCOUNT" \
  --id <event-id>
```

### Find Free Time Slots

```bash
proton calendar availability \
  --account "$PROTON_ACCOUNT" \
  --date "2025-06-15" \
  --duration 60
```

Find slots over multiple days:

```bash
proton calendar availability \
  --account "$PROTON_ACCOUNT" \
  --from "2025-06-15" \
  --to "2025-06-19" \
  --duration 30 \
  --working-hours "09:00-17:00"
```

### List Calendars

```bash
proton calendar list-calendars --account "$PROTON_ACCOUNT"
```

### Export Events (ICS)

```bash
proton calendar export \
  --account "$PROTON_ACCOUNT" \
  --from "2025-01-01" \
  --to "2025-12-31" \
  --output ~/backup/calendar-2025.ics
```

### Import Events (ICS)

```bash
proton calendar import \
  --account "$PROTON_ACCOUNT" \
  --file ~/backup/calendar-2025.ics
```

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account to use (default: `$PROTON_ACCOUNT`) |
| `--date DATE` | Single date (`YYYY-MM-DD`) |
| `--from DATE` | Range start date (`YYYY-MM-DD`) |
| `--to DATE` | Range end date (`YYYY-MM-DD`) |
| `--id EVENT_ID` | Target a specific event by ID |
| `--title TEXT` | Event title |
| `--start DATETIME` | Event start (`YYYY-MM-DDTHH:MM:SS`) |
| `--end DATETIME` | Event end (`YYYY-MM-DDTHH:MM:SS`) |
| `--description TEXT` | Event description |
| `--location TEXT` | Event location |
| `--attendees CSV` | Comma-separated attendee emails |
| `--recurrence RRULE` | iCal RRULE string for recurring events |
| `--duration MINUTES` | Duration for availability search |
| `--working-hours HH:MM-HH:MM` | Working hours for availability search |
| `--calendar-id ID` | Target a specific sub-calendar |
| `--format json` | Output as JSON for scripting |

## Examples

```bash
# Quick daily briefing
proton calendar today --account "$PROTON_ACCOUNT"

# Monthly view as JSON
proton calendar list \
  --account "$PROTON_ACCOUNT" \
  --from "$(date +%Y-%m-01)" \
  --format json

# Find a 1-hour slot this week
proton calendar availability \
  --account "$PROTON_ACCOUNT" \
  --from "$(date +%Y-%m-%d)" \
  --to "$(date -d '+7 days' +%Y-%m-%d)" \
  --duration 60 \
  --working-hours "09:00-18:00"
```
