#!/bin/bash
set -e

# SO-ADK Installer
# Usage:
#   Global install (skills available in all projects):
#     curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash
#
#   Local install (current project only):
#     curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --local

REPO="https://raw.githubusercontent.com/sotthang/so-adk/main"
MODE="global"

# Parse args
for arg in "$@"; do
  case $arg in
    --local) MODE="local" ;;
  esac
done

echo ""
echo "╔══════════════════════════════════╗"
echo "║         SO-ADK Installer         ║"
echo "╚══════════════════════════════════╝"
echo ""

# Determine target directories
if [ "$MODE" = "local" ]; then
  SKILLS_DIR="./.claude/skills"
  AGENTS_DIR="./.claude/agents"
  CLAUDE_MD_TARGET="./CLAUDE.md"
  echo "📁 Mode: Local install (current project)"
else
  SKILLS_DIR="$HOME/.claude/skills"
  AGENTS_DIR="$HOME/.claude/agents"
  CLAUDE_MD_TARGET=""
  echo "📁 Mode: Global install (~/.claude/)"
fi

echo ""

# Create directories
mkdir -p "$SKILLS_DIR"
mkdir -p "$AGENTS_DIR"

# Download skill files
echo "⬇️  Downloading skills..."
SKILLS=(dev plan simplify pr)
for skill in "${SKILLS[@]}"; do
  curl -fsSL "$REPO/.claude/skills/${skill}.md" -o "$SKILLS_DIR/${skill}.md"
  echo "   ✓ /$(basename $skill .md)"
done

# Download agent files
echo "⬇️  Downloading agents..."
AGENTS=(planner reviewer architect tester developer quality docs)
for agent in "${AGENTS[@]}"; do
  curl -fsSL "$REPO/.claude/agents/${agent}.md" -o "$AGENTS_DIR/${agent}.md"
  echo "   ✓ ${agent}"
done

# Handle CLAUDE.md
if [ "$MODE" = "local" ]; then
  if [ -f "./CLAUDE.md" ]; then
    echo ""
    echo "⚠️  CLAUDE.md already exists in this project."
    read -p "   Overwrite? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      curl -fsSL "$REPO/CLAUDE.md" -o "./CLAUDE.md"
      echo "   ✓ CLAUDE.md updated"
    else
      echo "   ↩ Skipped CLAUDE.md"
    fi
  else
    curl -fsSL "$REPO/CLAUDE.md" -o "./CLAUDE.md"
    echo "   ✓ CLAUDE.md created"
  fi
fi

echo ""
echo "✅ SO-ADK installed successfully!"
echo ""
if [ "$MODE" = "global" ]; then
  echo "Skills are now available in all Claude Code projects."
  echo "To also add CLAUDE.md to a project: run with --local flag inside that project."
else
  echo "Skills and CLAUDE.md are ready in this project."
fi
echo ""
echo "Available slash commands:"
echo "  /dev \"feature description\"  — full pipeline (Plan → Build → Test → Docs)"
echo "  /plan \"feature description\" — generate SPEC only"
echo "  /simplify                   — review and refactor code"
echo "  /pr                         — create a pull request"
echo ""
