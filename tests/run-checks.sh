#!/usr/bin/env bash
# tests/run-checks.sh — SO-ADK self-verification smoke tests (bash only)
#
# Acceptance Coverage
# | AC ID                              | Test function                              | Status |
# | ---------------------------------- | ------------------------------------------ | ------ |
# | AC-R1 (훅 존재/실행권한)           | check_hook_exists_executable               | GREEN  |
# | AC-R1 (settings.json 유효 JSON)    | check_settings_json_valid                  | RED (기지)|
# | AC-R1 (빈 디렉토리 훅 스킵)        | check_hook_empty_dir                       | GREEN  |
# | AC-R1 (npm lint OK)                | check_hook_npm_lint_ok                     | GREEN  |
# | AC-R1 (npm lint fail → non-zero)   | check_hook_npm_lint_fail                   | GREEN  |
# | AC-R1 (python/ruff 없으면 스킵)    | check_hook_python_no_tools                 | GREEN  |
# | AC-R2 (Outside-In 섹션)            | check_tester_outside_in_mode               | GREEN  |
# | AC-R3 (so-designer install.sh)     | check_new_agents_in_install                | GREEN  |
# | AC-R3 (so-designer orchestrator)   | check_new_agents_in_orchestrator           | GREEN  |
# | AC-R4 (Step 3.5 / Complexity gate) | check_orchestrator_parallel_review         | GREEN  |
# | AC-R4 (Preview mode)               | check_architect_preview_mode               | GREEN  |
# | AC-R5 (frontmatter 필드)           | check_frontmatter                          | GREEN  |
#
# --- SPEC-002 신규 9종 ---
# | AC-R1a/R1b (architect Bash+제한지침)   | check_architect_bash_tool          | GREEN  |
# | AC-R1a/R3a (툴 부여 4건)               | check_tool_grants                  | GREEN  |
# | AC-R2a (reviewer Write)                | check_reviewer_write_tool          | GREEN  |
# | AC-R2b/R6d (영속화+대조+자가점검)      | check_reviewer_persistence         | GREEN  |
# | AC-R4a/R4b (so-spike 존재+계약)        | check_spike_agent                  | GREEN  |
# | AC-R4c (install.sh AGENTS)             | check_spike_in_install             | GREEN (plugins/ 이관 후 SKIP 전환) |
# | AC-R5a (미검증 가정 형식)              | check_unverified_assumption_format | GREEN  |
# | AC-R6a/R6b/R6c (Step 3.7 경로)         | check_orchestrator_spike_path      | GREEN  |
# | AC-R7b (하드코드 경로 부재)            | check_no_hardcoded_agent_paths     | GREEN  |
# | AC-R1c/R2c/R2d/R4d                     | 수동 스모크 — Smoke-Verified trailer| MANUAL |
# | AC-R3b (적정 10개 무변경)              | 수동 — merge-base diff 확인         | MANUAL |
# | AC-R7a (리졸버 전후 동일 GREEN)        | 커밋 1 전후 전체 실행 대조          | MANUAL |
# | AC-R7d (plugins 레이아웃 GREEN)        | SPEC-001 병합 후 스모크             | DEFER  |
#
# --- SPEC-001 플러그인 전환 (RED — plugins/ 레이아웃 미이관, so-tester 작성) ---
# 권위 있는 매핑표: specs/SPEC-001-plugin-migration.arch.md §6
# | AC ID                                  | Test function                          | Status |
# | --------------------------------------- | -------------------------------------- | ------ |
# | AC-R1b (agents 16 / skills 8)           | check_asset_counts                     | RED    |
# | AC-R2a (core plugin validate)           | check_plugin_validate_core             | RED    |
# | AC-R2b (hooks.json 스키마)              | check_hooks_json_valid                 | RED    |
# | AC-R2d (skills: 플레인 이름)            | check_frontmatter 계열 — 무수정(리졸버)| N/A    |
# | AC-R3a (orchestrator plugin validate)   | check_plugin_validate_orchestrator     | RED    |
# | AC-R3b (settings.json "agent" 키)       | check_orchestrator_settings_agent      | RED    |
# | AC-R3d (frontmatter name/desc, model·tools 부재) | check_orchestrator_frontmatter | RED    |
# | AC-R4a (marketplace.json)               | check_marketplace_json_valid           | RED    |
# | AC-R4b/c/d (settings.json 재정의 3종)   | check_settings_json_valid (재정의)     | RED (C4 이후 통과 예정 — 지금 통과시키지 않음) |
# | AC-R5a (구 스킬 호출명 0건, plugins/)   | check_skill_namespace                  | RED    |
# | AC-R6a/R6f (백업 이동 + 사용자 수정본 보존) | check_migrate_backup_preserves     | RED    |
# | AC-R6b (curl/append 부재 + 고정목록 + 대칭 마커 가드) | check_wrapper_static         | RED    |
# | AC-R6c (빈 디렉토리 무변경)             | check_migrate_empty_dir                | RED    |
# | AC-R6d (무플래그 무변경)                | check_migrate_no_flag_noop             | RED    |
# | AC-R6e (--dry-run 계획만 출력)          | check_migrate_dry_run                  | RED    |
# | AC-R6g (jq 부재 → 무이동 + exit 비0)    | check_migrate_no_jq_guard              | RED    |
# | AC-R6h (invalid JSON → 무이동 + exit 비0) | check_migrate_bad_settings_json      | RED    |
# | (정상 경로 훅 엔트리 정밀 제거)         | check_migrate_normal_path_hook_removal | RED    |
# | AC-R7b (순방향 파일-참조 일치성)        | check_orchestrator_agent_refs_exist    | RED    |
# | AC-R7c (역방향 고아 에이전트 부재)      | check_no_orphan_agents                 | RED    |
# | AC-R7d (구 검사명 소멸)                 | 본 파일에서 check_new_agents_in_install / check_install_dry_run_preserves / check_install_dry_run_empty / check_install_calls_merge_in_normal_path 제거 완료 | DONE |
# | AC-R2c/R3e/R11a/R11b/R11c/R12a/R12b/R8/R9/R10 | 수동 스모크 / trailer / README 검사 (run-checks.sh 비포함, C-9·R11-e 참조) | MANUAL |

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- 경로 리졸버 (SPEC-002 R7): SPEC-001 plugins/ 레이아웃 공존 ---
resolve_agents_dir() {
  if [ -d "$REPO_ROOT/plugins/so-adk-core/agents" ]; then
    echo "$REPO_ROOT/plugins/so-adk-core/agents"
  else
    echo "$REPO_ROOT/.claude/agents"
  fi
}
resolve_orchestrator_file() {
  if [ -f "$REPO_ROOT/plugins/so-adk-orchestrator/agents/so-orchestrator.md" ]; then
    echo "$REPO_ROOT/plugins/so-adk-orchestrator/agents/so-orchestrator.md"
  else
    echo "$REPO_ROOT/.claude/so-orchestrator.md"
  fi
}
# --- 신규 리졸버 (SPEC-001): 훅 스크립트 디렉터리. 이동 전에는 레거시 경로로 폴백해
# 기존 훅 검사 5종(#5, #9~12)이 git mv 전에도 계속 GREEN을 유지하도록 한다.
resolve_hooks_dir() {
  if [ -d "$REPO_ROOT/plugins/so-adk-core/hooks" ]; then
    echo "$REPO_ROOT/plugins/so-adk-core/hooks"
  else
    echo "$REPO_ROOT/.claude/hooks"
  fi
}
AGENTS_DIR="$(resolve_agents_dir)"
ORCH_FILE="$(resolve_orchestrator_file)"
HOOKS_DIR="$(resolve_hooks_dir)"

PASS=0
FAIL=0
SKIP=0
FAILED_CHECKS=()

pass()  { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail()  { echo "[FAIL] $1" >&2; FAIL=$((FAIL+1)); FAILED_CHECKS+=("$1"); }
skip()  { echo "[SKIP] $1 ($2)"; SKIP=$((SKIP+1)); }

# require_phrase — $file에 $phrase가 없으면 표준 [FAIL] 메시지를 찍고 1을 반환한다.
# 여러 static check 함수가 "문구 목록을 순회하며 grep -qF"를 반복 구현하던 것을 통합한 헬퍼.
# $4(label)를 주면 "$name: $label missing phrase '...'" 형식(여러 파일을 순회하는 체크용),
# 생략하면 "$name: missing phrase '...'" 형식(단일 파일 체크용)으로 출력한다.
require_phrase() {
  local name="$1" file="$2" phrase="$3" label="${4:-}"
  if grep -qF "$phrase" "$file"; then
    return 0
  fi
  if [ -n "$label" ]; then
    echo "[FAIL] $name: $label missing phrase '$phrase'" >&2
  else
    echo "[FAIL] $name: missing phrase '$phrase'" >&2
  fi
  return 1
}

# trap으로 임시 디렉토리 정리
TMP_DIRS=()
cleanup() {
  for d in "${TMP_DIRS[@]:-}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

mk_tmp() {
  local d
  d="$(mktemp -d)"
  TMP_DIRS+=("$d")
  echo "$d"
}

# mk_legacy_fixture — SPEC-001 R6 마이그레이션 래퍼 테스트용 레거시 설치 재현 헬퍼.
# $1 디렉터리에 레거시 .claude/ 레이아웃(에이전트 16개 + 사용자 파일 + 스킬 + 훅 +
# 병합된 settings.json + CLAUDE.md import 라인)을 구성한다.
# 주의: 이 함수는 의도적으로 `.claude/agents`·`.claude/so-orchestrator.md` 리터럴을
# 포함한다(레거시 레이아웃 재현이 목적) — check_no_hardcoded_agent_paths의 예외 목록에
# 등재되어 있다(§6.4 자기 충돌 방어).
mk_legacy_fixture() {
  local dir="$1"
  mkdir -p "$dir/.claude/agents" "$dir/.claude/skills" "$dir/.claude/hooks"

  cat > "$dir/CLAUDE.md" <<'EOF'
# My Project

Some user-authored content that must survive migration.

@.claude/so-orchestrator.md
EOF

  echo "# so-orchestrator (legacy fixture)" > "$dir/.claude/so-orchestrator.md"

  local agents=(so-planner so-reviewer so-architect so-scaffold so-tester so-developer
                so-quality so-docs so-debugger so-explainer so-preflight so-security
                so-performance so-designer so-auditor so-spike)
  local a
  for a in "${agents[@]}"; do
    printf -- '---\nname: %s\n---\n\nso-foundation\n' "$a" > "$dir/.claude/agents/${a}.md"
  done
  # 사용자 소유 파일 — SO-ADK 마커가 없으므로 절대 이동/삭제되면 안 됨
  echo "# my custom agent (not SO-ADK owned)" > "$dir/.claude/agents/my-agent.md"

  local gskills=(dev plan pr refactor)
  local s
  for s in "${gskills[@]}"; do
    mkdir -p "$dir/.claude/skills/$s"
    echo "Claude normally triggers this automatically — fixture $s skill." > "$dir/.claude/skills/$s/SKILL.md"
  done
  local iskills=(so-foundation so-spec-format so-tdd-workflow so-context)
  for s in "${iskills[@]}"; do
    mkdir -p "$dir/.claude/skills/$s"
    echo "# $s (internal skill fixture)" > "$dir/.claude/skills/$s/SKILL.md"
  done

  printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/.claude/hooks/post-edit-check.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$dir/.claude/hooks/session-start-resume.sh"
  chmod +x "$dir/.claude/hooks/post-edit-check.sh" "$dir/.claude/hooks/session-start-resume.sh"

  cat > "$dir/.claude/settings.json" <<'EOF'
{
  "model": "opus",
  "env": { "FOO": "bar" },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start-resume.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit",
        "hooks": [ { "type": "command", "command": ".claude/hooks/post-edit-check.sh" } ] }
    ]
  }
}
EOF
}

# ---------------------------------------------------------------------------
# 정적 검증 (8개)
# ---------------------------------------------------------------------------

# check_frontmatter — agents 디렉터리 모든 파일이 ---로 시작하고
# name/description/tools/model 4개 필드 포함
check_frontmatter() {
  local name="check_frontmatter"
  local failed=0
  for f in "$AGENTS_DIR"/*.md; do
    [ -f "$f" ] || continue
    local fname
    fname="$(basename "$f")"

    # 첫 줄이 ---인지
    if ! head -1 "$f" | grep -q "^---$"; then
      echo "[FAIL] $name: $fname does not start with ---" >&2
      failed=1
    fi

    # 4개 필드 모두 존재하는지
    for field in name description tools model; do
      if ! grep -q "^${field}:" "$f"; then
        echo "[FAIL] $name: $fname missing frontmatter field '${field}'" >&2
        failed=1
      fi
    done
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_new_agents_in_orchestrator — orchestrator 파일에 so-designer, so-auditor 최소 1회 이상
check_new_agents_in_orchestrator() {
  local name="check_new_agents_in_orchestrator"
  local failed=0
  for agent in so-designer so-auditor; do
    if ! grep -q "$agent" "$ORCH_FILE"; then
      echo "[FAIL] $name: '$agent' not found in so-orchestrator.md" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_settings_json_valid — SPEC-001 R4 재정의판 (매핑 #4).
# 구현이 R4에 따라 .claude/settings.json에 extraKnownMarketplaces/enabledPlugins를
# 커밋하기 전까지는 파일 부재로 FAIL한다 — 통과 시점은 커밋 C4 이후(설계 §5).
# 지금 이 시점에는 통과시키지 않는다(오케스트레이터 지시 — 재정의 범위이되 조기 GREEN 금지).
check_settings_json_valid() {
  local name="check_settings_json_valid"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local settings="$REPO_ROOT/.claude/settings.json"
  if [ ! -f "$settings" ]; then
    fail "$name"
    echo "[FAIL] $name: .claude/settings.json not found (R4 — committed at C2, contract redefined at C4)" >&2
    return
  fi
  if ! jq . "$settings" &>/dev/null; then
    fail "$name"
    echo "[FAIL] $name: .claude/settings.json is not valid JSON" >&2
    return
  fi
  local failed=0
  # (a) extraKnownMarketplaces / enabledPlugins 존재·유효성
  if ! jq -e '.extraKnownMarketplaces["so-adk"]' "$settings" &>/dev/null; then
    echo "[FAIL] $name: .extraKnownMarketplaces[\"so-adk\"] missing" >&2
    failed=1
  fi
  if ! jq -e '.enabledPlugins["so-adk-core@so-adk"] == true' "$settings" &>/dev/null; then
    echo "[FAIL] $name: .enabledPlugins[\"so-adk-core@so-adk\"] != true" >&2
    failed=1
  fi
  if ! jq -e '.enabledPlugins["so-adk-orchestrator@so-adk"] == true' "$settings" &>/dev/null; then
    echo "[FAIL] $name: .enabledPlugins[\"so-adk-orchestrator@so-adk\"] != true" >&2
    failed=1
  fi
  # (b) AC-R4c — 최상위 키가 정확히 두 개뿐
  local keys
  keys="$(jq -r 'keys | sort | join(",")' "$settings" 2>/dev/null)"
  if [ "$keys" != "enabledPlugins,extraKnownMarketplaces" ]; then
    echo "[FAIL] $name: top-level keys='$keys' (expected exactly 'enabledPlugins,extraKnownMarketplaces' — AC-R4c)" >&2
    failed=1
  fi
  # (c) AC-R4d — source가 github 정규 스키마 (F13/F14: 잘못된 형태는 조용히 disabled)
  if ! jq -e '.extraKnownMarketplaces["so-adk"].source.source == "github" and (.extraKnownMarketplaces["so-adk"].source.repo == "sotthang/so-adk")' "$settings" &>/dev/null; then
    echo "[FAIL] $name: extraKnownMarketplaces[\"so-adk\"].source is not the github/sotthang/so-adk form (AC-R4d)" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_hook_exists_executable — 훅 스크립트 2개(post-edit-check.sh, session-start-resume.sh)
# 모두 존재 + -x 권한 (SPEC-001 매핑 #5: 경로는 HOOKS_DIR 리졸버, 검사 대상을 2개로 확장)
check_hook_exists_executable() {
  local name="check_hook_exists_executable"
  local failed=0
  local script
  for script in post-edit-check.sh session-start-resume.sh; do
    local hook="$HOOKS_DIR/$script"
    if [ ! -f "$hook" ]; then
      echo "[FAIL] $name: $hook not found" >&2
      failed=1
      continue
    fi
    if [ ! -x "$hook" ]; then
      echo "[FAIL] $name: $hook is not executable" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_tester_outside_in_mode — so-tester.md에 "Outside-In" 또는 "Acceptance → Unit" 또는 "역피라미드" 중 하나
check_tester_outside_in_mode() {
  local name="check_tester_outside_in_mode"
  local tester="$AGENTS_DIR/so-tester.md"
  if [ ! -f "$tester" ]; then
    fail "$name"
    echo "[FAIL] $name: so-tester.md not found" >&2
    return
  fi
  if grep -qE "Outside-In|Acceptance → Unit|역피라미드" "$tester"; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: so-tester.md missing Outside-In / Acceptance → Unit / 역피라미드" >&2
  fi
}

# check_architect_preview_mode — so-architect.md에 "Preview mode" 또는 동등 표현
check_architect_preview_mode() {
  local name="check_architect_preview_mode"
  local architect="$AGENTS_DIR/so-architect.md"
  if [ ! -f "$architect" ]; then
    fail "$name"
    echo "[FAIL] $name: so-architect.md not found" >&2
    return
  fi
  if grep -qi "preview mode\|Preview mode" "$architect"; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: so-architect.md missing 'Preview mode' section" >&2
  fi
}

# check_orchestrator_parallel_review — so-orchestrator.md에 "Step 3.5" 또는 "Complexity gate" 또는 "Parallel review"
check_orchestrator_parallel_review() {
  local name="check_orchestrator_parallel_review"
  local orch="$ORCH_FILE"
  if [ ! -f "$orch" ]; then
    fail "$name"
    echo "[FAIL] $name: so-orchestrator.md not found" >&2
    return
  fi
  if grep -qE "Step 3\.5|Complexity gate|Parallel review" "$orch"; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: so-orchestrator.md missing Step 3.5 / Complexity gate / Parallel review" >&2
  fi
}

# ---------------------------------------------------------------------------
# SPEC-002 신규 정적 검증 (9개)
# ---------------------------------------------------------------------------

# check_architect_bash_tool — so-architect.md tools:에 Bash + 본문에 Bash 제한 지침 4개 문구
# (AC-R1a, AC-R1b)
check_architect_bash_tool() {
  local name="check_architect_bash_tool"
  local architect="$AGENTS_DIR/so-architect.md"
  if [ ! -f "$architect" ]; then
    fail "$name"
    echo "[FAIL] $name: so-architect.md not found" >&2
    return
  fi
  local failed=0
  if ! grep -E "^tools:" "$architect" | grep -qw "Bash"; then
    echo "[FAIL] $name: tools: line missing Bash" >&2
    failed=1
  fi
  for phrase in "허용: 읽기/검증 목적" "금지: 저장소 파일 변경" "scratchpad" "스파이크를 요청"; do
    require_phrase "$name" "$architect" "$phrase" || failed=1
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_reviewer_write_tool — so-reviewer.md tools:에 Write (AC-R2a)
check_reviewer_write_tool() {
  local name="check_reviewer_write_tool"
  local reviewer="$AGENTS_DIR/so-reviewer.md"
  if [ ! -f "$reviewer" ]; then
    fail "$name"
    echo "[FAIL] $name: so-reviewer.md not found" >&2
    return
  fi
  if grep -E "^tools:" "$reviewer" | grep -qw "Write"; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: tools: line missing Write" >&2
  fi
}

# check_reviewer_persistence — so-reviewer.md 영속화·대조·자가점검 문구
# (AC-R2b, AC-R6d)
check_reviewer_persistence() {
  local name="check_reviewer_persistence"
  local reviewer="$AGENTS_DIR/so-reviewer.md"
  if [ ! -f "$reviewer" ]; then
    fail "$name"
    echo "[FAIL] $name: so-reviewer.md not found" >&2
    return
  fi
  local failed=0
  if ! grep -qF "review-v" "$reviewer"; then
    echo "[FAIL] $name: missing 'review-v' persistence rule" >&2
    failed=1
  fi
  if ! grep -qF "인라인으로 삽입하는 것을 금지" "$reviewer"; then
    echo "[FAIL] $name: missing inline-insertion prohibition phrase" >&2
    failed=1
  fi
  if ! grep -qF "이전 라운드 지적 추적" "$reviewer"; then
    echo "[FAIL] $name: missing '이전 라운드 지적 추적' section marker" >&2
    failed=1
  fi
  if ! grep -qF "새 정보 / 이전 누락" "$reviewer"; then
    echo "[FAIL] $name: missing self-check phrase '새 정보 / 이전 누락'" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_tool_grants — planner Edit, designer Edit, architect Edit, quality Write
# (AC-R1a, AC-R3a)
check_tool_grants() {
  local name="check_tool_grants"
  local failed=0
  local pair f tool path
  for pair in "so-planner.md:Edit" "so-designer.md:Edit" "so-architect.md:Edit" "so-quality.md:Write"; do
    f="${pair%%:*}"
    tool="${pair##*:}"
    path="$AGENTS_DIR/$f"
    if [ ! -f "$path" ]; then
      echo "[FAIL] $name: $f not found" >&2
      failed=1
      continue
    fi
    if ! grep -E "^tools:" "$path" | grep -qw "$tool"; then
      echo "[FAIL] $name: $f tools: line missing $tool" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_spike_agent — so-spike.md 존재 + maxTurns + 입출력/저장소불변 계약 문구
# (AC-R4a, AC-R4b)
check_spike_agent() {
  local name="check_spike_agent"
  local spike="$AGENTS_DIR/so-spike.md"
  if [ ! -f "$spike" ]; then
    fail "$name"
    echo "[FAIL] $name: so-spike.md not found" >&2
    return
  fi
  local failed=0
  if ! grep -qE "^maxTurns:" "$spike"; then
    echo "[FAIL] $name: missing maxTurns: frontmatter field" >&2
    failed=1
  fi
  for phrase in "git status --porcelain" "측정불능" "가정 ID" "거짓일 경우 무너지는 것" "기준선 대조"; do
    require_phrase "$name" "$spike" "$phrase" || failed=1
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_unverified_assumption_format — reviewer·architect 본문 "미검증 가정" 3열 형식
# (AC-R5a)
check_unverified_assumption_format() {
  local name="check_unverified_assumption_format"
  local failed=0
  for f in "$AGENTS_DIR/so-reviewer.md" "$AGENTS_DIR/so-architect.md"; do
    if [ ! -f "$f" ]; then
      echo "[FAIL] $name: $(basename "$f") not found" >&2
      failed=1
      continue
    fi
    for phrase in "미검증 가정" "거짓일 경우 무너지는 것" "제안 측정 방법" "스파이크를 요청"; do
      require_phrase "$name" "$f" "$phrase" "$(basename "$f")" || failed=1
    done
  done
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_orchestrator_spike_path — Step 3.7 + so-spike 라우팅 + 상한 + 사실 불변 원칙
# (AC-R6a, AC-R6b, AC-R6c)
check_orchestrator_spike_path() {
  local name="check_orchestrator_spike_path"
  local orch="$ORCH_FILE"
  if [ ! -f "$orch" ]; then
    fail "$name"
    echo "[FAIL] $name: orchestrator file not found" >&2
    return
  fi
  local failed=0
  if ! grep -qE "Step 3\.7" "$orch"; then
    echo "[FAIL] $name: missing 'Step 3.7'" >&2
    failed=1
  fi
  if ! grep -qF "so-spike" "$orch"; then
    echo "[FAIL] $name: missing 'so-spike'" >&2
    failed=1
  fi
  if ! grep -qF "최대 2회" "$orch"; then
    echo "[FAIL] $name: missing '최대 2회' cap phrase" >&2
    failed=1
  fi
  if ! grep -qF "사실 불변" "$orch"; then
    echo "[FAIL] $name: missing '사실 불변' principle phrase" >&2
    failed=1
  fi
  if ! grep -qF "재설계를 강제" "$orch"; then
    echo "[FAIL] $name: missing '재설계를 강제' phrase" >&2
    failed=1
  fi
  if ! grep -qF "writes scratchpad only" "$orch"; then
    echo "[FAIL] $name: missing Agent Context Passing row 'writes scratchpad only'" >&2
    failed=1
  fi
  if ! grep -qE "\[3\.7\]" "$orch"; then
    echo "[FAIL] $name: missing pipeline diagram row '[3.7]'" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then
    pass "$name"
  else
    fail "$name"
  fi
}

# check_spike_in_install — install.sh AGENTS 배열에 so-spike (plugins/ 레이아웃이면 스킵)
# (AC-R4c)
check_spike_in_install() {
  local name="check_spike_in_install"
  if [ -d "$REPO_ROOT/plugins/so-adk-core/agents" ]; then
    skip "$name" "plugins/ layout — install.sh AGENTS array not applicable"
    return
  fi
  if grep -q "so-spike" "$REPO_ROOT/install.sh"; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: 'so-spike' not found in install.sh" >&2
  fi
}

# check_no_hardcoded_agent_paths — 리졸버·자기 자신·마이그레이션 픽스처 헬퍼 밖에서
# agents/orchestrator 하드코드 경로 부재 (AC-R7b, N-7 판정으로 상설 체크 격상)
# SPEC-001 갱신(매핑 #24): 다음 3개를 예외 목록에 추가한다(§6.4) — 탐지 정규식 자체
# (`\.claude/(agents|so-orchestrator\.md)`)는 실측 검증된 패턴이므로 변경하지 않는다.
#   - mk_legacy_fixture: 레거시 레이아웃을 의도적으로 재현하는 테스트 픽스처 헬퍼
#   - check_wrapper_static: install.sh 본문에서 "구 curl 다운로드 패턴이 사라졌는지"를
#     검사하기 위해 그 리터럴 패턴 자체를 grep 인자로 담고 있음 (탐지 대상이지 버그 아님)
#   - check_migrate_backup_preserves: 위 픽스처를 사용해 마이그레이션 결과를 검증하는 테스트
check_no_hardcoded_agent_paths() {
  local name="check_no_hardcoded_agent_paths"
  if awk '
    /^(resolve_agents_dir|resolve_orchestrator_file|check_no_hardcoded_agent_paths|mk_legacy_fixture|check_wrapper_static|check_migrate_backup_preserves)\(\)/ {skip=1}
    skip==1 && /^}/ {skip=0; next}
    skip!=1 {print}
  ' "$REPO_ROOT/tests/run-checks.sh" \
    | grep -vE '^[[:space:]]*#' \
    | grep -qE '\.claude/(agents|so-orchestrator\.md)'; then
    fail "$name"
    echo "[FAIL] $name: hardcoded agents/orchestrator path outside resolver functions" >&2
  else
    pass "$name"
  fi
}

# ---------------------------------------------------------------------------
# 동적 검증 (5개) — 훅 실제 실행 (SPEC-001: HOOKS_DIR 리졸버 사용, 매핑 #9~12)
# ---------------------------------------------------------------------------

# check_hook_empty_dir — 빈 디렉토리에서 훅 실행 → exit 0
check_hook_empty_dir() {
  local name="check_hook_empty_dir"
  local hook="$HOOKS_DIR/post-edit-check.sh"
  if [ ! -x "$hook" ]; then
    skip "$name" "hook not executable"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"

  local out
  out="$(cd "$tmpdir" && bash "$hook" < /dev/null 2>&1)"
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    fail "$name"
    echo "[FAIL] $name: hook exited $rc in empty dir (expected 0)" >&2
    return
  fi
  # lint 관련 출력이 없어야 함 (lint/typecheck/ruff/mypy/go vet/cargo 언급 없어야)
  if echo "$out" | grep -qiE "lint|typecheck|ruff|mypy|go vet|cargo check"; then
    fail "$name"
    echo "[FAIL] $name: hook produced lint-related output in empty dir" >&2
    return
  fi
  pass "$name"
}

# check_hook_npm_lint_ok — package.json lint=echo OK → stdout에 "OK" 포함, exit 0
check_hook_npm_lint_ok() {
  local name="check_hook_npm_lint_ok"
  local hook="$HOOKS_DIR/post-edit-check.sh"
  if [ ! -x "$hook" ]; then
    skip "$name" "hook not executable"
    return
  fi
  if ! command -v node &>/dev/null; then
    skip "$name" "node not in PATH"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"
  cat > "$tmpdir/package.json" <<'EOF'
{
  "name": "test-pkg",
  "scripts": {
    "lint": "echo OK"
  }
}
EOF

  local out
  out="$(cd "$tmpdir" && bash "$hook" < /dev/null 2>&1)"
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    fail "$name"
    echo "[FAIL] $name: hook exited $rc (expected 0). output: $out" >&2
    return
  fi
  if ! echo "$out" | grep -q "OK"; then
    fail "$name"
    echo "[FAIL] $name: stdout did not contain 'OK'. output: $out" >&2
    return
  fi
  pass "$name"
}

# check_hook_npm_lint_fail — package.json lint=exit 1 → non-zero exit
check_hook_npm_lint_fail() {
  local name="check_hook_npm_lint_fail"
  local hook="$HOOKS_DIR/post-edit-check.sh"
  if [ ! -x "$hook" ]; then
    skip "$name" "hook not executable"
    return
  fi
  if ! command -v node &>/dev/null; then
    skip "$name" "node not in PATH"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"
  cat > "$tmpdir/package.json" <<'EOF'
{
  "name": "test-pkg",
  "scripts": {
    "lint": "exit 1"
  }
}
EOF

  ( cd "$tmpdir" && bash "$hook" < /dev/null &>/dev/null )
  local rc=$?

  if [ "$rc" -eq 0 ]; then
    fail "$name"
    echo "[FAIL] $name: hook exited 0 (expected non-zero) when lint=exit 1" >&2
    return
  fi
  pass "$name"
}

# check_hook_python_no_tools — pyproject.toml만 있고 ruff/mypy가 PATH에 없으면 exit 0 (스킵)
# ruff 또는 mypy가 실제로 PATH에 있으면 이 테스트를 SKIP 처리
check_hook_python_no_tools() {
  local name="check_hook_python_no_tools"
  local hook="$HOOKS_DIR/post-edit-check.sh"
  if [ ! -x "$hook" ]; then
    skip "$name" "hook not executable"
    return
  fi
  if command -v ruff &>/dev/null || command -v mypy &>/dev/null; then
    skip "$name" "ruff or mypy found in PATH — cannot test no-tool skip path"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"
  touch "$tmpdir/pyproject.toml"

  ( cd "$tmpdir" && bash "$hook" < /dev/null &>/dev/null )
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    fail "$name"
    echo "[FAIL] $name: hook exited $rc (expected 0) with pyproject.toml but no ruff/mypy" >&2
    return
  fi
  pass "$name"
}

# ---------------------------------------------------------------------------
# SPEC-001 신규 정적 검증 — 플러그인 매니페스트·프론트매터·파일-참조 일치성
# 권위 있는 근거: specs/SPEC-001-plugin-migration.arch.md §6.3
# ---------------------------------------------------------------------------

# check_asset_counts — agents 16개 / skills 8개 (AC-R1b)
check_asset_counts() {
  local name="check_asset_counts"
  local adir="$REPO_ROOT/plugins/so-adk-core/agents"
  local sdir="$REPO_ROOT/plugins/so-adk-core/skills"
  if [ ! -d "$adir" ] || [ ! -d "$sdir" ]; then
    fail "$name"
    echo "[FAIL] $name: plugins/so-adk-core/{agents,skills} not found (pre-migration)" >&2
    return
  fi
  local acount scount
  acount="$(find "$adir" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')"
  scount="$(find "$sdir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -type f | wc -l | tr -d ' ')"
  local failed=0
  [ "$acount" = "16" ] || { echo "[FAIL] $name: agents count=$acount (expected 16)" >&2; failed=1; }
  [ "$scount" = "8" ]  || { echo "[FAIL] $name: skills count=$scount (expected 8)" >&2; failed=1; }
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_plugin_validate_core — claude plugin validate ./plugins/so-adk-core --strict (AC-R2a)
check_plugin_validate_core() {
  local name="check_plugin_validate_core"
  if ! command -v claude &>/dev/null; then
    skip "$name" "claude CLI not in PATH"
    return
  fi
  if [ ! -d "$REPO_ROOT/plugins/so-adk-core" ]; then
    fail "$name"
    echo "[FAIL] $name: plugins/so-adk-core not found (pre-migration)" >&2
    return
  fi
  if claude plugin validate "$REPO_ROOT/plugins/so-adk-core" --strict &>/dev/null; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: claude plugin validate --strict failed for so-adk-core" >&2
  fi
}

# check_plugin_validate_orchestrator — claude plugin validate ./plugins/so-adk-orchestrator --strict (AC-R3a)
check_plugin_validate_orchestrator() {
  local name="check_plugin_validate_orchestrator"
  if ! command -v claude &>/dev/null; then
    skip "$name" "claude CLI not in PATH"
    return
  fi
  if [ ! -d "$REPO_ROOT/plugins/so-adk-orchestrator" ]; then
    fail "$name"
    echo "[FAIL] $name: plugins/so-adk-orchestrator not found (pre-migration)" >&2
    return
  fi
  if claude plugin validate "$REPO_ROOT/plugins/so-adk-orchestrator" --strict &>/dev/null; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: claude plugin validate --strict failed for so-adk-orchestrator" >&2
  fi
}

# check_plugin_validate_marketplace — claude plugin validate <repo root> --strict (마켓플레이스 루트, R7)
check_plugin_validate_marketplace() {
  local name="check_plugin_validate_marketplace"
  if ! command -v claude &>/dev/null; then
    skip "$name" "claude CLI not in PATH"
    return
  fi
  if [ ! -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]; then
    fail "$name"
    echo "[FAIL] $name: .claude-plugin/marketplace.json not found (pre-migration)" >&2
    return
  fi
  if claude plugin validate "$REPO_ROOT" --strict &>/dev/null; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: claude plugin validate --strict failed for marketplace root" >&2
  fi
}

# check_hooks_json_valid — hooks.json 유효 JSON + 이벤트/매처 + ${CLAUDE_PLUGIN_ROOT} + 스크립트 존재·실행가능 (AC-R2b)
check_hooks_json_valid() {
  local name="check_hooks_json_valid"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local hooks_json="$REPO_ROOT/plugins/so-adk-core/hooks/hooks.json"
  if [ ! -f "$hooks_json" ]; then
    fail "$name"
    echo "[FAIL] $name: $hooks_json not found (pre-migration)" >&2
    return
  fi
  local failed=0
  if ! jq . "$hooks_json" &>/dev/null; then
    echo "[FAIL] $name: hooks.json is not valid JSON" >&2
    failed=1
  fi
  if ! jq -e '.hooks.SessionStart' "$hooks_json" &>/dev/null; then
    echo "[FAIL] $name: missing .hooks.SessionStart" >&2
    failed=1
  fi
  if ! jq -e '.hooks.PostToolUse[]? | select(.matcher=="Edit|Write|MultiEdit")' "$hooks_json" &>/dev/null; then
    echo "[FAIL] $name: missing PostToolUse matcher 'Edit|Write|MultiEdit'" >&2
    failed=1
  fi
  local non_plugin_root
  non_plugin_root="$(jq -r '[.hooks | to_entries[]?.value[]?.hooks[]?.command] | map(select(startswith("${CLAUDE_PLUGIN_ROOT}") | not)) | length' "$hooks_json" 2>/dev/null)"
  if [ "${non_plugin_root:-1}" != "0" ]; then
    echo "[FAIL] $name: not every hook command starts with \${CLAUDE_PLUGIN_ROOT}" >&2
    failed=1
  fi
  local script
  for script in post-edit-check.sh session-start-resume.sh; do
    local sp="$REPO_ROOT/plugins/so-adk-core/hooks/$script"
    if [ ! -x "$sp" ]; then
      echo "[FAIL] $name: referenced script $script missing or not executable at $sp" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_orchestrator_settings_agent — orchestrator settings.json의 "agent" 키 (AC-R3b)
check_orchestrator_settings_agent() {
  local name="check_orchestrator_settings_agent"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local f="$REPO_ROOT/plugins/so-adk-orchestrator/settings.json"
  if [ ! -f "$f" ]; then
    fail "$name"
    echo "[FAIL] $name: $f not found (pre-migration)" >&2
    return
  fi
  local agent
  agent="$(jq -r '.agent' "$f" 2>/dev/null)"
  if [ "$agent" = "so-orchestrator" ]; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: .agent='$agent' (expected 'so-orchestrator')" >&2
  fi
}

# check_orchestrator_frontmatter — name/description 존재 + model/tools 부재 (AC-R3d, §4)
check_orchestrator_frontmatter() {
  local name="check_orchestrator_frontmatter"
  local f="$ORCH_FILE"
  if [ ! -f "$f" ]; then
    fail "$name"
    echo "[FAIL] $name: orchestrator file not found" >&2
    return
  fi
  local fm failed=0
  fm="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f")"
  if ! head -1 "$f" | grep -q '^---$'; then
    echo "[FAIL] $name: first line is not '---' (no frontmatter block)" >&2
    failed=1
  fi
  if ! grep -q '^name: so-orchestrator$' <<<"$fm"; then
    echo "[FAIL] $name: frontmatter missing 'name: so-orchestrator'" >&2
    failed=1
  fi
  if ! grep -q '^description:' <<<"$fm"; then
    echo "[FAIL] $name: frontmatter missing 'description:'" >&2
    failed=1
  fi
  if grep -q '^model:' <<<"$fm"; then
    echo "[FAIL] $name: frontmatter must NOT contain 'model:' (F10)" >&2
    failed=1
  fi
  if grep -q '^tools:' <<<"$fm"; then
    echo "[FAIL] $name: frontmatter must NOT contain 'tools:' (R3)" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_marketplace_json_valid — repo 루트 marketplace.json 유효 JSON + 두 플러그인 엔트리 (AC-R4a)
check_marketplace_json_valid() {
  local name="check_marketplace_json_valid"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local f="$REPO_ROOT/.claude-plugin/marketplace.json"
  if [ ! -f "$f" ]; then
    fail "$name"
    echo "[FAIL] $name: $f not found (pre-migration)" >&2
    return
  fi
  local failed=0
  if ! jq . "$f" &>/dev/null; then
    echo "[FAIL] $name: marketplace.json is not valid JSON" >&2
    failed=1
  fi
  if ! jq -e '.plugins[]? | select(.name=="so-adk-core" and (.source|startswith("./plugins/")))' "$f" &>/dev/null; then
    echo "[FAIL] $name: missing so-adk-core entry with ./plugins/ source" >&2
    failed=1
  fi
  if ! jq -e '.plugins[]? | select(.name=="so-adk-orchestrator" and (.source|startswith("./plugins/")))' "$f" &>/dev/null; then
    echo "[FAIL] $name: missing so-adk-orchestrator entry with ./plugins/ source" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_skill_namespace — 구 스킬 호출명 0건, plugins/ 하위 한정 (AC-R5a, M-1 보정 패턴 그대로 사용)
check_skill_namespace() {
  local name="check_skill_namespace"
  if [ ! -d "$REPO_ROOT/plugins" ]; then
    fail "$name"
    echo "[FAIL] $name: plugins/ not found (pre-migration)" >&2
    return
  fi
  local failed=0
  # 패턴 (1) 슬래시형 — M-1 보정: 제외 문자군에 '/'를 포함해 /dev/null류 오탐 배제
  if grep -rlE '(^|[^:a-z/])/(dev|plan|pr|refactor)([^a-z:/]|$)' "$REPO_ROOT/plugins" &>/dev/null; then
    echo "[FAIL] $name: legacy slash-form skill call found under plugins/" >&2
    grep -rnE '(^|[^:a-z/])/(dev|plan|pr|refactor)([^a-z:/]|$)' "$REPO_ROOT/plugins" >&2
    failed=1
  fi
  # 패턴 (2) 무슬래시 스킬 언급형 — 백틱형/무백틱형 모두 포착, 네임스페이스형은 콜론 선행으로 제외
  if grep -rlE '(^|[^:[:alnum:]_-])`?(dev|plan|pr|refactor)`? skill' "$REPO_ROOT/plugins" &>/dev/null; then
    echo "[FAIL] $name: legacy bare skill-mention form found under plugins/" >&2
    grep -rnE '(^|[^:[:alnum:]_-])`?(dev|plan|pr|refactor)`? skill' "$REPO_ROOT/plugins" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_orchestrator_agent_refs_exist — 순방향: 오케스트레이터 본문의 so-* 참조 전수가
# plugins/so-adk-core/agents/에 실파일로 존재 (AC-R7b). 두 플러그인을 잇는 유일한 기계적 계약.
check_orchestrator_agent_refs_exist() {
  local name="check_orchestrator_agent_refs_exist"
  local core_agents_dir="$REPO_ROOT/plugins/so-adk-core/agents"
  if [ ! -d "$core_agents_dir" ]; then
    fail "$name"
    echo "[FAIL] $name: $core_agents_dir not found (pre-migration — plugins/ layout not yet created)" >&2
    return
  fi
  local orch="$ORCH_FILE"
  local denylist_regex='^(so-adk|so-adk-core|so-adk-orchestrator|so-orchestrator)$'
  local skill sname
  for skill in "$REPO_ROOT"/plugins/so-adk-core/skills/*/ "$REPO_ROOT"/.claude/skills/*/; do
    [ -d "$skill" ] || continue
    sname="$(basename "$skill")"
    denylist_regex="${denylist_regex}|^${sname}$"
  done
  local failed=0 ref
  for ref in $(grep -oE '\bso-[a-z][a-z-]*' "$orch" | sort -u); do
    echo "$ref" | grep -qE "$denylist_regex" && continue
    if [ ! -f "$core_agents_dir/${ref}.md" ]; then
      echo "[FAIL] $name: orchestrator references '$ref' but $core_agents_dir/${ref}.md does not exist" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_no_orphan_agents — 역방향: plugins/so-adk-core/agents/의 에이전트 중 오케스트레이터
# 본문에서 참조되지 않는 고아 에이전트 탐지 (AC-R7c)
check_no_orphan_agents() {
  local name="check_no_orphan_agents"
  local core_agents_dir="$REPO_ROOT/plugins/so-adk-core/agents"
  if [ ! -d "$core_agents_dir" ]; then
    fail "$name"
    echo "[FAIL] $name: $core_agents_dir not found (pre-migration — plugins/ layout not yet created)" >&2
    return
  fi
  local orch="$ORCH_FILE"
  local failed=0 f agent
  for f in "$core_agents_dir"/*.md; do
    [ -f "$f" ] || continue
    agent="$(basename "$f" .md)"
    if ! grep -qF -- "$agent" "$orch"; then
      echo "[FAIL] $name: '$agent' exists in $core_agents_dir but is never referenced in orchestrator body" >&2
      failed=1
    fi
  done
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# ---------------------------------------------------------------------------
# SPEC-001 신규 동적 검증 — install.sh 마이그레이션 래퍼 (R6)
# 안전 가드: install.sh가 아직 --migrate 플래그를 구현하지 않았으므로(RED), 실제 실행 전에
# 항상 정적으로 플래그 지원 여부를 먼저 grep한다 — 그렇지 않으면 현행 install.sh가
# 플래그를 인식하지 못해 레거시 curl 전체 설치 경로로 빠져 실제 네트워크 다운로드가
# 발생한다(임시 디렉터리에서라도 바람직하지 않음). 구현 후에는 이 가드를 자연히 통과하고
# 아래의 실제 동작 검증이 수행된다.
# ---------------------------------------------------------------------------

_migrate_wrapper_ready() {
  grep -qE -- '--migrate' "$REPO_ROOT/install.sh"
}

# check_wrapper_static — curl 다운로드/CLAUDE.md append 부재 + 고정 목록 + 대칭 마커 가드 (AC-R6b)
check_wrapper_static() {
  local name="check_wrapper_static"
  local f="$REPO_ROOT/install.sh"
  local failed=0
  if grep -qE 'curl .*\.claude/agents/\$\{?agent' "$f" 2>/dev/null; then
    echo "[FAIL] $name: install.sh still curl-downloads agent files" >&2
    failed=1
  fi
  if grep -qE 'curl .*\.claude/skills/\$\{?skill' "$f" 2>/dev/null; then
    echo "[FAIL] $name: install.sh still curl-downloads skill files" >&2
    failed=1
  fi
  if grep -qF 'appended import line' "$f" || grep -qF '>> "./CLAUDE.md"' "$f"; then
    echo "[FAIL] $name: install.sh still appends to CLAUDE.md" >&2
    failed=1
  fi
  require_phrase "$name" "$f" "LEGACY_AGENTS" || failed=1
  require_phrase "$name" "$f" "so-foundation" "agent marker guard (symmetric with skills)" || failed=1
  require_phrase "$name" "$f" "Claude normally triggers this automatically" "skill marker guard" || failed=1
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_migrate_empty_dir — 레거시 미감지 빈 디렉토리에서 --migrate → 무변경 + 안내만 (AC-R6c)
check_migrate_empty_dir() {
  local name="check_migrate_empty_dir"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  local dir; dir="$(mk_tmp)"
  local before after
  before="$(cd "$dir" && find . | sort)"
  ( cd "$dir" && bash "$REPO_ROOT/install.sh" --migrate ) &>/dev/null
  after="$(cd "$dir" && find . | sort)"
  if [ "$before" = "$after" ]; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: --migrate on legacy-free empty dir created/modified files (expected no-op)" >&2
  fi
}

# check_migrate_no_flag_noop — 플래그 없이 실행 시 진단만, 무변경 (AC-R6d)
check_migrate_no_flag_noop() {
  local name="check_migrate_no_flag_noop"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet (bare invocation still runs legacy curl-based installer)" >&2
    return
  fi
  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"
  local before after
  before="$(cd "$dir" && find . -type f | sort)"
  ( cd "$dir" && bash "$REPO_ROOT/install.sh" ) &>/dev/null
  after="$(cd "$dir" && find . -type f | sort)"
  if [ "$before" = "$after" ]; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: bare invocation modified files (expected diagnosis-only, opt-in required)" >&2
  fi
}

# check_migrate_dry_run — 계획만 출력, 무변경 (AC-R6e)
check_migrate_dry_run() {
  local name="check_migrate_dry_run"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"
  local before after out failed=0
  before="$(cd "$dir" && find . -type f | sort)"
  out="$(cd "$dir" && bash "$REPO_ROOT/install.sh" --dry-run 2>&1)"
  after="$(cd "$dir" && find . -type f | sort)"
  if [ "$before" != "$after" ]; then
    echo "[FAIL] $name: --dry-run modified files (expected plan output only)" >&2
    failed=1
  fi
  if ! echo "$out" | grep -qi "backup\|so-adk-backup"; then
    echo "[FAIL] $name: --dry-run output does not mention planned backup path" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_migrate_backup_preserves — SO-ADK 소유 파일은 백업 이동(삭제 아님), 사용자 파일/수정본 보존,
# CLAUDE.md는 import 라인만 제거되고 삭제되지 않음 (AC-R6a, AC-R6f)
check_migrate_backup_preserves() {
  local name="check_migrate_backup_preserves"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"
  # 사용자가 본문을 수정한 SO-ADK 에이전트 (AC-R6f)
  printf -- '---\nname: so-planner\n---\n\nso-foundation\nCUSTOM USER EDIT\n' > "$dir/.claude/agents/so-planner.md"

  ( cd "$dir" && bash "$REPO_ROOT/install.sh" --migrate ) &>/dev/null

  local failed=0
  local backup
  backup="$(find "$dir/.claude" -maxdepth 1 -type d -name '.so-adk-backup-*' 2>/dev/null | head -1)"
  if [ -z "$backup" ]; then
    echo "[FAIL] $name: no .claude/.so-adk-backup-<timestamp>/ dir created" >&2
    failed=1
  else
    if ! find "$backup" -name 'so-planner.md' -exec grep -l 'CUSTOM USER EDIT' {} \; 2>/dev/null | grep -q .; then
      echo "[FAIL] $name: user-modified so-planner.md content not found preserved in backup" >&2
      failed=1
    fi
  fi
  [ -f "$dir/.claude/agents/my-agent.md" ] || { echo "[FAIL] $name: my-agent.md removed (must be preserved — not SO-ADK owned)" >&2; failed=1; }
  [ -f "$dir/CLAUDE.md" ] || { echo "[FAIL] $name: CLAUDE.md deleted (must never delete, even if emptied)" >&2; failed=1; }
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_migrate_normal_path_hook_removal — 정상 경로: settings.json 훅 엔트리만 정밀 제거,
# 다른 최상위 키 보존 (매핑 #14 정상 경로 절반)
check_migrate_normal_path_hook_removal() {
  local name="check_migrate_normal_path_hook_removal"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"
  ( cd "$dir" && bash "$REPO_ROOT/install.sh" --migrate ) &>/dev/null

  local settings="$dir/.claude/settings.json"
  local failed=0
  if [ -f "$settings" ]; then
    if jq -e '.hooks.PostToolUse' "$settings" &>/dev/null; then
      echo "[FAIL] $name: PostToolUse hook entry not removed from settings.json" >&2
      failed=1
    fi
    if jq -e '.hooks.SessionStart' "$settings" &>/dev/null; then
      echo "[FAIL] $name: SessionStart hook entry not removed from settings.json" >&2
      failed=1
    fi
    if [ "$(jq -r '.model' "$settings" 2>/dev/null)" != "opus" ]; then
      echo "[FAIL] $name: unrelated key .model not preserved" >&2
      failed=1
    fi
  else
    echo "[FAIL] $name: settings.json missing after --migrate" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_migrate_no_jq_guard — jq 부재 시 훅 엔트리 제거 실패 → 훅 스크립트 미이동 + exit 비0 (AC-R6g)
check_migrate_no_jq_guard() {
  local name="check_migrate_no_jq_guard"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH originally — cannot construct no-jq guard test"
    return
  fi

  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"

  # jq가 있는 디렉터리만 PATH에서 제외하되, 같은 디렉터리의 다른 필수 도구는
  # 심볼릭 링크로 별도 fakebin에 살려서 PATH 손상을 방지한다.
  local jq_path jq_dir fakebin
  jq_path="$(command -v jq)"
  jq_dir="$(dirname "$jq_path")"
  fakebin="$(mk_tmp)"
  local f bn
  for f in "$jq_dir"/*; do
    [ -e "$f" ] || continue
    bn="$(basename "$f")"
    [ "$bn" = "jq" ] && continue
    ln -sf "$f" "$fakebin/$bn" 2>/dev/null
  done

  local newpath="$fakebin" p
  IFS=':' read -ra _parts <<< "$PATH"
  for p in "${_parts[@]}"; do
    [ "$p" = "$jq_dir" ] && continue
    newpath="$newpath:$p"
  done

  local rc
  ( cd "$dir" && PATH="$newpath" bash "$REPO_ROOT/install.sh" --migrate ) &>/dev/null
  rc=$?

  local failed=0
  if [ "$rc" -eq 0 ]; then
    echo "[FAIL] $name: exit 0 (expected non-zero) when jq missing" >&2
    failed=1
  fi
  if [ ! -f "$dir/.claude/hooks/post-edit-check.sh" ]; then
    echo "[FAIL] $name: hook script moved despite failed jq-gated entry removal (orphan hook risk)" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# check_migrate_bad_settings_json — settings.json이 유효 JSON이 아니면 훅 미이동 + exit 비0 (AC-R6h)
check_migrate_bad_settings_json() {
  local name="check_migrate_bad_settings_json"
  if ! _migrate_wrapper_ready; then
    fail "$name"
    echo "[FAIL] $name: install.sh does not implement --migrate flag yet" >&2
    return
  fi
  local dir; dir="$(mk_tmp)"
  mk_legacy_fixture "$dir"
  echo '{ this is not valid json' > "$dir/.claude/settings.json"

  ( cd "$dir" && bash "$REPO_ROOT/install.sh" --migrate ) &>/dev/null
  local rc=$?

  local failed=0
  if [ "$rc" -eq 0 ]; then
    echo "[FAIL] $name: exit 0 (expected non-zero) when settings.json is invalid JSON" >&2
    failed=1
  fi
  if [ ! -f "$dir/.claude/hooks/post-edit-check.sh" ]; then
    echo "[FAIL] $name: hook script moved despite invalid settings.json (orphan hook risk)" >&2
    failed=1
  fi
  if [ "$failed" -eq 0 ]; then pass "$name"; else fail "$name"; fi
}

# ---------------------------------------------------------------------------
# 실행
# ---------------------------------------------------------------------------

# --- 기존 24개 (SPEC-002 병합분 포함) — 매핑표대로 무수정/갱신 ---
check_frontmatter
check_new_agents_in_orchestrator
check_settings_json_valid
check_hook_exists_executable
check_tester_outside_in_mode
check_architect_preview_mode
check_orchestrator_parallel_review
check_architect_bash_tool
check_reviewer_write_tool
check_reviewer_persistence
check_tool_grants
check_spike_agent
check_unverified_assumption_format
check_orchestrator_spike_path
check_spike_in_install
check_no_hardcoded_agent_paths
check_hook_empty_dir
check_hook_npm_lint_ok
check_hook_npm_lint_fail
check_hook_python_no_tools

# --- SPEC-001 신규 계약 검사 (RED — plugins/ 레이아웃·install.sh --migrate 구현 전) ---
check_asset_counts
check_plugin_validate_core
check_plugin_validate_orchestrator
check_plugin_validate_marketplace
check_hooks_json_valid
check_orchestrator_settings_agent
check_orchestrator_frontmatter
check_marketplace_json_valid
check_skill_namespace
check_orchestrator_agent_refs_exist
check_no_orphan_agents
check_wrapper_static
check_migrate_empty_dir
check_migrate_no_flag_noop
check_migrate_dry_run
check_migrate_backup_preserves
check_migrate_normal_path_hook_removal
check_migrate_no_jq_guard
check_migrate_bad_settings_json

echo ""
echo "Summary: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed checks:" >&2
  printf '  - %s\n' "${FAILED_CHECKS[@]}" >&2
  exit 1
fi
exit 0
