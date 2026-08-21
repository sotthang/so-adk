# Architecture: SO-ADK Claude Code 플러그인 전환 (SPEC-001 v3.2)

**SPEC**: `specs/SPEC-001-plugin-migration.md` (v3.2, Approved → 본 설계 완료 시 Architected)
**리뷰**: `specs/SPEC-001-plugin-migration.review-v3.md` (Approved, M-1·M-2 반영 완료 확인)
**선행 산출물**: v2 preview(`scratchpad/arch-preview-v2-partial.md`)의 매핑표·매니페스트를 재사용하되, R11은 F12에 따라 전면 재작성. F1~F14 실측 사실을 전제로 하며 추측 폴백 없음.

**이 설계 세션에서 새로 실측한 사실** (2026-08-21, claude CLI 2.1.226):

| # | 실측 내용 | 결과 | 반영 |
| - | -------- | ---- | ---- |
| V-1 | `bash tests/run-checks.sh` 현행 기준선 | **23 passed, 1 failed** (`check_settings_json_valid`), 0 skipped — 검사 총 24개 | §6 매핑표 |
| V-2 | `tests/run-checks.sh:44-59`의 `resolve_agents_dir`/`resolve_orchestrator_file` | scratchpad 픽스처에서 `plugins/` 레이아웃 감지 **동작 확인** — 디렉터리/파일 존재 시 plugins 경로 반환 | §6 — 리졸버 사용 검사 11종은 **경로 무수정** |
| V-3 | §3 매니페스트 초안 4종을 scratchpad에 구성 후 `claude plugin validate --strict` | core·orchestrator·marketplace **모두 exit 0**. 단 marketplace는 최상위 `description` 누락 시 `--strict` FAIL → **description 필수** (SPEC R4에 없던 실측 추가 요건) | §3.5 |
| V-4 | §3.6 settings.json 초안에 대한 AC-R4c/AC-R4d jq 검사 | keys == `enabledPlugins`,`extraKnownMarketplaces` ✓, github 스키마 ✓ | §3.6 |
| V-5 | **현행 `check_settings_json_valid`(run-checks.sh:173-198)는 `.hooks.PostToolUse` 존재를 요구한다** — R4의 신규 settings.json(훅 없음)을 커밋해도 현행 구현으로는 **여전히 FAIL** (jq 실측: `.hooks.PostToolUse` → null, exit 1) | 오케스트레이터 지시문의 "R4 커밋으로 통과 예상"은 **부정확** — 검사 재정의(C4)가 있어야 통과. §6 #4 | §5, §6 |
| V-6 | AC-R5a 패턴 (1)(M-1 보정판)을 현 트리에 적용 | `so-quality.md:3` `/refactor` **정확히 1건** (오탐 0) — SPEC 자가 검증 조건 재현 성공 | §7 C3 |
| V-7 | AC-R5a 패턴 (2)를 현 오케스트레이터에 적용 | 4건 검출 — 단 실제 행 번호는 **88·244·250·295** (SPEC의 88·228·234·277은 SPEC-002 병합으로 stale — 건수 4는 유지) | §11 불일치 보고 |
| V-8 | 에이전트 16개 전수에 `so-foundation` 문자열 존재 | **16/16 매치** → R6 에이전트 마커 grep 가드로 채택 가능 | §8 |
| V-9 | v2 preview의 스킬 마커 정규식 `so-(adk\|planner\|quality\|preflight\|orchestrator)`를 dev/plan/pr/refactor에 적용 | **plan·refactor만 매치, dev·pr 불매치** — preview 설계 결함. 대체 마커: 4개 스킬 모두 포함하는 공통 문장 `Claude normally triggers this automatically` **4/4 매치** | §8 |
| V-10 | git 상태 | 브랜치 `feat/spec-001-plugin-migration`, `pre-plugin` 태그 로컬 존재, 훅 2개 `+x` 유지 | §7 T0 |

---

## 1. File Structure (최종 형상)

```text
so-adk/
├── .claude-plugin/
│   └── marketplace.json                      # 신규 — §3.5 (--strict 통과에 description 필수: V-3)
├── .claude/
│   ├── settings.json                         # 신규 커밋 — §3.6 (키 2개 한정, github source)
│   └── settings.local.json                   # 계속 gitignore (개인 설정 배출구)
├── plugins/
│   ├── so-adk-core/
│   │   ├── .claude-plugin/plugin.json        # 신규 — §3.1
│   │   ├── agents/                           # git mv ← .claude/agents/ (16개, 본문 무수정*)
│   │   │                                     #   * 예외: so-quality.md:3 '/refactor' — C3 치환 (M-2)
│   │   ├── skills/                           # git mv ← .claude/skills/ (8개 디렉터리)
│   │   │   └── dev/SKILL.md                  #   └ R5 CLAUDE.md 참조 문구 치환 (C3)
│   │   └── hooks/
│   │       ├── hooks.json                    # 신규 — §3.3
│   │       ├── post-edit-check.sh            # git mv (본문 무수정, +x 유지)
│   │       └── session-start-resume.sh       # git mv (본문 무수정, +x 유지)
│   └── so-adk-orchestrator/
│       ├── .claude-plugin/plugin.json        # 신규 — §3.2
│       ├── agents/so-orchestrator.md         # git mv ← .claude/so-orchestrator.md
│       │                                     #   └ C3: frontmatter 추가(§4) + R5/R10 치환
│       └── settings.json                     # 신규 — §3.4 ("agent" 키, F1)
├── install.sh                                # 마이그레이션 래퍼로 전면 재작성 — §8
├── install.ps1                               # 동일 동작 best-effort + --migrate 베타 경고 (C-8)
├── tests/run-checks.sh                       # 24개 검사 전수 매핑 반영 — §6
├── CLAUDE.md                                 # dogfooding 안내문으로 대체 (C7 — C-7)
├── .gitignore                                # 3행 .claude/settings.json 등재 해제 — §3.7
└── README.md / README.ko.md                  # R8
```

---

## 2. 파일 이동 매핑표 — 디렉터리 단위 `git mv` 시퀀스 (R1, 커밋 C1)

디렉터리 3건 + 파일 1건. 나열 누락 버그 클래스가 이동 작업에 존재하지 않는다:

```bash
mkdir -p plugins/so-adk-core plugins/so-adk-orchestrator/agents

git mv .claude/agents  plugins/so-adk-core/agents        # 에이전트 16개 (so-spike 포함 — v3.2)
git mv .claude/skills  plugins/so-adk-core/skills        # 스킬 디렉터리 8개
git mv .claude/hooks   plugins/so-adk-core/hooks         # 훅 스크립트 2개 (+x 유지 확인: V-10)
git mv .claude/so-orchestrator.md \
       plugins/so-adk-orchestrator/agents/so-orchestrator.md

git commit -m "structural: move assets into plugin directories (pure git mv, no content change)"
```

- **C1은 순수 이동 커밋** — frontmatter·치환 일절 없음(SPEC Technical Approach가 frontmatter를 커밋 3에 배정 — C-5). 전 파일 유사도 100% rename (AC-R1a).
- 검증: `git diff --name-status --find-renames HEAD~1 HEAD | grep -v '^R100'` → **출력 0줄**.
- C1 직후 레거시 4경로(`.claude/agents`, `.claude/skills`, `.claude/hooks`, `.claude/so-orchestrator.md`)는 저장소에서 소멸한다(AC-R9의 경로 부재 조건은 C1부터 충족). 남는 R9 잔여 작업은 CLAUDE.md 처분(C7)뿐이다.

---

## 3. 매니페스트 실제 내용 (전부 scratchpad에서 `claude plugin validate --strict` 통과 확인 — V-3)

### 3.1 `plugins/so-adk-core/.claude-plugin/plugin.json`

```json
{
  "name": "so-adk-core",
  "version": "1.0.0",
  "description": "SO-ADK core: 16 pipeline agents, 8 skills, 2 hooks (SessionStart resume + PostToolUse lint/typecheck gate). WARNING: at User scope the hooks fire globally in EVERY project (lint/typecheck on every Edit, blocking on failure; specs scan on every session start) - install at Project or Local scope.",
  "author": { "name": "sotthang", "email": "sotthang@gmail.com" }
}
```

### 3.2 `plugins/so-adk-orchestrator/.claude-plugin/plugin.json`

```json
{
  "name": "so-adk-orchestrator",
  "version": "1.0.0",
  "description": "SO-ADK main-thread orchestrator: replaces the session's main agent with natural-language intent routing to the SO-ADK pipeline. REQUIRES so-adk-core (agents are dispatched by plain name across plugins). Project/Local scope ONLY.",
  "author": { "name": "sotthang", "email": "sotthang@gmail.com" }
}
```

### 3.3 `plugins/so-adk-core/hooks/hooks.json`

현행 `install.sh` `SETTINGS_TEMPLATE`(install.sh:12-30)과 동일한 이벤트/매처 구성, 경로만 `${CLAUDE_PLUGIN_ROOT}`(F5):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start-resume.sh" } ] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write|MultiEdit",
        "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-check.sh" } ] }
    ]
  }
}
```

### 3.4 `plugins/so-adk-orchestrator/settings.json`

```json
{ "agent": "so-orchestrator" }
```

플레인 이름 — F1(메인 스레드 교체)·F11(교차 플러그인 플레인 이름 디스패치) 실측 확정.

### 3.5 `.claude-plugin/marketplace.json` (repo 루트)

**실측 추가 요건(V-3)**: 최상위 `description` 없으면 `--strict` FAIL — SPEC R4 명세에 없지만 F6("warning의 --strict 에러 승격")의 구체 사례이므로 추가한다.

```json
{
  "name": "so-adk",
  "description": "SO-ADK: spec-first agentic development kit for Claude Code (pipeline agents, skills, hooks, main-thread orchestrator).",
  "owner": { "name": "sotthang", "email": "sotthang@gmail.com" },
  "plugins": [
    { "name": "so-adk-core", "source": "./plugins/so-adk-core", "version": "1.0.0",
      "description": "SO-ADK pipeline agents, skills, and hooks. Project/Local scope recommended (User scope fires hooks globally)." },
    { "name": "so-adk-orchestrator", "source": "./plugins/so-adk-orchestrator", "version": "1.0.0",
      "description": "Main-thread orchestrator. Requires so-adk-core. Project/Local scope only." }
  ]
}
```

`version`을 marketplace 엔트리에 기재 — `claude plugin tag`의 일치 검증 대상(F8, R12).

### 3.6 repo `.claude/settings.json` (신규 커밋 — R4)

**github 정규 형태 확정** (F14 — v2 preview의 local-relative 1안은 폐기, F13/F14로 대체됨):

```json
{
  "extraKnownMarketplaces": {
    "so-adk": { "source": { "source": "github", "repo": "sotthang/so-adk" } }
  },
  "enabledPlugins": {
    "so-adk-core@so-adk": true,
    "so-adk-orchestrator@so-adk": true
  }
}
```

- 효력 경계(F12): 마켓플레이스 **자동 등록 + 활성 상태 기록**까지. 설치는 기여자가 `claude plugin install <name>@so-adk --scope project` **명시적 1회** (README 개발 섹션).
- AC-R4c(키 2개 한정)·AC-R4d(github 스키마) jq 검사 초안 통과 확인(V-4).

### 3.7 `.gitignore` 변경 (3행 해제, 2행 유지)

```gitignore
# Claude Code — settings.json은 팀 공유 설정(마켓플레이스 등록/플러그인 활성 기록)으로 커밋 대상.
# 개인 설정(model, env, permissions 등)은 반드시 settings.local.json에 둘 것 (계속 ignore됨).
.claude/settings.local.json
.claude/memory/

# macOS
.DS_Store

# VSCode
.vscode/

# SO-ADK: archive 폴더 구조는 유지하되 내용은 로컬에만
specs/archive/*
!specs/archive/.gitkeep
```

개인 설정 유출 방지 2중 장치: (1) 관행 — `settings.local.json` 지속 ignore + 주석 + README 한 줄(R8), (2) 기계 — 재정의된 `check_settings_json_valid`의 최상위 키 allowlist(AC-R4c)가 게이트에서 차단.

---

## 4. 오케스트레이터 frontmatter (R3, 커밋 C3)

```yaml
---
name: so-orchestrator
description: SO-ADK main-thread orchestrator. Routes natural-language intents to SO-ADK pipeline agents (so-planner through so-spike). Not a subagent - activated by the so-adk-orchestrator plugin's settings.json "agent" key. Requires so-adk-core.
---
```

- `model` **금지**(F10 — 세션 `--model` 존중), `tools` **생략**(전체 상속), `skills` 생략(현행도 프리로드 없음 — 동작 보존).

### `check_frontmatter` 분리 (매핑 #1)

- `check_frontmatter`(기존): 대상은 리졸버의 `$AGENTS_DIR`이므로 **코드 무수정으로 plugins 경로에 자동 적용**(V-2). 4필드(name/description/tools/model) 요구 유지 — 16개 에이전트 전용.
- `check_orchestrator_frontmatter`(신설): 대상 `$ORCH_FILE`. 부재 검사는 **frontmatter 블록에 한정**해야 오탐이 없다(본문 산문에 `model:` 등장 가능):

```bash
check_orchestrator_frontmatter() {
  local f="$ORCH_FILE" fm
  fm="$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$f")"
  head -1 "$f" | grep -q '^---$'             || fail_reason "first line not ---"
  grep -q '^name: so-orchestrator$' <<<"$fm" || fail_reason "name missing"
  grep -q '^description:' <<<"$fm"           || fail_reason "description missing"
  grep -q '^model:' <<<"$fm"                 && fail_reason "model must be ABSENT (F10)"
  grep -q '^tools:' <<<"$fm"                 && fail_reason "tools must be ABSENT"
}
```

---

## 5. R11 커밋 시퀀스 (F12 재설계 반영)

**폐기된 v2 메커니즘**: "git mv 직후 settings.json 커밋으로 dogfooding 즉시 복구" — F12로 부정됨. **대체**: 브랜치 전 구간의 dogfooding은 `claude --plugin-dir` 세션 로드(역할축 — I-1: 플러그인 개발자용 상시 로드 방식), 병합 후 소비자·기여자 온보딩은 명시적 install 1회.

| # | 커밋 | 분류 | dogfooding 상태 | run-checks 기대 |
| - | ---- | ---- | -------------- | --------------- |
| T0 | (완료) `pre-plugin` 태그 + `feat/spec-001-plugin-migration` 브랜치 (V-10). **태그 push 확인 필요** (`git ls-remote --tags origin pre-plugin`) | — | 레거시 (현재 이 저장소는 settings.json 부재로 훅 비활성 — 허용 동작 변경 5) | 기준선 **23P/1F** (V-1) |
| C1 | §2 순수 git mv 4건 | 구조 | 불능 시작 → **스파이크 S-1로 착수 전 `--plugin-dir` 사전 확인**(리뷰 I-1) | **예상 FAIL 6종**(하단 표) — PR 본문에 기록 |
| C2 | 신규 파일 6종(§3.1~3.6) + `.gitignore` 해제(§3.7) | 구조 | `claude --plugin-dir ./plugins/so-adk-core` 가능(core만 — orchestrator는 frontmatter 전이라 미등록) | C1과 동일 FAIL 6종 — **settings.json을 커밋해도 현행 검사는 `.hooks.PostToolUse`를 요구해 여전히 FAIL**(V-5) |
| C3 | 텍스트 치환: orchestrator frontmatter(§4) + 스킬 네임스페이스(슬래시형 1건 `so-quality.md:3` V-6 + 스킬 언급형 4건 orchestrator 88·244·250·295 V-7) + dev SKILL.md CLAUDE.md 문구 + Step 2-B self-update 서술(R10) | 허용 치환 | **두 플러그인 `--plugin-dir` 동시 로드 가능 시점** | 동일 FAIL 6종 |
| C4 | install.sh/ps1 래퍼 재작성(§8) + tests/run-checks.sh 전수 매핑 반영(§6) | 행위(도구) | 정상 | **이 커밋부터 전체 PASS 의무** — 이후 전 커밋 exit 0 |
| C5 | README.md / README.ko.md (R8 — 8항목 체크리스트 AC-R8) | 문서 | 정상 | PASS |
| C6 | 스모크 수행(하단) → 결과 커밋에 **trailer `Smoke-Verified: AC-R2c,AC-R3e`** (필요 시 `--allow-empty`). 상세는 PR 본문(정보용 — 증명 수단은 trailer, 통과 사실은 자기 신고) | 검증 | 정상 | PASS |
| C7 | **최종 커밋**: repo `CLAUDE.md`를 import 한 줄에서 **dogfooding 안내문으로 대체**(C-7 — 자체 플러그인 사용 사실 + 기여자 온보딩 1회 install + `--plugin-dir` 개발 모드, 상세는 README 링크) | 구조 | 정상 | PASS |

**C1~C3 예상 상태 — 스파이크 S-2로 실측 완료 (예측 정정됨)**

> ⚠️ **S-2 음성**: 이 표는 원래 "FAIL 6종"으로 예측했으나 **실측 결과는 `17 passed, 2 failed, 5 skipped`** 였다.
> 훅 검사 4종(`check_hook_empty_dir`/`check_hook_npm_lint_ok`/`check_hook_npm_lint_fail`/`check_hook_python_no_tools`)은
> 훅 파일 부재 시 `skip`을 먼저 호출하는 가드가 있어 **FAIL이 아니라 SKIP**으로 떨어진다(사유 `"hook not executable"`).
> 실제 FAIL은 `check_settings_json_valid`와 `check_hook_exists_executable` **2종뿐**이다.
> 코드 분석만으로 도출한 예측이 실행 경로의 skip 가드를 놓친 사례다.
> **PR 본문과 AC-R7a 기준선은 "FAIL 6종"이 아니라 "FAIL 2종 + SKIP 4종"으로 기록해야 한다.**

| 검사 | C1 직후 실측 판정 | 사유 |
| ---- | ---------------- | ---- |
| `check_settings_json_valid` | **FAIL** | C1: 파일 부재(현행과 동일). C2 이후: 파일은 있으나 현행 구현이 `.hooks.PostToolUse` 요구(V-5) |
| `check_hook_exists_executable` | **FAIL** | `.claude/hooks/post-edit-check.sh` 하드코드(run-checks.sh:202) — C1에서 경로 소멸 |
| `check_hook_empty_dir` 외 3종 | **SKIP** | 동일 하드코드지만 skip 가드가 선행 — 예측이 FAIL로 본 것이 오류 |

<details><summary>원 예측표 (v1 — 보존)</summary>


| 검사 | FAIL 사유 |
| ---- | -------- |
| `check_settings_json_valid` | C1: 파일 부재(현행과 동일). C2 이후: 파일은 있으나 현행 구현이 `.hooks.PostToolUse` 요구(V-5) |
| `check_hook_exists_executable` | `.claude/hooks/post-edit-check.sh` 하드코드(run-checks.sh:202) — C1에서 경로 소멸 |
| `check_hook_empty_dir` / `check_hook_npm_lint_ok` / `check_hook_npm_lint_fail` / `check_hook_python_no_tools` | 동일 하드코드(:508/:538/:579/:615) |

</details>

리졸버 기반 검사 11종(V-2)과 install.sh 참조 검사(구 install.sh가 C4까지 잔존)는 C1~C3에서도 PASS 유지, `check_spike_in_install`은 plugins 레이아웃 자체 SKIP 분기로 SKIP 전환(run-checks.sh:471-474 실물 확인).

**C6 스모크 내용**:

- **AC-R2c**: `claude --plugin-dir ./plugins/so-adk-core` 세션 → so-planner 호출 → so-foundation·so-spec-format 플레인 이름 프리로드(F4 재확인) + `${CLAUDE_PLUGIN_ROOT}` 훅 발동(F5 재확인 — hooks.json 래퍼 스키마의 실동작 검증 겸용).
- **AC-R3e**: 전역 CLAUDE.md 지침이 있는 스크래치 프로젝트에서 `claude --plugin-dir <abs>/plugins/so-adk-core --plugin-dir <abs>/plugins/so-adk-orchestrator` 세션(github published에 아직 plugins/가 없으므로 install 경로는 병합 전 사용 불가 — `--plugin-dir`가 유일한 스모크 수단): (1) "도움말" → Help Guide(메인 스레드 교체), (2) 전역 CLAUDE.md 지침 인지 질의(F2 회귀), (3) 라우팅 발화 → so-planner 실 Agent 툴 호출(F11 회귀 — 교차 플러그인 디스패치).

**AC-R11b 기계 검증** (PR 체크리스트):

```bash
git log -1 HEAD^ --format=%B | grep -F 'Smoke-Verified: AC-R2c,AC-R3e'   # trailer 존재
git diff --name-only HEAD~1 HEAD                                          # C7 = CLAUDE.md 1줄
git show HEAD:CLAUDE.md | grep -cF '@.claude/so-orchestrator.md'          # 0
git tag --list pre-plugin && git merge-base --is-ancestor pre-plugin HEAD # AC-R11a
gh pr view --json headRefName,baseRefName                                 # AC-R11c
```

**온보딩(병합 후, README 개발 섹션 명문화)**: ① 소비 기여자 — `claude plugin install so-adk-core@so-adk --scope project` (+ orchestrator) 1회, 이어서 `claude plugin list`로 두 플러그인 `✔ enabled` 확인(리뷰 I-2 — F13 무증상 disabled 방어), ② `plugins/` 편집 개발자 — 상시 `--plugin-dir` (github 소스 install은 published 사본을 무성 로드하므로 로컬 편집 미반영 — I-1 역할축).

---

## 6. R7 테스트 설계 — **24개 검사 전수 매핑표** (v3.2 미처리분 갱신)

SPEC v3의 15개 표는 stale — SPEC-002가 9종을 추가해 현행 **24개**(V-1: 23P/1F). 리졸버(V-2)가 이미 plugins 레이아웃을 감지하므로 **11종은 코드 무수정**이다. 전수 처분:

### 6.1 레거시 15종 (SPEC R7 표의 번호 유지)

| # | 검사 | 처분 | 내용 |
| - | ---- | ---- | ---- |
| 1 | `check_frontmatter` | **무수정+분리** | `$AGENTS_DIR` 리졸버 사용 → 경로 자동 적응(V-2). 4필드 유지. orchestrator는 `check_orchestrator_frontmatter` 신설 분리(§4) |
| 2 | `check_new_agents_in_install` | **삭제→대체** | install.sh 나열 소멸 → 순방향 파일-참조 일치성 `check_orchestrator_agent_refs_exist`(§6.3). 함수명 문자열 자체 제거(AC-R7d) |
| 3 | `check_new_agents_in_orchestrator` | **무수정** | `$ORCH_FILE` 리졸버 사용(실물 확인) |
| 4 | `check_settings_json_valid` | **재정의** | 현행은 `.hooks.PostToolUse` 요구 → R4 파일과 양립 불가(V-5). 재정의 3종: (a) 유효 JSON + `extraKnownMarketplaces["so-adk"]` + `enabledPlugins` 두 키(`<plugin>@so-adk` == true), (b) **최상위 키 정확히 2개**(AC-R4c — jq `keys == ["enabledPlugins","extraKnownMarketplaces"]`), (c) **source github 정규 스키마**(AC-R4d — `.source.source=="github" and .source.repo=="sotthang/so-adk"`, V-4에서 jq 식 검증 완료) |
| 5 | `check_hook_exists_executable` | **갱신** | 하드코드 `.claude/hooks/`(:202) → `plugins/so-adk-core/hooks/`, **2개 스크립트 모두** 존재+`-x` (현행은 post-edit-check.sh만 검사 — 확장) |
| 6 | `check_tester_outside_in_mode` | **무수정** | `$AGENTS_DIR` 리졸버 |
| 7 | `check_architect_preview_mode` | **무수정** | `$AGENTS_DIR` 리졸버 |
| 8 | `check_orchestrator_parallel_review` | **무수정** | `$ORCH_FILE` 리졸버 |
| 9 | `check_hook_empty_dir` | **갱신** | 하드코드(:508) → 훅 경로 상수 `HOOK="$REPO_ROOT/plugins/so-adk-core/hooks/post-edit-check.sh"` 도입, 로직 무수정 |
| 10 | `check_hook_npm_lint_ok` | **갱신** | 동일(:538) |
| 11 | `check_hook_npm_lint_fail` | **갱신** | 동일(:579) |
| 12 | `check_hook_python_no_tools` | **갱신** | 동일(:615) |
| 13 | `check_install_dry_run_preserves` | **삭제→대체** | `check_migrate_backup_preserves` — AC-R6a/f: 레거시 픽스처(`mk_legacy_fixture`, §6.4) → `--migrate` → SO-ADK 자산 백업 이동 + `my-agent.md`·사용자 CLAUDE.md 내용·settings 타 키 보존 + 사용자 수정 `so-planner.md` 백업 보존 |
| 14 | `check_install_calls_merge_in_normal_path` | **삭제→대체** | `check_migrate_hook_entry_removal`(정상 경로: 엔트리만 정밀 제거) + `check_migrate_no_jq_guard`(AC-R6g: jq 제외 스텁 PATH → 훅 스크립트 미이동 + exit 비0) + `check_migrate_bad_settings_json`(AC-R6h: 픽스처 settings.json을 비유효 JSON으로 → 훅 스크립트 미이동 + 수동 절차 출력 + exit 비0) |
| 15 | `check_install_dry_run_empty` | **삭제→대체** | `check_migrate_no_flag_noop`(AC-R6d) + `check_migrate_dry_run`(AC-R6e) + `check_migrate_empty_dir`(AC-R6c) — 실행 전후 `find \| sort` + 파일 해시 대조로 무변경 증명 |

### 6.2 SPEC-002 신규 9종

| # | 검사 | 처분 | 근거 |
| - | ---- | ---- | ---- |
| 16 | `check_architect_bash_tool` | **무수정** | `$AGENTS_DIR` 리졸버 |
| 17 | `check_reviewer_write_tool` | **무수정** | 동일 |
| 18 | `check_reviewer_persistence` | **무수정** | 동일 |
| 19 | `check_tool_grants` | **무수정** | 동일 |
| 20 | `check_spike_agent` | **무수정** | 동일 |
| 21 | `check_unverified_assumption_format` | **무수정** | 동일 |
| 22 | `check_orchestrator_spike_path` | **무수정** | `$ORCH_FILE` 리졸버. 요구 문구(Step 3.7, so-spike, 최대 2회 등)는 R5/R10 치환 대상과 무교집합 — 본문 무수정 불변식으로 보존 |
| 23 | `check_spike_in_install` | **무수정 (SKIP 전환)** | plugins 레이아웃 자체 SKIP 분기 내장(run-checks.sh:471-474 실물 확인) — 이관 후 영구 SKIP. 제거는 SPEC-002 소관이므로 이번엔 유지(최소 diff) |
| 24 | `check_no_hardcoded_agent_paths` | **갱신** | awk 예외 목록(`resolve_*`, 자기 자신)에 **`mk_legacy_fixture` 추가** — §6.4의 함정 방어 |

### 6.3 신규 검사 (SPEC R7 + AC 대응)

| 함수 (신설) | 검증 내용 |
| ----------- | -------- |
| `check_orchestrator_agent_refs_exist` | **순방향**: 오케스트레이터 본문의 `so-*` 참조 전수가 `plugins/so-adk-core/agents/`에 실파일 존재(AC-R7b). 토큰 패턴 `\bso-[a-z][a-z-]*`(`so-[a-z]+`는 `so-spec-format`을 절단 — preview 검증 유지). denylist = 고정 4개(`so-adk`, `so-adk-core`, `so-adk-orchestrator`, `so-orchestrator`) + **스킬 디렉터리명 동적 수집**(스킬 추가 시 테스트 무수정) |
| `check_no_orphan_agents` | **역방향**: agents 16개 전수가 오케스트레이터 본문에서 참조됨(AC-R7c). so-spike는 Step 3.7로 참조 확인됨(#22 GREEN이 방증) — 양방향 이관 직후 GREEN 기대 |
| `check_orchestrator_frontmatter` | §4 — name/description 존재 + model/tools **부재**(AC-R3d) |
| `check_hooks_json_valid` | AC-R2b: jq 파싱 + SessionStart/PostToolUse(matcher `Edit\|Write\|MultiEdit`) + 전 command `${CLAUDE_PLUGIN_ROOT}` 시작 + 참조 스크립트 2개 존재·실행가능 |
| `check_plugin_validate_core` / `_orchestrator` / `_marketplace` | `command -v claude` 부재 시 SKIP. `claude plugin validate <path> --strict` exit 0 (AC-R2a/R3a — --strict 통과 가능함은 V-3 실측) |
| `check_asset_counts` | AC-R1b: agents `*.md` == **16**, `skills/*/SKILL.md` == 8 (SPEC AC-R1b의 '15'는 stale — §11) |
| `check_skill_namespace` | AC-R5a 두 패턴(M-1 보정 슬래시형 + C-4 스킬 언급형)으로 `plugins/` 하위 구 호출명 0건. 자가 검증 실측 재현 완료(V-6·V-7) |
| `check_wrapper_static` | AC-R6b: install.sh에 curl 다운로드·CLAUDE.md append 부재 + 고정 목록 존재 + **에이전트·스킬 대칭 마커 grep 가드 존재** |
| `check_orchestrator_settings_agent` | AC-R3b: `jq -r '.agent'` == `so-orchestrator` |
| `check_marketplace_json_valid` | AC-R4a: jq 파싱 + 두 플러그인 엔트리 + `./plugins/` source |

run-checks.sh 상단 주석에 **`claude plugin eval` 미도입 판정** 기재(R7 요구): eval은 LLM 실행 기반 시나리오 러너 — 비결정적·API 비용·CI 부적합. 파일-참조 일치성은 결정적 정적 계약이므로 bash grep이 정확·즉시·무비용. eval의 적소는 AC-R3e류 라우팅 스모크의 향후 자동화(Out of Scope).

`claude plugin tag` 검증(AC-R12a)은 실제 태그 생성 부작용 → run-checks 미포함, 릴리스 시 1회(C-9).

### 6.4 신규 함정 — `check_no_hardcoded_agent_paths` 자기 충돌 방어

#13~15 대체 검사는 임시 디렉터리에 **레거시 픽스처**(`.claude/agents/` 등)를 구축해야 하는데, `check_no_hardcoded_agent_paths`는 run-checks.sh 내 `\.claude/(agents|so-orchestrator\.md)` 리터럴을 금지한다(리졸버·자기 자신만 예외). 픽스처 코드가 이 리터럴을 쓰면 #24가 FAIL한다. **방어**: 레거시 픽스처 구축을 단일 헬퍼 `mk_legacy_fixture()`로 집약하고, #24의 awk 예외 목록에 이 함수명을 추가한다(§6.2 #24). 변조 테스트(AC-R7b/c)는 저장소 임시 사본(`cp -R` → mktemp)에서 수행해 작업 트리를 오염시키지 않는다.

---

## 7. 셀프 호스팅 안전 순서 + 롤백 (R9·R11)

**안전 순서** = §5 커밋 시퀀스 그 자체. 핵심 불변식:

1. main은 병합 시점까지 레거시 유지 — 기존 curl URL 사용자에게 중간 상태 미서빙(R11-b, AC-R11c).
2. 브랜치 전 구간 dogfooding은 `--plugin-dir`(설치·settings 상태 무관 — F12 우회). 착수 전 스파이크 S-1로 사전 확인(리뷰 I-1). 실패 시 폴백: `claude plugin install --scope local`(F12 **대조군 양성** — 이미 실측된 경로).
3. 레거시 제거(C7)는 최종 커밋, 직전 커밋에 `Smoke-Verified:` trailer(AC-R11b).

**롤백 계층**:

| 상황 | 절차 |
| ---- | ---- |
| 병합 전 실패 | 브랜치 폐기 — main 무손상. `--plugin-dir` 세션만 중단하면 원상태 |
| 병합 후 저장소 롤백 | `git revert -m 1 <merge-commit>` (이력 보존) 또는 비상시 `pre-plugin` 태그 기준 복귀. T0에서 태그 push 확인 필수 |
| 사용자 롤백 (마이그레이션 후) | `.claude/.so-adk-backup-<ts>/` 백업을 원위치로 복원(R6이 삭제가 아닌 이동이므로 항상 가능) + `claude plugin uninstall`(project 스코프는 F9 — `--scope local` disable 안내) |
| README 기재 | 위 절차 전부 R8 (7) 롤백/복구 섹션에 문서화 (AC-R8) |

---

## 8. R6 마이그레이션 래퍼 (`install.sh`) 제어 흐름

v2 preview §7을 계승하되 **3건 수정**: 에이전트 16개(so-spike 추가 — v3.2 (c): 누락 시 curl 사용자의 `so-spike.md`만 고아로 남아 override 문제 발동), 에이전트 마커 가드 추가(대칭 — R6), 스킬 마커를 실측 기반으로 교체(V-9).

```text
install.sh [--migrate | --dry-run | --help]

parse_flag                          # 미지 플래그 → usage + exit 1
  │
detect_legacy                       # 읽기 전용. 고정 목록 대조:
  │   LEGACY_AGENTS=(so-planner so-reviewer so-architect so-scaffold so-tester
  │                  so-developer so-quality so-docs so-debugger so-explainer
  │                  so-preflight so-security so-performance so-designer
  │                  so-auditor so-spike)                    # 16개 — v3.2
  │   LEGACY_INTERNAL_SKILLS=(so-foundation so-spec-format so-tdd-workflow so-context)
  │   LEGACY_GUARDED_SKILLS=(dev plan pr refactor)
  │   LEGACY_HOOKS=(post-edit-check.sh session-start-resume.sh)
  │   LEGACY_ORCH=.claude/so-orchestrator.md
  │   # 주석 필수: "동결된 레거시 집합 — 더 이상 자라지 않으므로 나열 누락 버그 클래스 아님"
  │
  ├─ [무플래그]  진단만 출력(감지 목록 + --dry-run/--migrate 안내 + 설치 안내) → exit 0. 무변경 (AC-R6d)
  ├─ [--dry-run] 작업 계획 전체 출력(백업 대상 전체 경로, CLAUDE.md 라인 제거 예정,
  │              settings 훅 엔트리 제거 예정) → exit 0. 무변경 (AC-R6e)
  └─ [--migrate]
       (0) 레거시 미감지 → 설치 안내만, exit 0, 무변경 (AC-R6c)
       (1) 훅 엔트리 제거 게이트 — 어떤 파일 이동보다 먼저 (R6 순서 강제):
           - jq 부재 AND settings.json에 SO-ADK 훅 엔트리 존재
             → 수동 제거 절차 출력 + exit 1, 무이동 (AC-R6g)
           - settings.json이 비유효 JSON (jq 파싱 실패)
             → 수동 제거 절차 출력 + exit 1, 무이동 (AC-R6h)
       (2) settings.json 훅 엔트리 정밀 제거 (jq):
           - PostToolUse: command == ".claude/hooks/post-edit-check.sh" 엔트리만
           - SessionStart: command == ".claude/hooks/session-start-resume.sh" 엔트리만
           - 빈 배열 → 배열 삭제, .hooks == {} → hooks 키 삭제, 그 외 전 키 보존
           - tmp에 쓰고 jq 재파싱 검증 후 mv (원자적). 실패 → exit 1, 무이동
       (3) BACKUP=".claude/.so-adk-backup-$(date +%Y%m%d-%H%M%S)" 생성 — 첫 쓰기
       (4) 고정 목록 이동 (mv — 삭제 금지, 사용자 수정본 보존 → AC-R6a/f):
           - agents 16개: [ -f ] && grep -q 'so-foundation' 통과 시에만 mv   # 가드 대칭 (V-8: 16/16)
           - internal skills 4개: 무조건 mv (SO-ADK 전유 이름)
           - guarded skills 4개: SKILL.md에
             grep -qF 'Claude normally triggers this automatically' 통과 시에만 mv
             # V-9: install.sh:99-102 선례의 so-* 정규식은 dev·pr 불매치 — 실측 공통 문장으로 교체
           - hooks 2개 + so-orchestrator.md → $BACKUP/
           - .claude/agents·skills·hooks가 비면 rmdir (빈 경우만)
       (5) CLAUDE.md: '@.claude/so-orchestrator.md' 라인만 제거 (grep -vxF → tmp → mv).
           빈 파일 되어도 삭제 금지. 파일 부재 시 skip (생성도 금지)
       (6) 완료 출력: 백업 경로 + 설치 명령(--scope 명시 — C-3) + F9 문구
           (project 스코프는 일반 uninstall 거부 — --scope local disable)
           ※ specs/·specs/archive/ 생성하지 않음 (MODERATE 12)
```

**순서 불변식**: (1)(2) 훅 엔트리 제거 성공 → 그 후에만 (4) 훅 스크립트 이동. 역순이면 중간 실패 시 "엔트리 잔존 + 스크립트 부재" = 모든 Edit가 고아 훅으로 차단되는 최악 상태. 현재 순서의 중간 실패는 "엔트리 제거 + 스크립트 잔존"으로 무해.

`install.ps1`: 동일 흐름 best-effort 이식(AC 없음 — Out of Scope), 단 `--migrate` 출력에 **"이 스크립트는 자동 테스트가 없는 베타입니다 — 실행 전 --dry-run으로 대상을 확인하고 수동 검증하세요"** 경고 필수(C-8, R6).

---

## 9. Key Design Decisions

1. **리졸버 재사용으로 테스트 이관 diff 최소화**: SPEC-002의 `resolve_*`가 plugins 레이아웃을 이미 감지함을 실측(V-2) — 24개 중 11종 무수정, 경로 갱신은 훅 5종 + settings 1종에 국한. C4의 실제 작업량이 크게 줄어든다.
2. **`check_settings_json_valid`는 '경로 갱신'이 아니라 '재정의'**: 현행 구현이 `.hooks.PostToolUse`를 요구하므로 R4 파일 커밋만으로는 통과 불가(V-5). 훅은 플러그인 hooks.json으로 이관되므로 이 단언 자체가 무의미해진다 — SPEC 매핑 #4의 3종 재정의를 그대로 구현.
3. **marketplace description 추가**: `--strict`가 최상위 description 누락을 FAIL로 승격함을 실측(V-3). SPEC R4 명세 밖이지만 F6의 당연한 귀결로 편입.
4. **스킬 마커 가드를 실측 기반으로 교체**: preview의 `so-*` 정규식은 dev·pr 불매치(V-9) — 4개 스킬 공통 실측 문장 채택. 에이전트 가드는 `so-foundation`(16/16 — V-8).
5. **frontmatter는 C3** (preview의 C2 배치 폐기): SPEC v3 Technical Approach·AC-R1a가 커밋 3에 명시 배정(C-5). F12로 "C2 = dogfooding 복구 시점"이라는 preview의 배치 근거 자체가 소멸했다.
6. **`mk_legacy_fixture` 헬퍼 + awk 예외 등재**: 마이그레이션 픽스처의 `.claude/agents` 리터럴이 `check_no_hardcoded_agent_paths`를 FAIL시키는 자기 충돌을 구조적으로 방어(§6.4).
7. **eval 미도입**(preview 판정 유지): 결정적 정적 계약에 LLM 러너 부적합 — 판정을 run-checks 주석으로 기록.
8. **`--plugin-dir` = 역할축**(I-1/v3.1): 전환 중 임시 수단이 아니라 plugins/ 편집 개발자의 상시 모드. github 소스 install은 published 사본을 무성 로드 — README에서 소비자/개발자 경로 구분 기술.

## Dependencies

- **신규 패키지 없음**. bash + jq(기존 의존) + `claude` CLI(validate — PATH 부재 시 SKIP; 로컬 2.1.226에서 validate --strict 동작 확인).
- **재사용**: run-checks.sh의 `pass/fail/skip`·`require_phrase`·`mk_tmp`·trap 프레임과 리졸버 2종(무수정), 훅 스크립트 2개(무수정, +x 확인), scratchpad의 검증 완료 매니페스트 초안 4종(`scratchpad/draft/` — 커밋 시 그대로 사용 가능).

---

## 10. 미검증 가정 (Unverified Assumptions) — 스파이크 요청

| ID | 가정 내용 | 거짓일 경우 무너지는 것 | 제안 측정 방법 |
| -- | -------- | ----------------------- | -------------- |
| S-1 | `claude --plugin-dir`가 (a) 단독 및 (b) **2개 동시 지정**으로 플러그인을 세션 로드하고, hooks.json 래퍼 스키마(§3.3)의 훅이 실제 발동한다 — F 표에 `--plugin-dir` 실측 없음(리뷰 §2-1 지적과 동일) | **R11-c 공백기 봉쇄 전체**(브랜치 전 구간의 유일한 dogfooding 경로), AC-R2c·AC-R3e 스모크 실행 가능성 | scratchpad에 §3 초안으로 스켈레톤 플러그인 2개 구성 → `claude --plugin-dir <a> --plugin-dir <b> -p "..."` 1회 세션에서 에이전트 등록·훅 발동 확인 (5분 내). 실패 시 폴백은 `--scope local` install(F12 대조군 양성) |
| S-2 | C1 직후 run-checks의 FAIL 집합이 §5 예측표(6종)와 정확히 일치한다 — 코드 분석 도출이며 전체 스위트 실행으로는 미실측 | AC-R7a 기준선 해석("이관 전 통과하던 검사 전부"의 대상 확정)과 PR 본문의 C1~C3 예상 FAIL 기록(R11) | 저장소를 scratchpad에 `cp -R` → §2의 mv 4건 적용(plain mv) → `bash tests/run-checks.sh` 실행 → FAIL 목록을 예측표와 대조 (3분 내) |
| S-3 | 기여자가 커밋된 `.claude/settings.json`이 있는 상태에서 `claude plugin install --scope project`를 실행해도, 이 파일에 **새 최상위 키가 추가되거나 기존 값이 변형되지 않는다**(멱등) | AC-R4c(키 2개 한정 게이트)가 기여자 온보딩 직후 FAIL하거나 작업 트리가 상시 dirty가 되는 운영 마찰 — R4·R9 온보딩 절차의 실용성 | scratchpad에 §3.6 settings.json + 로컬 디렉터리 마켓플레이스를 둔 임시 git repo 구성 → project 스코프 install 실행 → `git diff .claude/settings.json`과 `jq keys` 대조 (5분 내) |

세 건 모두 픽스처 구성·세션 실행이 필요한 다단계 셋업이므로 본 설계에서 직접 수행하지 않았다(저장소 불변 계약 — so-spike 소관). **S-1은 C1 착수 전 필수**(리뷰 I-1), S-2·S-3은 C4 전까지 수행 권장.

## 11. SPEC 불일치 보고 (Architect는 SPEC 본문 수정 불가 — 오케스트레이터 처분 요망)

1. **AC-R1b가 여전히 "정확히 15"** (SPEC:280): 실물 에이전트는 16개(so-spike 포함, v3.2가 이 AC를 갱신 누락). 본 설계는 실물 기준 **16**으로 `check_asset_counts`를 설계했다. SPEC 문언 1자 수정 필요.
2. **AC-R5a 자가 검증의 행 번호 stale** (SPEC:294): 오케스트레이터의 스킬 언급 4건은 SPEC-002 병합으로 88·228·234·277 → **88·244·250·295**로 이동(V-7). 검출 **건수 4는 유지**되므로 AC 성립에는 영향 없음 — 정보성 갱신.
3. **R7 매핑표 15개 → 24개**: v3.2 이력에 "리베이스 시 갱신" 예고된 사항 — 본 설계 §6이 그 갱신본이다.

---

## ✅ Architect Complete — 다음 단계

- **산출물**: `specs/SPEC-001-plugin-migration.arch.md` (본 파일), SPEC Status → `Architected`
- **다음**: (1) 오케스트레이터 — §10 스파이크 3건(S-1 필수) 발주 + §11 SPEC 문언 처분, (2) so-tester — 본 설계 §6 매핑표 기준 RED 테스트 작성 (`so-scaffold`는 §2가 git mv 기반이므로 스텁 생성 불필요)
