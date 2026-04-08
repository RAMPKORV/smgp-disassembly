#!/usr/bin/env bash
# tools/pre-commit.sh
#
# Installs a Git pre-commit hook that runs verify.bat (or build.sh on
# non-Windows) and tools/run_checks.js before every commit.
#
# Usage (run once from the repo root):
#   bash tools/pre-commit.sh
#
# To uninstall, delete .git/hooks/pre-commit

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_DIR="$REPO_ROOT/.git/hooks"
HOOK_FILE="$HOOK_DIR/pre-commit"

if [ ! -d "$HOOK_DIR" ]; then
  echo "ERROR: .git/hooks directory not found. Run this from inside the repo." >&2
  exit 1
fi

# Detect platform: use verify.bat on Windows (Git Bash / MSYS2), build.sh elsewhere
if [[ "$(uname -s)" =~ MINGW|CYGWIN|MSYS ]]; then
  VERIFY_CMD='cmd.exe /c verify.bat'
  VERIFY_LABEL='verify.bat'
else
  VERIFY_CMD='bash build.sh && echo "SHA256 check skipped on non-Windows (manual step)"'
  VERIFY_LABEL='build.sh'
fi

cat > "$HOOK_FILE" <<HOOK
#!/bin/sh
# pre-commit hook for Super Monaco GP disassembly
# Installed by tools/pre-commit.sh
#
# Runs:
#   1. ${VERIFY_LABEL}  -- bit-perfect SHA256 check (Windows) / build check
#   2. node tools/run_checks.js  -- structural integrity checks

set -e

REPO_ROOT="\$(git rev-parse --show-toplevel)"
cd "\$REPO_ROOT"

echo "=== pre-commit: running ${VERIFY_LABEL} ==="
${VERIFY_CMD}
if [ \$? -ne 0 ]; then
  echo "ERROR: ${VERIFY_LABEL} failed -- build is not bit-perfect"
  exit 1
fi

echo "=== pre-commit: running run_checks.js ==="
node tools/run_checks.js
if [ \$? -ne 0 ]; then
  echo "ERROR: run_checks.js failed -- fix structural errors before committing"
  exit 1
fi

echo "pre-commit checks passed."
HOOK

chmod +x "$HOOK_FILE"

echo "Installed pre-commit hook at: $HOOK_FILE"
echo ""
echo "The hook will run ${VERIFY_LABEL} and node tools/run_checks.js before each commit."
echo "To skip in an emergency: git commit --no-verify"
echo "To uninstall: rm \"$HOOK_FILE\""
