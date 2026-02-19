---
name: proton-pass
description: Proton Pass CLI for listing, retrieving, copying, and managing end-to-end encrypted passwords and secure items. Always asks for explicit confirmation before revealing any credential.
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

# Proton Pass

## When to Use

Use this skill when the user asks to look up a password or credential, find login details, add or update a password, or manage their Proton Pass vaults. Trigger on phrases like "get my password for", "look up my login for", "what's the password to", "add a password", "generate a password", or "list my passwords".

## Setup

One-time authentication (run once per account):

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

## Ask-Before-Read Behavior

**Default: ALWAYS ask before accessing any credential or vault content.**

This is a security-critical skill. Confirmation is required before every read operation regardless of session state — even if the user has disabled confirmations for other Proton skills.

### When to ask

| Action | Confirmation prompt |
|--------|-------------------|
| List vault items | "List items in vault '[vault name]'?" |
| Get password | "Retrieve the password for '[item name]'?" |
| Get full item details | "Show all credentials for '[item name]'?" |
| Copy to clipboard | "Copy the password for '[item name]' to clipboard?" |
| Export vault | "Export all items from vault '[vault name]'?" |

### Disabling confirmation (read-list only)

The user may disable confirmation for **listing** vault names and item names only (no credential values). They may NOT disable confirmation for password retrieval or clipboard copy.

If the user says "stop asking to list", skip the listing confirmation only. Always confirm before revealing actual credentials.

Run the confirm helper:

```bash
bash scripts/ask.sh "Retrieve the password for 'GitHub'?"
# Exit 0 = confirmed, exit 1 = cancelled
```

## Common Operations

### List All Vaults

```bash
proton pass vaults --account "$PROTON_ACCOUNT"
```

### List Items in a Vault

```bash
proton pass list \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal"
```

List all vaults:

```bash
proton pass list --account "$PROTON_ACCOUNT"
```

### Get an Item (username + URL only, no password)

```bash
proton pass get \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --field username

proton pass get \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --field url
```

### Retrieve a Password

**Always confirm before running this command.**

```bash
proton pass get \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --field password
```

### Copy Password to Clipboard

**Always confirm before running this command.**

```bash
proton pass copy \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub"
```

The password is placed in the clipboard and cleared after 30 seconds automatically.

### Search Items

```bash
proton pass search \
  --account "$PROTON_ACCOUNT" \
  --query "github"
```

### Create a New Item

```bash
proton pass create \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --name "GitHub" \
  --username "myuser" \
  --password "s3cur3p4ss!" \
  --url "https://github.com"
```

### Generate and Store a Password

```bash
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
proton pass generate \
  --length 20 \
  --symbols \
  --no-ambiguous
```

### Update an Existing Item

```bash
proton pass update \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub" \
  --password "newp4ss!" \
  --username "newuser"
```

### Delete an Item

```bash
proton pass delete \
  --account "$PROTON_ACCOUNT" \
  --item "GitHub"
```

### Add a Secure Note

```bash
proton pass note create \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --name "SSH Key Passphrase" \
  --content "My passphrase is ..."
```

### Add a Credit Card

```bash
proton pass card create \
  --account "$PROTON_ACCOUNT" \
  --vault "Financial" \
  --name "Visa Debit" \
  --number "4111111111111111" \
  --expiry "12/27" \
  --cvv "123" \
  --cardholder "Jane Doe"
```

### Export Vault (encrypted)

**Always confirm before running this command.**

```bash
proton pass export \
  --account "$PROTON_ACCOUNT" \
  --vault "Personal" \
  --output ~/backup/pass-personal.pgp \
  --format pgp
```

### Import from Another Password Manager

```bash
proton pass import \
  --account "$PROTON_ACCOUNT" \
  --vault "Imported" \
  --file ~/export/lastpass.csv \
  --format lastpass
```

Supported import formats: `lastpass`, `1password`, `bitwarden`, `keepass`, `dashlane`, `csv`

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account to use (default: `$PROTON_ACCOUNT`) |
| `--vault NAME` | Target vault by name |
| `--item NAME` | Target item by name or ID |
| `--field FIELD` | Field to retrieve: `username`, `password`, `url`, `totp`, `note` |
| `--query TEXT` | Search query string |
| `--name TEXT` | Item name (create/update) |
| `--username TEXT` | Username (create/update) |
| `--password TEXT` | Password value (create/update) |
| `--url URL` | Website URL (create/update) |
| `--generate-password` | Auto-generate a strong password |
| `--length N` | Generated password length (default: `20`) |
| `--symbols` | Include symbols in generated password |
| `--no-ambiguous` | Exclude ambiguous characters (0, O, l, 1) |
| `--output PATH` | Local output path (export) |
| `--format FORMAT` | Export/import format |
| `--format json` | Output as JSON for scripting |

## Security Notes

- Passwords retrieved with `--field password` are printed to stdout. Avoid logging or capturing stdout in insecure locations.
- Use `proton pass copy` over `proton pass get --field password` when possible — clipboard is auto-cleared after 30s.
- Never store `PROTON_ACCOUNT` credentials in plain-text files or scripts committed to version control.
- Exported vaults should always use encrypted formats (`pgp`, `proton`) rather than plain CSV in production.

## Examples

```bash
# Find a login and copy its password
proton pass search --account "$PROTON_ACCOUNT" --query "github"
proton pass copy  --account "$PROTON_ACCOUNT" --item "GitHub"

# Generate a strong password for a new account
proton pass generate --length 32 --symbols --no-ambiguous

# Create an item with a generated password
proton pass create \
  --account "$PROTON_ACCOUNT" \
  --vault "Work" \
  --name "Jira" \
  --username "jane@company.com" \
  --url "https://company.atlassian.net" \
  --generate-password --length 24 --symbols
```
