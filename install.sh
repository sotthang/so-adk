#!/usr/bin/env bash
# SO-ADK Migration Wrapper
#
# SO-ADK is now distributed as a Claude Code plugin (marketplace + 2 plugins:
# so-adk-core, so-adk-orchestrator). This script no longer downloads or
# installs anything itself — it only helps existing curl-based installs
# migrate their legacy .claude/ assets out of the way (backup, not delete)
# so that the plugin equivalents can take over without local files
# overriding them.
#
# Usage:
#   install.sh              — diagnosis only, no changes (detects legacy assets)
#   install.sh --dry-run    — print the migration plan, no changes
#   install.sh --migrate    — perform the migration (backup + remove hook entries)
#   install.sh --help       — show this usage
#
# After migrating, install the plugins:
#   claude plugin marketplace add sotthang/so-adk
#   claude plugin install so-adk-core@so-adk --scope project
#   claude plugin install so-adk-orchestrator@so-adk --scope project   # optional

set -uo pipefail

# ── 동결된 레거시 집합 (frozen legacy set) ──────────────────────────────────
# 이 목록들은 curl 기반 구 설치 방식이 만들어낸 자산의 고정 스냅샷이다.
# 더 이상 자라지 않으므로(플러그인 전환 후 신규 에이전트/스킬은 여기 추가되지
# 않는다) install.sh 나열 누락 버그 클래스에 해당하지 않는다.
LEGACY_AGENTS=(so-planner so-reviewer so-architect so-scaffold so-tester
               so-developer so-quality so-docs so-debugger so-explainer
               so-preflight so-security so-performance so-designer
               so-auditor so-spike)
LEGACY_INTERNAL_SKILLS=(so-foundation so-spec-format so-tdd-workflow so-context)
LEGACY_GUARDED_SKILLS=(dev plan pr refactor simplify)   # simplify = refactor의 rename 이전 이름
# 구 배포는 스킬을 평탄 파일로 내보냈다(.claude/skills/<name>.md, 내부 스킬은
# .claude/skills/internal/<name>.md). 현행 디렉터리 형식과 함께 3종을 모두 검사한다.
SKILL_MARKER="Claude normally triggers this automatically"
LEGACY_HOOKS=(post-edit-check.sh session-start-resume.sh)
LEGACY_ORCH=".claude/so-orchestrator.md"
LEGACY_CLAUDE_MD_IMPORT="@.claude/so-orchestrator.md"

usage() {
  cat <<'EOF'
SO-ADK Migration Wrapper

Usage:
  install.sh              diagnosis only, no changes
  install.sh --dry-run     print migration plan, no changes
  install.sh --migrate     perform migration (backup legacy assets, remove hook entries)
  install.sh --help        show this help

After migrating, install the plugins:
  claude plugin marketplace add sotthang/so-adk
  claude plugin install so-adk-core@so-adk --scope project
  claude plugin install so-adk-orchestrator@so-adk --scope project   # optional
EOF
}

# ── 레거시 감지 (읽기 전용) ─────────────────────────────────────────────────
FOUND_AGENTS=()
FOUND_INTERNAL_SKILLS=()
FOUND_GUARDED_SKILLS=()
FOUND_HOOKS=()
FOUND_ORCH=0

detect_legacy() {
  FOUND_AGENTS=()
  FOUND_INTERNAL_SKILLS=()
  FOUND_GUARDED_SKILLS=()
  FOUND_HOOKS=()
  FOUND_ORCH=0

  local a s h
  for a in "${LEGACY_AGENTS[@]}"; do
    if [ -f ".claude/agents/${a}.md" ] && grep -q "so-foundation" ".claude/agents/${a}.md" 2>/dev/null; then
      FOUND_AGENTS+=("$a")
    fi
  done
  # 내부 스킬(so-* 전유 이름) — 마커 무가드. 디렉터리 / 평탄 / 구 internal 평탄.
  for s in "${LEGACY_INTERNAL_SKILLS[@]}"; do
    [ -d ".claude/skills/${s}" ]              && FOUND_INTERNAL_SKILLS+=(".claude/skills/${s}")
    [ -f ".claude/skills/${s}.md" ]           && FOUND_INTERNAL_SKILLS+=(".claude/skills/${s}.md")
    [ -f ".claude/skills/internal/${s}.md" ]  && FOUND_INTERNAL_SKILLS+=(".claude/skills/internal/${s}.md")
  done
  # 사용자 호출 스킬 — 동명의 사용자 작성 스킬을 건드리지 않도록 레이아웃 무관 마커 가드.
  local p
  for s in "${LEGACY_GUARDED_SKILLS[@]}"; do
    for p in ".claude/skills/${s}/SKILL.md" ".claude/skills/${s}.md" ".claude/skills/internal/${s}.md"; do
      if [ -f "$p" ] && grep -qF "$SKILL_MARKER" "$p" 2>/dev/null; then
        # 디렉터리 형식은 디렉터리째 이동한다
        case "$p" in
          */SKILL.md) FOUND_GUARDED_SKILLS+=("${p%/SKILL.md}") ;;
          *)          FOUND_GUARDED_SKILLS+=("$p") ;;
        esac
      fi
    done
  done
  for h in "${LEGACY_HOOKS[@]}"; do
    [ -f ".claude/hooks/${h}" ] && FOUND_HOOKS+=("$h")
  done
  [ -f "$LEGACY_ORCH" ] && FOUND_ORCH=1

  local total=$(( ${#FOUND_AGENTS[@]} + ${#FOUND_INTERNAL_SKILLS[@]} + ${#FOUND_GUARDED_SKILLS[@]} + ${#FOUND_HOOKS[@]} + FOUND_ORCH ))
  [ "$total" -gt 0 ]
}

print_detected() {
  echo "Detected legacy SO-ADK assets:"
  [ "${#FOUND_AGENTS[@]}" -gt 0 ]           && printf '  agent: %s\n' "${FOUND_AGENTS[@]}"
  [ "${#FOUND_INTERNAL_SKILLS[@]}" -gt 0 ]  && printf '  internal skill: %s\n' "${FOUND_INTERNAL_SKILLS[@]}"
  [ "${#FOUND_GUARDED_SKILLS[@]}" -gt 0 ]   && printf '  skill: %s\n' "${FOUND_GUARDED_SKILLS[@]}"
  [ "${#FOUND_HOOKS[@]}" -gt 0 ]            && printf '  hook: %s\n' "${FOUND_HOOKS[@]}"
  [ "$FOUND_ORCH" -eq 1 ]                   && echo "  orchestrator: $LEGACY_ORCH"
}

print_install_guidance() {
  cat <<'EOF'

Install SO-ADK as a plugin:
  claude plugin marketplace add sotthang/so-adk
  claude plugin install so-adk-core@so-adk --scope project
  claude plugin install so-adk-orchestrator@so-adk --scope project   # optional

Note: a plugin installed at --scope project cannot be removed with a plain
uninstall (it is shared with the team) — use --scope local to disable it
locally instead.
EOF
}

print_nothing_to_migrate() {
  echo "No legacy SO-ADK assets detected — nothing to migrate."
  print_install_guidance
}

# ── --dry-run 계획 출력 ──────────────────────────────────────────────────
print_dry_run_plan() {
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  echo "Migration plan (--dry-run, no changes will be made):"
  echo ""
  echo "Backup target: .claude/.so-adk-backup-${ts}/"
  local a s h
  for a in "${FOUND_AGENTS[@]}"; do
    echo "  mv .claude/agents/${a}.md -> .claude/.so-adk-backup-${ts}/agents/${a}.md"
  done
  # set -u 하에서 빈 배열 전개는 오류이므로 ${arr[@]+...} 로 보호한다
  for s in ${FOUND_INTERNAL_SKILLS[@]+"${FOUND_INTERNAL_SKILLS[@]}"} ${FOUND_GUARDED_SKILLS[@]+"${FOUND_GUARDED_SKILLS[@]}"}; do
    echo "  mv ${s} -> .claude/.so-adk-backup-${ts}/${s#.claude/}"
  done
  for h in "${FOUND_HOOKS[@]}"; do
    echo "  mv .claude/hooks/${h} -> .claude/.so-adk-backup-${ts}/hooks/${h}"
  done
  if [ "$FOUND_ORCH" -eq 1 ]; then
    echo "  mv $LEGACY_ORCH -> .claude/.so-adk-backup-${ts}/so-orchestrator.md"
  fi
  echo ""
  if [ -f "CLAUDE.md" ] && grep -qxF "$LEGACY_CLAUDE_MD_IMPORT" "CLAUDE.md" 2>/dev/null; then
    echo "CLAUDE.md: remove line '${LEGACY_CLAUDE_MD_IMPORT}' (file kept even if it becomes empty)"
  fi
  if [ -f ".claude/settings.json" ]; then
    echo "settings.json: remove SO-ADK PostToolUse/SessionStart hook entries (other keys preserved)"
  fi
}

# ── 훅 엔트리 제거 게이트 (파일 이동보다 선행) ────────────────────────────
_manual_hook_removal_instructions() {
  cat <<'EOF'
Could not automatically remove the SO-ADK hook entries from .claude/settings.json.
To avoid leaving orphaned hook references, no files were moved.

Please manually remove these entries from .claude/settings.json, then re-run
install.sh --migrate:
  - .hooks.PostToolUse entry whose command is ".claude/hooks/post-edit-check.sh"
  - .hooks.SessionStart entry whose command is ".claude/hooks/session-start-resume.sh"
EOF
}

# 반환 0: 제거 성공(또는 제거할 것이 없음) — 이후 파일 이동 진행 가능
# 반환 1: 제거 실패 — 파일 이동 중단
remove_hook_entries() {
  local settings=".claude/settings.json"
  if [ ! -f "$settings" ]; then
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    if grep -qE '\.claude/hooks/(post-edit-check|session-start-resume)\.sh' "$settings" 2>/dev/null; then
      echo "jq not found in PATH." >&2
      _manual_hook_removal_instructions
      return 1
    fi
    return 0
  fi

  if ! jq . "$settings" &>/dev/null; then
    echo ".claude/settings.json is not valid JSON." >&2
    _manual_hook_removal_instructions
    return 1
  fi

  local tmp
  tmp="$(mktemp)"
  # `X as $v | BODY`는 X가 빈 스트림이면 BODY를 한 번도 실행하지 않아 jq가 출력을 0개 낸다.
  # `.hooks.SessionStart // empty`가 바로 그 경우여서, 훅 이벤트가 한쪽만 있는
  # settings.json이 통째로 비워졌다. 빈 스트림을 만들지 않는 조건 분기로 바꾼다.
  if ! jq '
    def drop_entries($cmd): map(select(([.hooks[]?.command] | index($cmd)) | not));
    (if (.hooks.PostToolUse | type) == "array"
       then .hooks.PostToolUse |= drop_entries(".claude/hooks/post-edit-check.sh")
       else . end)
    | (if (.hooks.SessionStart | type) == "array"
       then .hooks.SessionStart |= drop_entries(".claude/hooks/session-start-resume.sh")
       else . end)
    | if ((.hooks.PostToolUse // null) == []) then del(.hooks.PostToolUse) else . end
    | if ((.hooks.SessionStart // null) == []) then del(.hooks.SessionStart) else . end
    | if ((.hooks // {}) == {}) then del(.hooks) else . end
  ' "$settings" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "Failed to compute new .claude/settings.json content." >&2
    _manual_hook_removal_instructions
    return 1
  fi
  # `jq .`는 0바이트 입력을 유효로 통과시키므로 크기를 먼저 본다.
  if [ ! -s "$tmp" ] || ! jq . "$tmp" &>/dev/null; then
    rm -f "$tmp"
    echo "Post-removal .claude/settings.json failed to re-parse as valid JSON." >&2
    _manual_hook_removal_instructions
    return 1
  fi
  # mv는 mktemp의 0600 모드까지 함께 옮겨 원본 퍼미션을 바꾼다 — 원본 파일에 덮어쓴다.
  cat "$tmp" > "$settings"
  rm -f "$tmp"
  return 0
}

# ── 백업 이동 + CLAUDE.md 정리 ──────────────────────────────────────────
do_migrate() {
  if ! detect_legacy; then
    print_nothing_to_migrate
    exit 0
  fi

  print_detected
  echo ""

  if ! remove_hook_entries; then
    exit 1
  fi

  local backup=".claude/.so-adk-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"

  local a s h
  if [ "${#FOUND_AGENTS[@]}" -gt 0 ]; then
    mkdir -p "$backup/agents"
    for a in "${FOUND_AGENTS[@]}"; do
      mv ".claude/agents/${a}.md" "$backup/agents/"
    done
  fi
  local dest
  for s in ${FOUND_INTERNAL_SKILLS[@]+"${FOUND_INTERNAL_SKILLS[@]}"} ${FOUND_GUARDED_SKILLS[@]+"${FOUND_GUARDED_SKILLS[@]}"}; do
    # 백업 안에서 원래 레이아웃을 그대로 재현한다 (skills/dev.md, skills/internal/so-*.md, skills/dev/)
    dest="$backup/${s#.claude/}"
    mkdir -p "$(dirname "$dest")"
    mv "$s" "$dest"
  done
  if [ "${#FOUND_HOOKS[@]}" -gt 0 ]; then
    mkdir -p "$backup/hooks"
    for h in "${FOUND_HOOKS[@]}"; do
      mv ".claude/hooks/${h}" "$backup/hooks/"
    done
  fi
  if [ "$FOUND_ORCH" -eq 1 ]; then
    mv "$LEGACY_ORCH" "$backup/so-orchestrator.md"
  fi

  rmdir ".claude/agents" 2>/dev/null || true
  rmdir ".claude/skills/internal" 2>/dev/null || true
  rmdir ".claude/skills" 2>/dev/null || true
  rmdir ".claude/hooks" 2>/dev/null || true

  if [ -f "CLAUDE.md" ]; then
    local tmp
    tmp="$(mktemp)"
    grep -vxF "$LEGACY_CLAUDE_MD_IMPORT" "CLAUDE.md" > "$tmp" 2>/dev/null || true
    # mv 대신 원본에 덮어써서 퍼미션을 보존한다(빈 파일이 되어도 삭제하지 않는다).
    cat "$tmp" > "CLAUDE.md"
    rm -f "$tmp"
  fi

  echo ""
  echo "✅ Migration complete."
  echo "   Backup: $backup/"
  print_install_guidance
}

# ── 인자 파싱 ────────────────────────────────────────────────────────────
case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --dry-run)
    if ! detect_legacy; then
      print_nothing_to_migrate
      exit 0
    fi
    print_detected
    echo ""
    print_dry_run_plan
    exit 0
    ;;
  --migrate)
    do_migrate
    exit $?
    ;;
  "")
    if detect_legacy; then
      print_detected
      echo ""
      echo "Run 'install.sh --dry-run' to preview the migration plan,"
      echo "or 'install.sh --migrate' to perform it (SO-ADK assets are backed up, not deleted)."
    else
      echo "No legacy SO-ADK assets detected."
    fi
    print_install_guidance
    exit 0
    ;;
  *)
    echo "Unknown flag: $1" >&2
    usage
    exit 1
    ;;
esac
