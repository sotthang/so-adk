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
# | AC-R1 (install --dry-run 보존)     | check_install_dry_run_preserves            | GREEN  |
# | AC-R1 (install --dry-run 빈 디렉)  | check_install_dry_run_empty                | GREEN  |
# | AC-R1 (정규 경로 merge 호출)       | check_install_calls_merge_in_normal_path   | GREEN  |
# | AC-R2 (Outside-In 섹션)            | check_tester_outside_in_mode               | GREEN  |
# | AC-R3 (so-designer install.sh)     | check_new_agents_in_install                | GREEN  |
# | AC-R3 (so-designer orchestrator)   | check_new_agents_in_orchestrator           | GREEN  |
# | AC-R4 (Step 3.5 / Complexity gate) | check_orchestrator_parallel_review         | GREEN  |
# | AC-R4 (Preview mode)               | check_architect_preview_mode               | GREEN  |
# | AC-R5 (frontmatter 필드)           | check_frontmatter                          | GREEN  |
#
# --- SPEC-002 신규 9종 (RED — 구현 전) ---
# | AC-R1a/R1b (architect Bash+제한지침)   | check_architect_bash_tool          | RED    |
# | AC-R1a/R3a (툴 부여 4건)               | check_tool_grants                  | RED    |
# | AC-R2a (reviewer Write)                | check_reviewer_write_tool          | RED    |
# | AC-R2b/R6d (영속화+대조+자가점검)      | check_reviewer_persistence         | RED    |
# | AC-R4a/R4b (so-spike 존재+계약)        | check_spike_agent                  | RED    |
# | AC-R4c (install.sh AGENTS)             | check_spike_in_install             | RED    |
# | AC-R5a (미검증 가정 형식)              | check_unverified_assumption_format | RED    |
# | AC-R6a/R6b/R6c (Step 3.7 경로)         | check_orchestrator_spike_path      | RED    |
# | AC-R7b (하드코드 경로 부재)            | check_no_hardcoded_agent_paths     | RED    |
# | AC-R1c/R2c/R2d/R4d                     | 수동 스모크 — Smoke-Verified trailer| MANUAL |
# | AC-R3b (적정 10개 무변경)              | 수동 — merge-base diff 확인         | MANUAL |
# | AC-R7a (리졸버 전후 동일 GREEN)        | 커밋 1 전후 전체 실행 대조          | MANUAL |
# | AC-R7d (plugins 레이아웃 GREEN)        | SPEC-001 병합 후 스모크             | DEFER  |

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
AGENTS_DIR="$(resolve_agents_dir)"
ORCH_FILE="$(resolve_orchestrator_file)"

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

# check_new_agents_in_install — install.sh에 so-designer, so-auditor 문자열 존재
check_new_agents_in_install() {
  local name="check_new_agents_in_install"
  local failed=0
  for agent in so-designer so-auditor; do
    if ! grep -q "$agent" "$REPO_ROOT/install.sh"; then
      echo "[FAIL] $name: '$agent' not found in install.sh" >&2
      failed=1
    fi
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

# check_settings_json_valid — jq . .claude/settings.json이 exit 0
check_settings_json_valid() {
  local name="check_settings_json_valid"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi
  local settings="$REPO_ROOT/.claude/settings.json"
  if [ ! -f "$settings" ]; then
    fail "$name"
    echo "[FAIL] $name: .claude/settings.json not found" >&2
    return
  fi
  if ! jq . "$settings" &>/dev/null; then
    fail "$name"
    echo "[FAIL] $name: .claude/settings.json is not valid JSON" >&2
    return
  fi
  # PostToolUse 훅이 포함되어 있는지
  if ! jq -e '.hooks.PostToolUse' "$settings" &>/dev/null; then
    fail "$name"
    echo "[FAIL] $name: .claude/settings.json missing .hooks.PostToolUse" >&2
    return
  fi
  pass "$name"
}

# check_hook_exists_executable — .claude/hooks/post-edit-check.sh 존재 + -x 권한
check_hook_exists_executable() {
  local name="check_hook_exists_executable"
  local hook="$REPO_ROOT/.claude/hooks/post-edit-check.sh"
  if [ ! -f "$hook" ]; then
    fail "$name"
    echo "[FAIL] $name: $hook not found" >&2
    return
  fi
  if [ ! -x "$hook" ]; then
    fail "$name"
    echo "[FAIL] $name: $hook is not executable" >&2
    return
  fi
  pass "$name"
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

# check_no_hardcoded_agent_paths — 리졸버·자기 자신 밖에서 agents/orchestrator 하드코드 경로 부재
# (AC-R7b, N-7 판정으로 상설 체크 격상)
check_no_hardcoded_agent_paths() {
  local name="check_no_hardcoded_agent_paths"
  if awk '
    /^(resolve_agents_dir|resolve_orchestrator_file|check_no_hardcoded_agent_paths)\(\)/ {skip=1}
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
# 동적 검증 (6개) — 훅 실제 실행
# ---------------------------------------------------------------------------

# check_hook_empty_dir — 빈 디렉토리에서 훅 실행 → exit 0
check_hook_empty_dir() {
  local name="check_hook_empty_dir"
  local hook="$REPO_ROOT/.claude/hooks/post-edit-check.sh"
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
  local hook="$REPO_ROOT/.claude/hooks/post-edit-check.sh"
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
  local hook="$REPO_ROOT/.claude/hooks/post-edit-check.sh"
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
  local hook="$REPO_ROOT/.claude/hooks/post-edit-check.sh"
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

# check_install_dry_run_preserves — 기존 settings.json이 있는 tmpdir에서 --dry-run-merge 호출
# 결과 JSON에서 model이 "opus", env.FOO가 "bar", hooks.PostToolUse가 존재해야 함
check_install_dry_run_preserves() {
  local name="check_install_dry_run_preserves"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"
  mkdir -p "$tmpdir/.claude"
  cat > "$tmpdir/.claude/settings.json" <<'EOF'
{"model":"opus","env":{"FOO":"bar"}}
EOF

  bash "$REPO_ROOT/install.sh" --dry-run-merge "$tmpdir" &>/dev/null
  local rc=$?

  local result="$tmpdir/.claude/settings.json"
  if [ ! -f "$result" ]; then
    fail "$name"
    echo "[FAIL] $name: settings.json not found after --dry-run-merge" >&2
    return
  fi

  local model env_foo has_hooks
  model="$(jq -r '.model' "$result" 2>/dev/null)"
  env_foo="$(jq -r '.env.FOO' "$result" 2>/dev/null)"
  has_hooks="$(jq -e '.hooks.PostToolUse' "$result" &>/dev/null && echo yes || echo no)"

  if [ "$model" != "opus" ]; then
    fail "$name"
    echo "[FAIL] $name: .model='$model' (expected 'opus')" >&2
    return
  fi
  if [ "$env_foo" != "bar" ]; then
    fail "$name"
    echo "[FAIL] $name: .env.FOO='$env_foo' (expected 'bar')" >&2
    return
  fi
  if [ "$has_hooks" != "yes" ]; then
    fail "$name"
    echo "[FAIL] $name: .hooks.PostToolUse not found after merge" >&2
    return
  fi
  pass "$name"
}

# check_install_calls_merge_in_normal_path — install.sh의 --dry-run-merge 블록 바깥에 merge_settings_json 호출이 있는지 확인
check_install_calls_merge_in_normal_path() {
  local name="check_install_calls_merge_in_normal_path"
  if awk '
    /--dry-run-merge/ {skip=1}
    skip==1 && /^fi/ {skip=0; next}
    skip!=1 {print}
  ' "$REPO_ROOT/install.sh" | grep -q 'merge_settings_json'; then
    pass "$name"
  else
    fail "$name"
    echo "[FAIL] $name: install.sh does not call merge_settings_json outside --dry-run-merge branch" >&2
  fi
}

# check_install_dry_run_empty — .claude/가 없는 빈 tmpdir에서 --dry-run-merge 실행
# 결과 JSON에 hooks.PostToolUse가 존재해야 함
check_install_dry_run_empty() {
  local name="check_install_dry_run_empty"
  if ! command -v jq &>/dev/null; then
    skip "$name" "jq not in PATH"
    return
  fi

  local tmpdir
  tmpdir="$(mk_tmp)"
  # .claude/ 디렉토리 없음 — 완전히 빈 상태

  bash "$REPO_ROOT/install.sh" --dry-run-merge "$tmpdir" &>/dev/null

  local result="$tmpdir/.claude/settings.json"
  if [ ! -f "$result" ]; then
    fail "$name"
    echo "[FAIL] $name: settings.json not created after --dry-run-merge in empty dir" >&2
    return
  fi

  if ! jq -e '.hooks.PostToolUse' "$result" &>/dev/null; then
    fail "$name"
    echo "[FAIL] $name: .hooks.PostToolUse not found in generated settings.json" >&2
    return
  fi
  pass "$name"
}

# ---------------------------------------------------------------------------
# 실행
# ---------------------------------------------------------------------------

check_frontmatter
check_new_agents_in_install
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
check_install_dry_run_preserves
check_install_dry_run_empty
check_install_calls_merge_in_normal_path

echo ""
echo "Summary: $PASS passed, $FAIL failed, $SKIP skipped"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed checks:" >&2
  printf '  - %s\n' "${FAILED_CHECKS[@]}" >&2
  exit 1
fi
exit 0
