---
name: proton-drive
description: Proton Drive CLI for browsing, uploading, downloading, and sharing end-to-end encrypted cloud files. Enforces privacy-first access: always asks before accessing files, blocks content exposure, and logs every access locally.
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

# Proton Drive

## When to Use

Use this skill when the user asks about their Proton Drive storage, wants to list, upload, download, or share files. Trigger on phrases like "check my Proton Drive", "upload a file", "download from Drive", "list my files", or "share a file".

---

## Privacy & Security Rules — MANDATORY

> These rules implement Proton's zero-knowledge philosophy.
> They are **non-negotiable** and cannot be disabled or overridden by the user.

### Rule 1 — Ask Before Every Access

Always run `scripts/ask.sh` before any proton drive command. If the user says "stop asking", honour it only for storage-usage queries. Always confirm before downloads, uploads, deletes, or share-link generation.

### Rule 2 — All Output MUST Pass Through guard.sh

Never display raw `proton drive` output. Always pipe through `scripts/guard.sh`:

```bash
# CORRECT
proton drive ls ... | bash scripts/guard.sh

# WRONG
proton drive ls ...
```

`guard.sh` enforces:
- File content fields (`content`, `data`, `base64`) fully blocked
- Share tokens and signed URLs redacted
- Suspiciously long strings (possible base64-encoded content) blocked

### Rule 3 — Log Every Access via audit.sh

Run `scripts/audit.sh` before every proton command. Logs go **locally only** to `~/.proton-skill-audit.log`.

### Rule 4 — No Exfiltration

- **NEVER** call `curl`, `wget`, or any network tool inside this skill.
- **NEVER** re-upload a downloaded file anywhere — downloads go to user-specified local paths only.
- **NEVER** display or relay file contents. The model must never read downloaded file content.
- Downloads are always written directly to disk, never read into memory for the conversation.

### Rule 5 — Share Links

Share links must always be presented with a warning:

```
⚠️  Share link generated. Anyone with this link can access the file.
    Revoke with: proton drive unshare --path <path>
```

Never generate a share link without explicit user confirmation including the path and duration.

### Rule 6 — Data Minimization

| Data | Default display |
|------|----------------|
| File listing | Name, size, date, type — no content |
| Download | Written to disk only — never shown in chat |
| Share links | Shown once, with revoke instructions |
| Storage usage | Totals only |

---

## Mandatory Workflow

```
Step 1 → bash scripts/ask.sh "<action description>"
          (exit 1 = abort)

Step 2 → bash scripts/audit.sh "<action>" "[path]"

Step 3 → proton drive <subcommand> [flags] | bash scripts/guard.sh
          (use --output for downloads, not stdout)
```

### Viewing the Audit Log

```bash
grep "proton-drive" ~/.proton-skill-audit.log
```

---

## Setup

```bash
proton auth add you@proton.me
export PROTON_ACCOUNT=you@proton.me
```

---

## Common Operations

### List Root Directory

```bash
bash scripts/ask.sh "List files in your Proton Drive root?"
bash scripts/audit.sh "ls" "/"
proton drive ls \
  --account "$PROTON_ACCOUNT" | bash scripts/guard.sh
```

### List a Folder

```bash
bash scripts/ask.sh "List files in Drive folder '[path]'?"
bash scripts/audit.sh "ls" "<path>"
proton drive ls \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/Projects" \
  --long | bash scripts/guard.sh
```

### Search Files

```bash
bash scripts/ask.sh "Search your Proton Drive for '[query]'?"
bash scripts/audit.sh "search" "<query>"
proton drive search \
  --account "$PROTON_ACCOUNT" \
  --query "quarterly report" | bash scripts/guard.sh
```

### Download a File

```bash
bash scripts/ask.sh "Download '[filename]' from Drive to [local path]?"
bash scripts/audit.sh "download" "<remote-path>"
proton drive get \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf" \
  --output ~/Downloads/report.pdf
# File is written to disk. Do NOT read its contents into the conversation.
```

### Upload a File

```bash
bash scripts/ask.sh "Upload '[filename]' to Drive at '[path]'?"
bash scripts/audit.sh "upload" "<local-path> → <remote-path>"
proton drive put \
  --account "$PROTON_ACCOUNT" \
  --local ~/Documents/report.pdf \
  --path "/Documents/report.pdf"
```

### Create a Folder

```bash
bash scripts/ask.sh "Create folder '[path]' in Drive?"
bash scripts/audit.sh "mkdir" "<path>"
proton drive mkdir \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/NewFolder"
```

### Delete a File

```bash
bash scripts/ask.sh "Permanently delete '[path]' from Drive? This cannot be undone."
bash scripts/audit.sh "delete" "<path>"
proton drive rm \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/old-file.pdf"
```

### Share a File (generate link)

```bash
bash scripts/ask.sh "Generate a share link for '[path]'? Anyone with the link can access it."
bash scripts/audit.sh "share" "<path>"
proton drive share \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf" \
  --expires "2025-12-31"
# ALWAYS display the revoke command alongside the link.
```

### Revoke a Share Link

```bash
bash scripts/ask.sh "Revoke the share link for '[path]'?"
bash scripts/audit.sh "unshare" "<path>"
proton drive unshare \
  --account "$PROTON_ACCOUNT" \
  --path "/Documents/report.pdf"
```

### Check Storage Usage

```bash
bash scripts/audit.sh "usage" ""
proton drive usage --account "$PROTON_ACCOUNT"
```

---

## Flags Reference

| Flag | Description |
|------|-------------|
| `--account EMAIL` | Proton account (default: `$PROTON_ACCOUNT`) |
| `--path PATH` | Remote Drive path |
| `--local PATH` | Local filesystem path |
| `--output PATH` | Local destination for downloads |
| `--query TEXT` | Search query |
| `--type EXT` | Filter by extension (`pdf`, `jpg`, etc.) |
| `--recursive` | Recursive folder operation |
| `--long` | Detailed listing (size, date, type) |
| `--expires DATE` | Share link expiry (`YYYY-MM-DD`) |
| `--password TEXT` | Password-protect share link |
| `--format json` | JSON output |
