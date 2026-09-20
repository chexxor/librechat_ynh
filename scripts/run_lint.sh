#!/bin/bash
# Deterministic linter runner for the LibreChat YunoHost package.
#
# This wrapper exists because package_linter is NOT pure Python: it shells out
# to grep/sed/head/du/file via subprocess(shell=True), which on Windows routes
# through cmd.exe and crashes. It MUST run under WSL2 with a POSIX app path and
# a Python >= 3.11 interpreter (uv provisions 3.12; WSL's system python is 3.8
# and too old).
#
# Usage:
#   wsl -e bash -lc 'bash /mnt/c/Users/Alex/Projects/librechat_ynh/scripts/run_lint.sh'
#
# The script always completes and writes both artifacts; the phase's pass/fail
# assertions live in the verify commands, not here. Its own exit code is 0
# unless a provisioning step genuinely failed.

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
export PYTHONUTF8=1

APPDIR="${1:-/mnt/c/Users/Alex/Projects/librechat_ynh}"
OUT="$APPDIR/.planning/phases/04-lint-baseline"
LINTER_DIR="${LINTER_DIR:-/tmp/pl}"

mkdir -p "$OUT"

# --- Idempotent provisioning (safe to re-run) -----------------------------
if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ ! -d "$LINTER_DIR" ]; then
    git clone --depth 1 https://github.com/YunoHost/package_linter "$LINTER_DIR"
fi

if [ ! -d "$LINTER_DIR/.venv" ]; then
    uv venv --python 3.12 "$LINTER_DIR/.venv"
fi

# Run unconditionally for determinism; fast when already satisfied.
uv pip install --python "$LINTER_DIR/.venv/bin/python" -r "$LINTER_DIR/requirements.txt" >/dev/null

# --- Run the linter twice, capturing both artifacts -----------------------
# The linter's .apps cache path is relative to cwd.
cd "$LINTER_DIR"

set +e
"$LINTER_DIR/.venv/bin/python" "$LINTER_DIR/package_linter.py" "$APPDIR" \
    > "$OUT/lint-baseline.txt" 2>&1
TEXT_EXIT=$?
set -e
echo "exit_code=$TEXT_EXIT" >> "$OUT/lint-baseline.txt"

# --json always exits 0; never assert on this exit code.
"$LINTER_DIR/.venv/bin/python" "$LINTER_DIR/package_linter.py" "$APPDIR" --json \
    > "$OUT/lint-baseline.json"

# --- Summary --------------------------------------------------------------
echo "run_lint.sh complete"
echo "  app path:  $APPDIR"
echo "  text:      $OUT/lint-baseline.txt (text-mode exit_code=$TEXT_EXIT)"
echo "  json:      $OUT/lint-baseline.json"
echo "  linter:    $LINTER_DIR (never committed)"
