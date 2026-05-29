#!/usr/bin/env bash
# session-start-resume.sh — SessionStart hook
# Scans specs/SPEC-*.md (active, non-archived) for any SPEC whose Status is not "Done"
# and injects a resume notice into the session context. This makes SO-ADK's
# "session resume" (Orchestrator Step 0) deterministic instead of relying on the
# model to remember to scan specs/ on every start.
#
# Output contract: exit 0 with JSON containing hookSpecificOutput.additionalContext.

# Consume stdin to avoid broken pipe
cat > /dev/null

shopt -s nullglob
PENDING=""
for f in specs/SPEC-*.md; do
  # Skip files without a Status line; capture the first Status value.
  status="$(grep -m1 -iE '^[[:space:]]*(\*\*)?Status(\*\*)?[[:space:]]*:' "$f" | sed -E 's/.*:[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$status" ] && status="(unknown)"
  case "$status" in
    Done|done|DONE) ;;  # completed — ignore
    *) PENDING="${PENDING}  - ${f} (Status: ${status})"$'\n' ;;
  esac
done

# No pending work → emit nothing (exit 0, no context).
[ -z "$PENDING" ] && exit 0

CONTEXT="⏸️ SO-ADK: 진행 중인(미완료) SPEC이 있습니다. 새 요청이 없다면 이어서 진행할지 사용자에게 먼저 물어보세요.
${PENDING}Pipeline Resume Map에 따라 해당 Status의 다음 단계부터 재개하세요."

# JSON-encode safely. Prefer jq; fall back to a minimal escaper.
if command -v jq &>/dev/null; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  # Minimal escape: backslashes, double quotes, then newlines → \n
  esc="${CONTEXT//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
fi
exit 0
