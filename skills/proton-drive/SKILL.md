---
name: proton-drive
description: Proton Drive CLI for browsing, uploading, downloading, and sharing end-to-end encrypted cloud files. Asks for explicit confirmation before accessing any file or folder contents.
license: MIT
homepage: https://proton.me/drive
user-invocable: true
allowed-tools:
  - Bash
metadata: {
  "clawdbot": {
    "emoji": "☁️",
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

# Proton Drive

## When to Use

Use this skill when the user asks about their Proton Drive storage, wants to list, upload, download, or share files, or manage their cloud storage. Trigger on phrases like "check my Proton Drive", "upload a file", "download from Drive", "list my Drive files", "share a file", or "how much storage do I have".

## Setup

One-time authentication (run once per account):

```bash
proton auth add you@proton.me
proton auth list
export PROTON_ACCOUNT=you@proton.me
```

## Ask-Before-Read Behavior

**Default: ALWAYS ask before accessing Drive contents.**

Before listing or reading any Drive files or folders, confirm with the user using `scripts/ask.sh`.

### When to ask

| Action | Confirmation prompt |
|--------|-------------------|
| List root / folder | "List files in [path / your Drive root]?" |
| Read / download file | "Download '[filename]' from Drive?" |
| Search Drive | "Search your Drive for '[query]'?" |
| Show storage usage | "Show your Proton Drive storage usage?" |

### Disabling confirmation

If the user says "stop asking", "don't ask", "just do it", or "disable confirmations", skip the prompt for the rest of the session.

Run the confirm helper:

```bash
bash scripts/ask.sh "List files in your Drive root?"
# Exit 0 = confirmed, exit 1 = cancelled
```

## Common Operations

### List Root Directory

```bash
proton drive ls --account "$PROTON_ACCOUNT"
```

### List a Specific Folder

```bash
proton drive ls \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/Projects"
```

### List with Details (size, date, type)

```bash
proton drive ls \
  --account "$PROTON_ACCOUNT" \
  --path "/" \
  --long
```

### Search Files

```bash
proton drive search \
  --account "$PROTON_ACCOUNT" \
  --query "quarterly report"
```

Search by file type:

```bash
proton drive search \
  --account "$PROTON_ACCOUNT" \
  --query "invoice" \
  --type pdf
```

### Download a File

```bash
proton drive get \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf" \
  --output ~/Downloads/report.pdf
```

Download a folder recursively:

```bash
proton drive get \
  --account "$PROTON_ACCOUNT" \
  --path "/Projects/2025" \
  --output ~/Downloads/Projects-2025 \
  --recursive
```

### Upload a File

```bash
proton drive put \
  --account "$PROTON_ACCOUNT" \
  --local ~/Documents/report.pdf \
  --path "/Documents/report.pdf"
```

Upload a folder:

```bash
proton drive put \
  --account "$PROTON_ACCOUNT" \
  --local ~/Projects/myapp \
  --path "/Projects/myapp" \
  --recursive
```

### Create a Folder

```bash
proton drive mkdir \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/NewFolder"
```

### Move / Rename

```bash
proton drive mv \
  --account "$PROTON_ACCOUNT" \
  --from "/Documents/old-name.pdf" \
  --to "/Documents/new-name.pdf"
```

### Delete a File or Folder

```bash
proton drive rm \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/old-file.pdf"
```

### Share a File (generate link)

```bash
proton drive share \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf"
```

Share with expiry:

```bash
proton drive share \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf" \
  --expires "2025-12-31" \
  --password "sharepass123"
```

### Revoke a Share Link

```bash
proton drive unshare \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf"
```

### Check Storage Usage

```bash
proton drive usage --account "$PROTON_ACCOUNT"
```

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account to use (default: `$PROTON_ACCOUNT`) |
| `--path PATH` | Remote Drive path |
| `--local PATH` | Local filesystem path |
| `--output PATH` | Local destination for downloads |
| `--query TEXT` | Search query string |
| `--type EXT` | Filter by file extension (e.g. `pdf`, `jpg`, `mp4`) |
| `--recursive` | Operate recursively on folders |
| `--long` | Long listing with size, date, and type |
| `--from PATH` | Source path (for move operations) |
| `--to PATH` | Destination path (for move operations) |
| `--expires DATE` | Share link expiry date (`YYYY-MM-DD`) |
| `--password TEXT` | Password-protect a share link |
| `--format json` | Output as JSON for scripting |

## Examples

```bash
# Check total storage
proton drive usage --account "$PROTON_ACCOUNT"

# List the entire tree as JSON
proton drive ls --account "$PROTON_ACCOUNT" --path "/" --long --format json

# Sync a local backup folder to Drive
proton drive put \
  --account "$PROTON_ACCOUNT" \
  --local ~/Backups/2025 \
  --path "/Backups/2025" \
  --recursive

# Share a file with a time-limited link
proton drive share \
  --account "$PROTON_ACCOUNT" \
  --path "/Shared/proposal.pdf" \
  --expires "$(date -d '+7 days' +%Y-%m-%d)"
```
