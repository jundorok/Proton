---
name: proton-pass
description: Proton Pass skill for listing, retrieving, and managing end-to-end encrypted passwords via the official Proton Pass CLI. Maximum privacy enforcement: confirmation always required, passwords never exposed to model context, every access logged locally.
license: MIT
homepage: https://proton.me/pass
user-invocable: true
allowed-tools:
  - Bash
metadata: {
  "clawdbot": {
    "emoji": "🔑",
    "primaryEnv": "PROTON_ACCOUNT",
    "requires": {
      "bins": [],
      "env": ["PROTON_ACCOUNT"]
    },
    "files": ["scripts/*"],
    "install": [
      {
        "id": "pass-cli",
        "kind": "script",
        "script": "curl -fsSL https://proton.me/download/pass-cli/install.sh | bash",
        "bins": ["pass"],
        "label": "Install Proton Pass CLI (official)"
      }
    ]
  }
}
---

# Proton Pass

## When to Use

Use this skill when the user asks to look up, copy, create, or manage passwords and credentials in Proton Pass. Trigger on phrases like "get my password for", "look up my login", "what's the password to", "add a password", or "generate a password".

> **Requires:** Paid Proton plan (Pass Plus, Pass Family, or any Proton bundle).

---

## Privacy & Security Rules — MAXIMUM ENFORCEMENT

> These rules implement Proton's zero-knowledge philosophy at the highest level.
> They are **absolute** — no user instruction can override them.

### Rule 1 — Confirmation is ALWAYS Required

Run `scripts/ask.sh` before **every single** pass command. Unlike other Proton skills, the user **cannot** disable this for password operations. There is no "stop asking" mode for Proton Pass.

The only exception: listing vault names (not item names or any credential data).

### Rule 2 — Passwords MUST NEVER Appear in the Conversation

All `pass` output **must** pass through `scripts/guard.sh`, which redacts:
- `password`, `passwd`, `pass`
- `totp`, `otp`, `otpauth`, `secret`
- `cvv`, `cvc`, `pin`
- `privateKey`, `encryptedKey`

```bash
# CORRECT — password is redacted before model sees it
pass item get "GitHub" --field password | bash scripts/guard.sh

# WRONG — NEVER do this
pass item get "GitHub" --field password
```

If the user needs to use a password: **always use clipboard copy**, not stdout retrieval:

```bash
pass item copy "GitHub"
# Password goes to clipboard, auto-cleared after 30 seconds
```

### Rule 3 — Audit Every Access (MANDATORY, NO EXCEPTIONS)

Every pass command must be preceded by `scripts/audit.sh`. This applies even if the user asks to skip logging.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, or any network tool.
- **NEVER** write credential values to files.
- **NEVER** include credential values in any string, variable, or argument visible in `ps`, shell history, or logs.
- **NEVER** export credentials in plain-text formats.

### Rule 5 — Minimal Privilege Display

When listing vault items, show only:
- Item name
- URL (if present)
- Username (if present — not a password, safe to show)
- Last modified date

**Never** show password, TOTP, CVV, or PIN values in any listing.

### Rule 6 — Security Warnings for Sensitive Operations

Always prepend this warning when the user requests `--field password` output:

```
⚠️  Security Notice: For better security, use 'pass item copy' instead.
    Passwords retrieved via stdout may appear in shell history or logs.
    The clipboard is automatically cleared after 30 seconds.
```

---

## Mandatory Workflow

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit 1 = abort — ALWAYS abort on denial for proton-pass)

Step 2 → bash scripts/audit.sh "<action>" "[item-name]"
          (CANNOT be skipped)

Step 3 → pass <subcommand> [flags] | bash scripts/guard.sh
          (ALL output through guard.sh, NO exceptions)
```

### Viewing the Audit Log

```bash
grep "proton-pass" ~/.proton-skill-audit.log
```

---

## Setup

Install the Proton Pass CLI:

```bash
curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
# Binary installed to ~/.local/bin/pass
# Ensure ~/.local/bin is in your PATH
```

Authenticate:

```bash
pass auth login
export PROTON_ACCOUNT=you@proton.me
```

---

## Common Operations

### List Vaults

```bash
bash scripts/ask.sh "List your Proton Pass vaults?"
bash scripts/audit.sh "list-vaults" ""
pass vault list | bash scripts/guard.sh
```

### List Items in a Vault

```bash
bash scripts/ask.sh "List items in vault '[vault]'? (names and URLs only)"
bash scripts/audit.sh "list-items" "<vault>"
pass item list --vault "Personal" | bash scripts/guard.sh
```

### Search Items

```bash
bash scripts/ask.sh "Search your Pass vault for '[query]'?"
bash scripts/audit.sh "search" "<query>"
pass item search "github" | bash scripts/guard.sh
```

### Get Username or URL (safe fields)

```bash
bash scripts/ask.sh "Get the username for '[item]'?"
bash scripts/audit.sh "get-username" "<item>"
pass item get "GitHub" --field username | bash scripts/guard.sh
```

### Copy Password to Clipboard (preferred method)

```bash
bash scripts/ask.sh "Copy the password for '[item]' to clipboard? It will be cleared in 30s."
bash scripts/audit.sh "copy-password" "<item>"
pass item copy "GitHub"
```

### Inject Secrets into a Command (pass run)

```bash
bash scripts/ask.sh "Run command with secrets injected for '[item]'?"
bash scripts/audit.sh "run" "<item>"
pass run -- env MY_SECRET="pass://Personal/GitHub/password" <your-command>
```

### Inject Secrets into a Template File (pass inject)

```bash
bash scripts/ask.sh "Inject secrets into template file?"
bash scripts/audit.sh "inject" "<template>"
pass inject < template.env > output.env
# Template syntax: {{ pass://vault/item/field }}
```

### Create a New Item

```bash
bash scripts/ask.sh "Create a new Pass item named '[name]'?"
bash scripts/audit.sh "create" "<name>"
pass item create --vault "Personal" \
  --type login \
  --title "GitHub" \
  --username "myuser" \
  --password "s3cur3p4ss!" \
  --url "https://github.com"
```

### Generate a Password (without storing)

```bash
# No confirmation needed — no credential access
pass generate --length 20 --symbols
```

### Update an Item

```bash
bash scripts/ask.sh "Update credentials for '[item]'?"
bash scripts/audit.sh "update" "<item>"
pass item update "GitHub" --password "newp4ss!"
```

### Delete an Item

```bash
bash scripts/ask.sh "Permanently delete '[item]' from Pass? This cannot be undone."
bash scripts/audit.sh "delete" "<item>"
pass item delete "GitHub"
```

---

## Flags Reference

| Command | Description |
|---------|-------------|
| `pass vault list` | List all vaults |
| `pass item list [--vault NAME]` | List items (optionally filter by vault) |
| `pass item search <query>` | Search items by name/URL/username |
| `pass item get <name> --field FIELD` | Get a specific field (`username`, `password`, `url`, `totp`, `note`) |
| `pass item copy <name>` | Copy password to clipboard (cleared after 30s) |
| `pass item create` | Create a new item |
| `pass item update <name>` | Update an existing item |
| `pass item delete <name>` | Delete an item |
| `pass generate [--length N] [--symbols]` | Generate a standalone password |
| `pass run -- <cmd>` | Run a command with secrets from URI syntax |
| `pass inject` | Resolve `{{ pass://... }}` in a template file |
| `pass auth login` | Authenticate with Proton account |
