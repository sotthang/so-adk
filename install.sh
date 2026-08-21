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
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/session-start-resume.sh" }
        ]
      }
    ],
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
    local post_hook='{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":".claude/hooks/post-edit-check.sh"}]}'
    local start_hook='{"hooks":[{"type":"command","command":".claude/hooks/session-start-resume.sh"}]}'
    local merged
    merged="$(jq --argjson post "$post_hook" --argjson start "$start_hook" '
      .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [$post] | unique_by(.matcher))
      | .hooks.SessionStart = ((.hooks.SessionStart // []) + [$start]
          | unique_by(.hooks[0].command))
    ' "$settings_path")"
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
mkdir -p "./.claude/skills"

# ── Clean up legacy SO-ADK files from older installs ─────────────────────────
# Older versions shipped flat skill files and a /simplify command. The skill
# format is now directory-based (<name>/SKILL.md) and /simplify was renamed to
# /refactor, so the old files are orphans. Remove only SO-ADK-owned paths —
# never touch user-authored skills.
echo "🧹 Cleaning up legacy SO-ADK files..."
LEGACY_FLAT_SKILLS=(dev plan simplify pr so-foundation so-spec-format so-tdd-workflow so-context)
for s in "${LEGACY_FLAT_SKILLS[@]}"; do
  rm -f "./.claude/skills/${s}.md"
  rm -f "./.claude/skills/internal/${s}.md"
done
rmdir "./.claude/skills/internal" 2>/dev/null || true
# Old /simplify skill dir (renamed to refactor) — remove the SO-ADK one only.
# Identify it by the SO-ADK marker so we don't delete an unrelated simplify skill.
if [ -f "./.claude/skills/simplify/SKILL.md" ] && \
   grep -q "so-quality" "./.claude/skills/simplify/SKILL.md" 2>/dev/null; then
  rm -rf "./.claude/skills/simplify"
fi

# Skills are directory-based: .claude/skills/<name>/SKILL.md
# (flat .md files under .claude/skills/ are NOT recognized by Claude Code).
echo "⬇️  Downloading skills..."
SKILLS=(dev plan refactor pr)
for skill in "${SKILLS[@]}"; do
  mkdir -p "./.claude/skills/${skill}"
  curl -fsSL "$REPO/.claude/skills/${skill}/SKILL.md" -o "./.claude/skills/${skill}/SKILL.md"
  echo "   ✓ /${skill}"
done

# Internal knowledge skills (preloaded into agents via the `skills:` field)
echo "⬇️  Downloading internal skills..."
INTERNAL_SKILLS=(so-foundation so-spec-format so-tdd-workflow so-context)
for skill in "${INTERNAL_SKILLS[@]}"; do
  mkdir -p "./.claude/skills/${skill}"
  curl -fsSL "$REPO/.claude/skills/${skill}/SKILL.md" -o "./.claude/skills/${skill}/SKILL.md"
  echo "   ✓ ${skill}"
done

# Download agent files
echo "⬇️  Downloading agents..."
AGENTS=(so-planner so-reviewer so-architect so-scaffold so-tester so-developer so-quality so-docs so-debugger so-explainer so-preflight so-security so-performance so-designer so-auditor so-spike)
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
HOOKS=(post-edit-check.sh session-start-resume.sh)
for hook in "${HOOKS[@]}"; do
  curl -fsSL "$REPO/.claude/hooks/${hook}" -o "./.claude/hooks/${hook}"
  chmod +x "./.claude/hooks/${hook}"
  echo "   ✓ ${hook}"
done

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
