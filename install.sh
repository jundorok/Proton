#!/usr/bin/env bash
# Proton Skills — Manual Install Script
#
# Copies skills into the OpenClaw skills directory AND installs all dependencies.
#
# Usage:
#   bash install.sh                            # auto-detect skills dir, install deps
#   bash install.sh --skills-dir /custom/path  # specify skills dir manually
#   bash install.sh --no-deps                  # skip dependency installation

set -euo pipefail

INSTALL_DEPS=true

# ── Parse args ────────────────────────────────────────────────────────────────
SKILLS_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        --no-deps)
            INSTALL_DEPS=false
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# ── Detect OpenClaw skills directory ─────────────────────────────────────────
detect_skills_dir() {
    local candidates=(
        "$HOME/.openclaw/skills"
        "$HOME/.config/openclaw/skills"
        "$HOME/.local/share/openclaw/skills"
        "$HOME/.claude/skills"
    )
    for dir in "${candidates[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return
        fi
    done
    echo ""
}

if [[ -z "$SKILLS_DIR" ]]; then
    SKILLS_DIR="$(detect_skills_dir)"
fi

if [[ -z "$SKILLS_DIR" ]]; then
    echo "Could not auto-detect OpenClaw skills directory."
    read -r -p "Enter the path to your OpenClaw skills directory: " SKILLS_DIR
fi

SKILLS_DIR="${SKILLS_DIR/#\~/$HOME}"

# ── Install dependencies ──────────────────────────────────────────────────────
if [[ "$INSTALL_DEPS" == true ]]; then
    echo ""
    echo "── Installing dependencies ───────────────────────────────"

    # proton-client (for proton-mail)
    if python3 -c "import proton" 2>/dev/null; then
        echo "  ✓  proton-client already installed"
    else
        echo "  →  Installing proton-client..."
        pip install proton-client
        echo "  ✓  proton-client installed"
    fi

    # playwright (for proton-calendar)
    if python3 -c "import playwright" 2>/dev/null; then
        echo "  ✓  playwright already installed"
    else
        echo "  →  Installing playwright..."
        pip install playwright
        echo "  ✓  playwright installed"
    fi

    # playwright chromium browser
    if python3 -c "
from playwright.sync_api import sync_playwright
try:
    with sync_playwright() as p:
        p.chromium.launch(headless=True).close()
    print('ok')
except Exception:
    exit(1)
" 2>/dev/null | grep -q ok; then
        echo "  ✓  Chromium already installed"
    else
        echo "  →  Installing Chromium..."
        playwright install chromium
        echo "  ✓  Chromium installed"
    fi

    # Proton Pass CLI (for proton-pass)
    if command -v pass &>/dev/null; then
        echo "  ✓  Proton Pass CLI already installed"
    else
        echo "  →  Installing Proton Pass CLI..."
        curl -fsSL https://proton.me/download/pass-cli/install.sh | bash
        # Add ~/.local/bin to PATH for this session if needed
        export PATH="$HOME/.local/bin:$PATH"
        if command -v pass &>/dev/null; then
            echo "  ✓  Proton Pass CLI installed"
        else
            echo "  !  Proton Pass CLI installed to ~/.local/bin/pass"
            echo "     Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
fi

# ── Copy skills ───────────────────────────────────────────────────────────────
echo ""
echo "── Installing skills to: $SKILLS_DIR"
echo ""

mkdir -p "$SKILLS_DIR"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

for skill in proton-mail proton-calendar proton-pass; do
    src="$REPO_DIR/skills/$skill"
    dst="$SKILLS_DIR/$skill"

    if [[ -d "$dst" ]]; then
        echo "  ⟳  $skill (updating)"
        rm -rf "$dst"
    else
        echo "  +  $skill (new)"
    fi

    cp -r "$src" "$dst"
    chmod +x "$dst"/scripts/*.sh 2>/dev/null || true
done

echo ""
echo "Skills installed:"
ls "$SKILLS_DIR" | grep proton || true

# ── Final status check ────────────────────────────────────────────────────────
echo ""
echo "── Status ────────────────────────────────────────────────"

ok()  { echo "  ✓  $1"; }
fail(){ echo "  ✗  $1"; }

command -v python3  &>/dev/null && ok "python3"           || fail "python3 — not found"
python3 -c "import proton"      2>/dev/null && ok "proton-client"    || fail "proton-client — pip install proton-client"
python3 -c "import playwright"  2>/dev/null && ok "playwright"       || fail "playwright — pip install playwright"
command -v pass     &>/dev/null && ok "pass (Proton Pass CLI)" || fail "pass — curl -fsSL https://proton.me/download/pass-cli/install.sh | bash"

echo ""
echo "── Environment variables ─────────────────────────────────"
[[ -n "${PROTON_ACCOUNT:-}" ]] \
    && ok  "PROTON_ACCOUNT = $PROTON_ACCOUNT" \
    || fail "PROTON_ACCOUNT not set — export PROTON_ACCOUNT=you@proton.me"

[[ -n "${PROTON_PASSWORD:-}" ]] \
    && ok  "PROTON_PASSWORD = (set)" \
    || fail "PROTON_PASSWORD not set — export PROTON_PASSWORD=yourpassword"

echo ""
echo "Done. Refresh the Skills panel in OpenClaw to see all three skills as eligible."
echo ""
