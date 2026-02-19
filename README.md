# Proton

OpenClaw skills for the Proton ecosystem — Mail, Calendar, Drive, and Pass.

## Skills

| Skill | Description | Emoji |
|-------|-------------|-------|
| [`proton-mail`](skills/proton-mail/) | Read, send, search, and manage encrypted email | ✉️ |
| [`proton-calendar`](skills/proton-calendar/) | View, create, and manage calendar events | 📅 |
| [`proton-drive`](skills/proton-drive/) | Browse, upload, download, and share cloud files | ☁️ |
| [`proton-pass`](skills/proton-pass/) | Retrieve, copy, and manage encrypted passwords | 🔑 |

All four skills share a common `proton` CLI binary and a configurable **ask-before-read** behavior that prompts for confirmation before accessing any sensitive content.

## Requirements

- `proton` CLI binary (see installation below)
- A Proton account (proton.me)
- `PROTON_ACCOUNT` environment variable set to your Proton email

## Installation

### Install the `proton` CLI

**macOS (Homebrew):**
```bash
brew install proton/tap/proton-cli
```

**npm (all platforms):**
```bash
npm install -g @proton/cli
```

### Authenticate

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

Add to your shell profile to persist:
```bash
echo 'export PROTON_ACCOUNT=you@proton.me' >> ~/.zshrc
```

### Install Skills via ClawHub

```bash
clawhub install proton-mail
clawhub install proton-calendar
clawhub install proton-drive
clawhub install proton-pass
```

Or install all at once:
```bash
clawhub install proton-mail proton-calendar proton-drive proton-pass
```

## Ask-Before-Read

Every skill asks for explicit confirmation before accessing sensitive data. This is enabled by default.

| Skill | What triggers a confirmation |
|-------|------------------------------|
| Mail | Before listing inbox, reading a message, or searching |
| Calendar | Before showing events or checking availability |
| Drive | Before listing folders, downloading, or searching |
| Pass | Before listing items, retrieving passwords, or copying to clipboard |

To skip confirmation for the current session, tell the agent: _"stop asking"_, _"don't ask"_, or _"disable confirmations"_.

> **Note:** Proton Pass credential retrieval always requires confirmation and cannot be disabled.

## Skill Structure

```
skills/
├── proton-mail/
│   ├── SKILL.md          # Skill instructions + frontmatter
│   └── scripts/
│       └── ask.sh        # Confirmation prompt helper
├── proton-calendar/
│   ├── SKILL.md
│   └── scripts/
│       └── ask.sh
├── proton-drive/
│   ├── SKILL.md
│   └── scripts/
│       └── ask.sh
└── proton-pass/
    ├── SKILL.md
    └── scripts/
        └── ask.sh
```

## License

MIT
