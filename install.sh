#!/bin/bash
set -e

# SO-ADK Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

REPO="https://raw.githubusercontent.com/sotthang/so-adk/main"

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
AGENTS=(so-planner so-reviewer so-architect so-tester so-developer so-quality so-docs so-debugger so-explainer so-preflight so-security so-performance)
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

# Create specs directory
mkdir -p "./specs"
touch "./specs/.gitkeep"

echo ""
echo "✅ SO-ADK installed successfully!"
echo ""
echo "그냥 말하면 됩니다:"
echo '  "로그인 기능 만들어줘"  → 전체 파이프라인 자동 실행'
echo '  "이 버그 고쳐줘"        → 디버거 → 개발자 직접 연결'
echo '  "PR 만들어줘"           → Preflight + Security → PR 생성'
echo ""
