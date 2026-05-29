#!/usr/bin/env bash
# post-edit-check.sh — PostToolUse hook: runs lint/typecheck after Edit/Write/MultiEdit
# Stdin: Claude Code hook JSON (ignored — cwd-based detection)
#
# Exit codes (Claude Code PostToolUse contract):
#   0 = all checks passed (or none applicable)
#   2 = a check failed → BLOCKS the next loop iteration and feeds stderr back to Claude
#       so the agent sees the lint/typecheck errors and fixes them before continuing.
# All tool output is routed to stderr so it reaches Claude on exit 2.

# Consume stdin to avoid broken pipe
cat > /dev/null

FAILED=0
SCRIPT_NAME="$(basename "$0")"

# Run a check; on failure mark FAILED. Output (stdout+stderr) goes to stderr.
run_check() {
  local label="$1"; shift
  "$@" 1>&2
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "$SCRIPT_NAME: $label failed (exit $rc)" >&2
    FAILED=1
  fi
}

# ── Node.js / npm ──────────────────────────────────────────────────────────
if [ -f "package.json" ]; then
  grep -q '"lint"'      package.json && run_check "npm run lint"      npm run lint --silent
  grep -q '"typecheck"' package.json && run_check "npm run typecheck" npm run typecheck --silent
fi

# ── Python ───────────────────────────────────────────────────────────────────
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  command -v ruff &>/dev/null && run_check "ruff check" ruff check .
  command -v mypy &>/dev/null && run_check "mypy"       mypy .
fi

# ── Go ─────────────────────────────────────────────────────────────────────
if [ -f "go.mod" ]; then
  command -v go &>/dev/null && run_check "go vet" go vet ./...
fi

# ── Rust ───────────────────────────────────────────────────────────────────
if [ -f "Cargo.toml" ]; then
  command -v cargo &>/dev/null && run_check "cargo check" cargo check
fi

# Exit 2 (not the raw rc) so PostToolUse surfaces failures to Claude as feedback.
[ "$FAILED" -ne 0 ] && exit 2
exit 0
