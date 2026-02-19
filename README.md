# Proton

OpenClaw skills for the Proton ecosystem — Mail, Calendar, and Pass.

## Skills

| Skill | Description | Emoji |
|-------|-------------|-------|
| [`proton-mail`](skills/proton-mail/) | Read, send, search, and manage encrypted email | ✉️ |
| [`proton-calendar`](skills/proton-calendar/) | View and manage calendar events via web automation | 📅 |
| [`proton-pass`](skills/proton-pass/) | Retrieve, copy, and manage encrypted passwords | 🔑 |

All skills enforce a configurable **ask-before-read** behavior that prompts for confirmation before accessing any sensitive content.

## Requirements

### proton-mail
- `python3`
- `proton-client` Python package (`pip install proton-client`)
- `PROTON_ACCOUNT` — your Proton email address
- `PROTON_PASSWORD` — your Proton account password

### proton-calendar
- `python3`
- `playwright` Python package + Chromium (`pip install playwright && playwright install chromium`)
- `PROTON_ACCOUNT` — your Proton email address
- `PROTON_PASSWORD` — your Proton account password

### proton-pass
- Proton Pass CLI (`pass` binary)
- A paid Proton plan (Pass Plus, Pass Family, or Proton bundle)

## Installation

### proton-mail

```bash
pip install proton-client
export PROTON_ACCOUNT=you@proton.me
export PROTON_PASSWORD=yourpassword
```

### proton-calendar

```bash
pip install playwright
playwright install chromium
export PROTON_ACCOUNT=you@proton.me
export PROTON_PASSWORD=yourpassword
```

### proton-pass

```bash
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
# Binary installs to ~/.local/bin/pass
```

### Install Skills via ClawHub

```bash
clawhub install proton-mail
clawhub install proton-calendar
clawhub install proton-pass
```

## Ask-Before-Read

Every skill asks for explicit confirmation before accessing sensitive data. This is enabled by default.

| Skill | What triggers a confirmation |
|-------|------------------------------|
| Mail | Before listing inbox, reading a message, or searching |
| Calendar | Before listing events, and always for create/update/delete |
| Pass | Before listing items, retrieving passwords, or copying to clipboard |

To skip confirmation for the current session, tell the agent: _"stop asking"_, _"don't ask"_, or _"disable confirmations"_.

> **Note:** Proton Pass credential retrieval always requires confirmation and cannot be disabled.

## Skill Structure

```
skills/
├── proton-mail/
│   ├── SKILL.md
│   └── scripts/
│       ├── ask.sh
│       ├── audit.sh
│       ├── guard.sh
│       └── mail.py         # proton-python-client wrapper
├── proton-calendar/
│   ├── SKILL.md
│   └── scripts/
│       ├── ask.sh
│       ├── audit.sh
│       ├── guard.sh
│       └── calendar.py     # Playwright web automation
└── proton-pass/
    ├── SKILL.md
    └── scripts/
        ├── ask.sh
        ├── audit.sh
        └── guard.sh
```

## License

MIT
