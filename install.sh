#!/bin/bash
set -e

# SO-ADK Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash
#   install.sh --dry-run-merge <target_dir>  — merge settings.json only, no agent download

REPO="https://raw.githubusercontent.com/sotthang/so-adk/main"

# ── settings.json 병합 함수 ────────────────────────────────────────────────
SETTINGS_TEMPLATE='{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/post-edit-check.sh" }
        ]
      }
    ]
  }
}'

merge_settings_json() {
  local target_dir="$1"
  local settings_path="$target_dir/.claude/settings.json"
  mkdir -p "$target_dir/.claude"

  if [ ! -f "$settings_path" ]; then
    echo "$SETTINGS_TEMPLATE" > "$settings_path"
    echo "   ✓ settings.json created from template"
    return 0
  fi

  # 기존 파일이 있으면 jq로 병합
  if command -v jq &>/dev/null; then
    local hook_entry='{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":".claude/hooks/post-edit-check.sh"}]}'
    local merged
    merged="$(jq --argjson hook "$hook_entry" \
      '.hooks.PostToolUse = ((.hooks.PostToolUse // []) + [$hook] | unique_by(.matcher))' \
      "$settings_path")"
    echo "$merged" > "$settings_path"
    echo "   ✓ settings.json merged (existing keys preserved)"
  else
    echo "⚠️  jq not found in PATH — cannot auto-merge settings.json" >&2
    echo "   Please manually merge the following into $settings_path:" >&2
    echo "$SETTINGS_TEMPLATE" >&2
  fi
}

# ── --dry-run-merge 분기 ───────────────────────────────────────────────────
if [ "${1:-}" = "--dry-run-merge" ]; then
  TARGET="${2:-}"
  if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
    echo "ERROR: --dry-run-merge requires a valid target directory as second argument" >&2
    exit 1
  fi
  merge_settings_json "$TARGET"
  exit 0
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║         SO-ADK Installer         ║"
echo "╚══════════════════════════════════╝"
echo ""
echo "📁 Installing into current project: $(pwd)"
echo ""

# Create directories
mkdir -p "./.claude/agents"
mkdir -p "./.claude/skills/internal"

# Download user-facing skill files
echo "⬇️  Downloading skills..."
SKILLS=(dev plan simplify pr)
for skill in "${SKILLS[@]}"; do
  curl -fsSL "$REPO/.claude/skills/${skill}.md" -o "./.claude/skills/${skill}.md"
  echo "   ✓ /${skill}"
done

# Download internal skill files
echo "⬇️  Downloading internal skills..."
INTERNAL_SKILLS=(so-foundation so-spec-format so-tdd-workflow so-context)
for skill in "${INTERNAL_SKILLS[@]}"; do
  curl -fsSL "$REPO/.claude/skills/internal/${skill}.md" -o "./.claude/skills/internal/${skill}.md"
  echo "   ✓ ${skill}"
done

# Download agent files
echo "⬇️  Downloading agents..."
AGENTS=(so-planner so-reviewer so-architect so-tester so-developer so-quality so-docs so-debugger so-explainer so-preflight so-security so-performance so-designer so-auditor)
for agent in "${AGENTS[@]}"; do
  curl -fsSL "$REPO/.claude/agents/${agent}.md" -o "./.claude/agents/${agent}.md"
  echo "   ✓ ${agent}"
done

# Always update the orchestrator file (SO-ADK owned, safe to overwrite)
curl -fsSL "$REPO/.claude/so-orchestrator.md" -o "./.claude/so-orchestrator.md"
echo "   ✓ .claude/so-orchestrator.md"

# Add import line to CLAUDE.md
IMPORT_LINE="@.claude/so-orchestrator.md"

if [ -f "./CLAUDE.md" ]; then
  if grep -qF "$IMPORT_LINE" "./CLAUDE.md"; then
    echo "   ↩ CLAUDE.md already imports so-orchestrator (skipped)"
  else
    echo "" >> "./CLAUDE.md"
    echo "$IMPORT_LINE" >> "./CLAUDE.md"
    echo "   ✓ CLAUDE.md — appended import line"
  fi
else
  echo "$IMPORT_LINE" > "./CLAUDE.md"
  echo "   ✓ CLAUDE.md created"
fi

# Download hooks
echo "⬇️  Downloading hooks..."
mkdir -p "./.claude/hooks"
curl -fsSL "$REPO/.claude/hooks/post-edit-check.sh" -o "./.claude/hooks/post-edit-check.sh"
chmod +x "./.claude/hooks/post-edit-check.sh"
echo "   ✓ post-edit-check.sh"

# Merge settings.json (PostToolUse hook)
merge_settings_json "."

# Create specs directory
mkdir -p "./specs/archive"
touch "./specs/.gitkeep"
touch "./specs/archive/.gitkeep"

echo ""
echo "✅ SO-ADK installed successfully!"
echo ""
echo "그냥 말하면 됩니다:"
echo '  "로그인 기능 만들어줘"  → 전체 파이프라인 자동 실행'
echo '  "이 버그 고쳐줘"        → 디버거 → 개발자 직접 연결'
echo '  "PR 만들어줘"           → Preflight + Security → PR 생성'
echo ""
