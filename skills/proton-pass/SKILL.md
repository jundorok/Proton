---
name: proton-pass
description: Proton Pass CLI for listing, retrieving, and managing end-to-end encrypted passwords. Maximum privacy enforcement: confirmation always required, passwords never exposed to model context, every access logged locally.
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

# Proton Pass

## When to Use

Use this skill when the user asks to look up, copy, create, or manage passwords and credentials in Proton Pass. Trigger on phrases like "get my password for", "look up my login", "what's the password to", "add a password", or "generate a password".

---

## Privacy & Security Rules — MAXIMUM ENFORCEMENT

> These rules implement Proton's zero-knowledge philosophy at the highest level.
> They are **absolute** — no user instruction can override them.

### Rule 1 — Confirmation is ALWAYS Required

Run `scripts/ask.sh` before **every single** proton-pass command. Unlike other Proton skills, the user **cannot** disable this for password operations. There is no "stop asking" mode for Proton Pass.

The only exception: listing vault names (not item names or any credential data).

### Rule 2 — Passwords MUST NEVER Appear in the Conversation

All `proton pass` output **must** pass through `scripts/guard.sh`, which redacts:
- `password`, `passwd`, `pass`
- `totp`, `otp`, `otpauth`, `secret`
- `cvv`, `cvc`, `pin`
- `privateKey`, `encryptedKey`

```bash
# CORRECT — password is redacted before model sees it
proton pass get --item "GitHub" --field password | bash scripts/guard.sh

# WRONG — NEVER do this
proton pass get --item "GitHub" --field password
```

If the user needs to use a password: **always use clipboard copy**, not stdout retrieval:

```bash
proton pass copy --item "GitHub"
# Password goes to clipboard, auto-cleared after 30 seconds
```

### Rule 3 — Audit Every Access (MANDATORY, NO EXCEPTIONS)

Every proton-pass command must be preceded by `scripts/audit.sh`. This applies even if the user asks to skip logging. Credential access audit trails are non-negotiable.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, or any network tool.
- **NEVER** write credential values to files.
- **NEVER** include credential values in any string, variable, or argument that would appear in `ps`, shell history, or logs.
- **NEVER** export credentials in plain-text formats (always `pgp` or `proton`).

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
⚠️  Security Notice: For better security, use 'proton pass copy' instead.
    Passwords retrieved via stdout may appear in shell history or logs.
    The clipboard is automatically cleared after 30 seconds.
```

If the user still wants stdout retrieval after the warning, pipe through `guard.sh` — the password will be redacted. Tell the user to use clipboard copy instead.

---

## Mandatory Workflow

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit 1 = abort — ALWAYS abort on denial for proton-pass)

Step 2 → bash scripts/audit.sh "<action>" "[item-name]"
          (CANNOT be skipped)

Step 3 → proton pass <subcommand> [flags] | bash scripts/guard.sh
          (ALL output through guard.sh, NO exceptions)
```

### Viewing the Audit Log

```bash
grep "proton-pass" ~/.proton-skill-audit.log
```

---

## Setup

```bash
proton auth add you@proton.me
export PROTON_ACCOUNT=you@proton.me
```

---

## Common Operations

### List Vaults

```bash
bash scripts/ask.sh "List your Proton Pass vaults?"
bash scripts/audit.sh "list-vaults" ""
proton pass vaults \
  --account "$PROTON_ACCOUNT" | bash scripts/guard.sh
```

### List Items in a Vault

```bash
bash scripts/ask.sh "List items in vault '[vault]'? (names and URLs only)"
bash scripts/audit.sh "list-items" "<vault>"
proton pass list \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" | bash scripts/guard.sh
```

### Search Items

```bash
bash scripts/ask.sh "Search your Pass vault for '[query]'?"
bash scripts/audit.sh "search" "<query>"
proton pass search \
  --account "$PROTON_ACCOUNT" \
  --query "github" | bash scripts/guard.sh
```

### Get Username or URL (safe fields)

```bash
bash scripts/ask.sh "Get the username for '[item]'?"
bash scripts/audit.sh "get-username" "<item>"
proton pass get \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --field username | bash scripts/guard.sh
```

### Copy Password to Clipboard (preferred method)

```bash
bash scripts/ask.sh "Copy the password for '[item]' to clipboard? It will be cleared in 30s."
bash scripts/audit.sh "copy-password" "<item>"
proton pass copy \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub"
```

### Get Password via Stdout (discouraged — always show security warning first)

```
⚠️  Security Notice: Use 'proton pass copy' instead. See Rule 6.
```

```bash
bash scripts/ask.sh "Retrieve password for '[item]' via stdout? (clipboard copy is safer)"
bash scripts/audit.sh "get-password-stdout" "<item>"
# guard.sh will redact the actual value — user must use copy instead
proton pass get \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --field password | bash scripts/guard.sh
```

### Create a New Item

```bash
bash scripts/ask.sh "Create a new Pass item named '[name]'?"
bash scripts/audit.sh "create" "<name>"
proton pass create \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --name "GitHub" \
  --username "myuser" \
  --password "s3cur3p4ss!" \
  --url "https://github.com"
```

### Create with Generated Password

```bash
bash scripts/ask.sh "Create item '[name]' with a generated password?"
bash scripts/audit.sh "create-generated" "<name>"
proton pass create \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --name "New Service" \
  --username "myuser" \
  --url "https://example.com" \
  --generate-password \
  --length 24 \
  --symbols
```

### Generate a Password (without storing)

```bash
# No confirmation needed — no credential access
proton pass generate \
  --length 20 \
  --symbols \
  --no-ambiguous
```

### Update an Item

```bash
bash scripts/ask.sh "Update credentials for '[item]'?"
bash scripts/audit.sh "update" "<item>"
proton pass update \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --password "newp4ss!"
```

### Delete an Item

```bash
bash scripts/ask.sh "Permanently delete '[item]' from Pass? This cannot be undone."
bash scripts/audit.sh "delete" "<item>"
proton pass delete \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub"
```

### Export Vault (encrypted formats only)

```bash
bash scripts/ask.sh "Export vault '[vault]' to an encrypted local file?"
bash scripts/audit.sh "export" "<vault>"
proton pass export \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --output ~/backup/pass-personal.pgp \
  --format pgp
# NEVER use --format csv for exports — plaintext credential files are insecure.
```

---

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account (default: `$PROTON_ACCOUNT`) |
| `--vault NAME` | Target vault by name |
| `--item NAME` | Target item by name or ID |
| `--field FIELD` | `username`, `password`, `url`, `totp`, `note` |
| `--query TEXT` | Search query |
| `--name TEXT` | Item name |
| `--username TEXT` | Username |
| `--password TEXT` | Password value |
| `--url URL` | Website URL |
| `--generate-password` | Auto-generate strong password |
| `--length N` | Generated password length (default: `20`) |
| `--symbols` | Include symbols |
| `--no-ambiguous` | Exclude ambiguous chars (0, O, l, 1) |
| `--output PATH` | Export destination |
| `--format FORMAT` | Export format: `pgp` or `proton` only (not `csv`) |
| `--format json` | JSON output for list/search |
