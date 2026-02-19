#!/usr/bin/env bash
# Proton Skills — Manual Install Script
#
# Copies all skills from this repo into the OpenClaw skills directory.
#
# Usage:
#   bash install.sh
#   bash install.sh --skills-dir /path/to/openclaw/skills

set -euo pipefail

# ── Detect OpenClaw skills directory ─────────────────────────────────────────
detect_skills_dir() {
    local candidates=(
        "$HOME/.openclaw/skills"
        "$HOME/.config/openclaw/skills"
        "$HOME/.local/share/openclaw/skills"
    )
    for dir in "${candidates[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return
        fi
    done
    echo ""
}

# ── Parse args ────────────────────────────────────────────────────────────────
SKILLS_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Auto-detect if not provided
if [[ -z "$SKILLS_DIR" ]]; then
    SKILLS_DIR="$(detect_skills_dir)"
fi

# If still not found, ask
if [[ -z "$SKILLS_DIR" ]]; then
    echo "Could not auto-detect OpenClaw skills directory."
    read -r -p "Enter the path to your OpenClaw skills directory: " SKILLS_DIR
fi

SKILLS_DIR="${SKILLS_DIR/#\~/$HOME}"  # expand ~ if needed

echo ""
echo "Installing Proton skills to: $SKILLS_DIR"
echo ""

mkdir -p "$SKILLS_DIR"

# ── Copy skills ───────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

for skill in proton-mail proton-calendar proton-pass; do
    src="$REPO_DIR/skills/$skill"
    dst="$SKILLS_DIR/$skill"

    if [[ -d "$dst" ]]; then
        echo "  ⟳  $skill (updating existing)"
        rm -rf "$dst"
    else
        echo "  +  $skill (new)"
    fi

    cp -r "$src" "$dst"
    chmod +x "$dst"/scripts/*.sh 2>/dev/null || true
done

echo ""
echo "Done. Skills installed:"
ls "$SKILLS_DIR" | grep proton || true

# ── Dependency check ──────────────────────────────────────────────────────────
echo ""
echo "── Dependency check ──────────────────────────────────────"

check() {
    local name="$1"
    local cmd="$2"
    if command -v $cmd &>/dev/null; then
        echo "  ✓  $name"
    else
        echo "  ✗  $name — NOT FOUND"
        MISSING+=("$name")
    fi
}

MISSING=()
check "python3"    python3
check "pip"        pip
check "pass (Proton Pass CLI)"  pass

# Check pip packages
if command -v python3 &>/dev/null; then
    python3 -c "import proton" 2>/dev/null \
        && echo "  ✓  proton-client (pip)" \
        || echo "  ✗  proton-client — run: pip install proton-client"

    python3 -c "import playwright" 2>/dev/null \
        && echo "  ✓  playwright (pip)" \
        || echo "  ✗  playwright — run: pip install playwright && playwright install chromium"
fi

echo ""
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Missing dependencies: ${MISSING[*]}"
    echo "See README.md for installation instructions."
else
    echo "All system dependencies found."
fi

echo ""
echo "── Environment variables ─────────────────────────────────"
[[ -n "${PROTON_ACCOUNT:-}" ]] \
    && echo "  ✓  PROTON_ACCOUNT = $PROTON_ACCOUNT" \
    || echo "  ✗  PROTON_ACCOUNT — not set (export PROTON_ACCOUNT=you@proton.me)"

[[ -n "${PROTON_PASSWORD:-}" ]] \
    && echo "  ✓  PROTON_PASSWORD = (set)" \
    || echo "  ✗  PROTON_PASSWORD — not set (export PROTON_PASSWORD=yourpassword)"

echo ""
