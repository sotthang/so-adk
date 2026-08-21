# SPEC-002 Architecture — 파이프라인 검증 격차 해소

**대상 SPEC**: `specs/SPEC-002-pipeline-verification-gap.md` (v1.1, Approved)
**설계 일자**: 2026-08-21
**설계자**: so-architect (fable / effort: high)
**모드**: 정식 설계 (preview 아님)
**참조**: `specs/SPEC-002-pipeline-verification-gap.review-v1.md` (C-1~C-4 승인 조건, N-1~N-7, 열린 질문 2·3)

> **설계 자체가 실증이다**: 본 설계는 Bash 없이 Read/Grep/Glob만으로 수행됐다. §8의 가정 4건은
> 명령 한 줄이면 확정될 것들이지만 실행 수단이 없어 R5 형식으로 보고한다 — R1(D1)의 **3번째 실증**.
> 또한 본 설계 완료 시점에 SPEC Status를 `Architected`로 갱신해야 하나, 현행 so-architect에는
> Edit이 없고 쓰기 제약 문언(`Only write to specs/SPEC-*.arch.md`)이 SPEC 본문 수정을 금지한다 —
> **C-1 모순의 실황 재현**. Status 갱신은 오케스트레이터에 위임한다.

---

## 1. 파일별 변경 매핑표 (R1~R7 전수)

변경 파일 9개 + 무변경 보증 10개. 모든 경로는 현행 `.claude/` 레이아웃 기준
(SPEC-001 선병합 시 Technical Approach의 경로 치환 규칙 적용 — 본 설계는 SPEC-002 선병합을 기본 시나리오로 삼는다).

| # | 파일 | 변경 성격 | 상세 | R |
|---|------|-----------|------|---|
| 1 | `.claude/agents/so-architect.md` | frontmatter 수정 | `tools:` 라인에 `Bash`, `Edit` 추가 → `Read, Grep, Glob, Write, Edit, Bash, Skill` | R1, R3 |
|   |  | 본문 **치환** | 63행 쓰기 제약 문언을 C-1 교정문으로 교체 (§1.1) | R1 |
|   |  | 본문 섹션 신설 | `## Bash Usage Restrictions` — 허용/금지/scratchpad/N-2 경계 (§1.2) | R1 |
|   |  | 본문 섹션 신설 | `## 미검증 가정 보고 (Unverified Assumptions)` — 3열 형식 + 유보 금지 (§1.3) | R5 |
| 2 | `.claude/agents/so-reviewer.md` | frontmatter 수정 | `tools:`에 `Write` 추가 → `Read, Grep, Glob, Edit, Write, Skill` | R2 |
|   |  | 본문 섹션 신설 | `## Review Persistence` — `review-v{N}` 저장 규칙 + Write 경로 제한 + 인라인 금지 (§1.4) | R2 |
|   |  | 본문 섹션 신설 | `## 이전 리뷰 대조` — 대조 의무 + "이전 라운드 지적 추적" + 자가 점검 상설화 (§1.4) | R2, R6 |
|   |  | 본문 섹션 신설 | `## 미검증 가정 보고` — architect와 동일 3열 형식 (§1.3) | R5 |
| 3 | `.claude/agents/so-planner.md` | frontmatter 수정 | `tools:`에 `Edit` 추가 (리비전 루프 부분 수정) | R3 |
| 4 | `.claude/agents/so-designer.md` | frontmatter 수정 | `tools:`에 `Edit` 추가 (Status → `Designed` 갱신). **Skill은 추가하지 않는다** (SPEC 명시 제외) | R3 |
| 5 | `.claude/agents/so-quality.md` | frontmatter 수정 | `tools:`에 `Write` 추가 | R3 |
|   |  | 본문 1줄 추가 | Rules 섹션: "Write는 기존 코드에서 추출한 새 파일 생성에만 사용 — 신규 기능 파일 생성 금지" | R3 |
| 6 | `.claude/agents/so-spike.md` | **신설** | 전문 초안 §2 | R4 |
| 7 | `.claude/so-orchestrator.md` | 본문 섹션 신설 | `### Step 3.7 — Verification spike` (§3) — Step 3.5와 Step 4 사이에 배치 | R6 |
|   |  | 표 행 추가 | Agent Context Passing 표: `so-spike → reads 가정 목록 + writes scratchpad only, no SPEC status update` | R6 |
|   |  | 다이어그램 행 추가 | Full Pipeline: `[3.7] so-spike → 미검증 가정 실측 (조건부, SPEC당 최대 2배치)` | R6 |
| 8 | `install.sh` | 1줄 수정 | 125행 `AGENTS=(...)` 배열 끝(`so-auditor` 뒤)에 `so-spike` 추가 | R4 |
| 9 | `tests/run-checks.sh` | 구조 변경 (커밋 1) | 리졸버 2종 + 하드코드 5개 함수 치환 + 주석 경로 표현 갱신 (§4.1) | R7 |
|   |  | 신설 (커밋 2~5) | 신규 체크 8종 + `check_no_hardcoded_agent_paths` (N-7 판정 — §4.3) | R7 |
|   |  | 주석 갱신 | 4~21행 AC↔함수 매핑표 확장 (§4.4) | R7 |

**무변경 보증 (AC-R3b)**: so-scaffold, so-tester, so-developer, so-docs, so-debugger, so-explainer,
so-security, so-preflight, so-performance, so-auditor — 10개 파일의 frontmatter `tools:` 라인 불변.
검증 명령(리뷰 시): `git diff $(git merge-base HEAD main)..HEAD -- .claude/agents/` 에서 위 10개 파일의 `tools:` 라인 diff 부재 확인.

### 1.1 C-1 교정 문언 (so-architect.md 63행 치환)

현행:

```text
- Only write to `specs/SPEC-*.arch.md` — do not write to any other path
```

교체:

```text
- File-write policy: create files only at `specs/SPEC-*.arch.md`. The only permitted Edit outside that is the `Status:` line of `specs/SPEC-{NNN}-{slug}.md` (set it to `Architected` when you finish a non-preview design). Do not write or edit any other path.
```

### 1.2 so-architect Bash 제한 섹션 (신설, sentinel 문구 포함)

```markdown
## Bash Usage Restrictions

Bash is for **feasibility verification only** — you design, you do not build.

- 허용: 읽기/검증 목적 명령만 — `ls`, `cat`, 버전 확인, `--dry-run`, `validate`, `git status` / `git log` / `git diff` (읽기), 테스트 러너 실행
- 금지: 저장소 파일 변경, `git add` / `git commit` / `git push` / `git mv` / `git rm`, 패키지 설치, 네트워크 쓰기
- 임시 산출물이 필요하면 세션 scratchpad 디렉터리만 사용한다
- **so-spike와의 경계**: 단일 명령으로 수초 내 확인 가능한 것(버전, 파일 존재, `--dry-run`, `validate`)은 직접 실행한다. 픽스처 구성·다단계 셋업·상태 변경 실험이 필요하면 직접 하지 말고 미검증 가정 보고 형식(R5)으로 **스파이크를 요청**한다 — 저장소 불변 계약을 지키는 것은 so-spike의 임무다.
```

### 1.3 미검증 가정 보고 섹션 (reviewer·architect 공통 — 문구 동일 유지)

두 파일에 **같은 문구**로 넣는다 (`check_unverified_assumption_format`이 두 파일을 같은 sentinel로 grep).

```markdown
## 미검증 가정 보고 (Unverified Assumptions)

실측 없이 참으로 가정한 것이 있으면 아래 3열 표로 보고한다. 각 항목은 3열을 **모두** 채운다:

| 가정 내용 | 거짓일 경우 무너지는 것 | 제안 측정 방법 |
| --------- | ----------------------- | -------------- |

- **거짓일 경우 무너지는 것**: 특정 R번호, AC, 또는 설계 결정을 지목한다. 지목할 수 없으면 스파이크 대상이 아니라 일반 리스크로만 기재한다.
- **제안 측정 방법**: 몇 분 안에 실행 가능한 수준으로 구체적으로 쓴다. 그 수준으로 기술할 수 없으면 스파이크 대상이 아니라 일반 리스크로 기재한다.
- 미검증 가정을 근거로 승인이나 판정을 유보하지 말 것 — 위 형식으로 보고하고 오케스트레이터에 **스파이크를 요청**할 것.
```

### 1.4 so-reviewer 영속화·대조 섹션 (신설, sentinel 문구 포함)

```markdown
## Review Persistence

- 매 검토 완료 시 리뷰 전문을 `specs/SPEC-{NNN}-{slug}.review-v{N}.md`로 저장한다. `N`은 기존 `review-v*` 파일의 최대 번호 + 1 (없으면 1).
- Write는 `specs/SPEC-*.review-v*.md` 경로에만 사용한다 — SPEC 본문 변경은 기존대로 `Status:` 라인 Edit만.
- 리뷰 전문을 SPEC 본문에 인라인으로 삽입하는 것을 금지한다.

## 이전 리뷰 대조

- 검토 시작 시 기존 `review-v*` 파일을 모두 읽는다.
- 리뷰 출력에 **"이전 라운드 지적 추적"** 섹션을 포함한다 — 각 항목: 흡수됨 / 미해결 / 의도적 기각 + 근거. 이전 리뷰 파일이 없으면 "대조 대상 없음(v1)"으로 명기한다.
- 자가 점검: 이번 라운드에서 새로 제기하는 지적이 이전 리뷰 파일에 없었다면 그 이유(새 정보 / 이전 누락)를 명시한다.
```

---

## 2. so-spike.md 전문 초안

SPEC-001 V0 스파이크 관행(스켈레톤을 scratchpad에 구성 → `claude -p`로 측정 → 확정 사실표 반환, 저장소 무변경)의 제도화.
참조 패턴: so-auditor (stateless, 보고 전용, sonnet). 아래 초안을 그대로 `.claude/agents/so-spike.md`로 저장한다.

````markdown
---
name: so-spike
description: Verification spike agent. 미검증 가정을 scratchpad에서 실측하여 확정 사실표(양성/음성/측정불능)로 반환한다. 저장소 불변 — 저장소 파일을 절대 변경하지 않는다. Stateless, SPEC status 갱신 없음.
tools: Read, Grep, Glob, Bash, Write, Skill
model: sonnet
permissionMode: default
maxTurns: 30
skills:
  - so-foundation
---

You are the **Spike Agent** in the SO-ADK pipeline.

Your job is to convert **unverified assumptions into measured facts**. Reviewer and Architect report assumptions; the Orchestrator sends them to you; you measure and return a fact table. You never guess — a fact you could not measure is reported as `측정불능`, not as a fact.

## 입력 계약 (Input Contract)

호출 프롬프트는 가정 목록과 F 시작 번호를 포함해야 한다. 각 가정 항목은 4개 필드를 모두 갖춘다:

| 필드 | 내용 |
| ---- | ---- |
| 가정 ID | A1, A2, ... (호출자가 부여) |
| 가정 내용 | 참이라고 가정된 명제 |
| 거짓일 경우 무너지는 것 | 특정 R번호·AC·설계 결정 |
| 제안된 측정 방법 | 몇 분 내 실행 가능한 구체적 절차 |

필드가 누락된 항목은 측정하지 말고 "입력 계약 위반"으로 표기해 반환한다. 목록 전체가 `maxTurns` 내 완료 불가능한 규모로 판단되면, 측정 착수 **전에** 처리 가능한 항목 수를 보고하고 나머지는 측정불능(사유: 배치 초과)으로 표기한다 — 1배치는 maxTurns 내 완료 가능한 규모여야 한다.

## 출력 계약 (Output Contract) — 확정 사실표

각 가정에 대해 사실표 행을 반환한다. F번호는 호출 프롬프트가 지정한 시작 번호부터 연속 부여한다 (SPEC의 기존 확정 사실과 연속).

| F{n} | 판정 | 실측 근거 | SPEC 반영 지점 |
| ---- | ---- | --------- | -------------- |

- **판정**은 3값: `양성` (가정이 참으로 측정됨) / `음성` (가정이 거짓으로 측정됨) / `측정불능` (측정하지 못함 — 사유 명기: 턴 소진, 환경 부재, 방법 실패 등)
- **실측 근거**: 실행한 명령과 관찰한 출력. 재현 가능해야 한다.
- 측정하지 못한 것을 측정한 것처럼 보고하는 것을 **금지**한다. `측정불능`은 실패가 아니라 정직한 보고다.
- 턴 소진이 임박하면 남은 항목을 측정불능(사유: 턴 소진)으로 표기하고 **부분 사실표라도 반드시 반환**한다 — 빈손 종료는 전 배치 측정불능 처리를 유발한다.

## 저장소 불변 계약 (Repository Invariance Contract)

1. **기준선 기록**: 스파이크 시작 시 가장 먼저 `git status --porcelain`을 실행하고 출력 전문을 기록한다.
2. 모든 픽스처·스켈레톤·임시 파일은 **세션 scratchpad 디렉터리에서만** 생성한다. Write 툴도 scratchpad 경로에만 사용한다.
3. Write·Bash로 저장소 경로를 변경하는 것을 금지한다 — 파일 생성·수정·삭제, `git add` / `git commit` / `git mv` / `git rm` 전부 포함. `git status` / `git log` / `git diff` 등 읽기 명령만 허용한다.
4. **기준선 대조**: 종료 직전 `git status --porcelain`을 재실행한다. **시작 시점 출력과 동일하지 않으면 스파이크 실패로 보고**하고, 무엇이 달라졌는지 명시한다. (종료 시점 출력이 비어 있어야 하는 것이 아니다 — 파이프라인 정상 운용 중에는 SPEC 파일 등이 이미 untracked/modified 상태다.)
5. 성공·실패와 무관하게 시작·종료 양쪽 `git status --porcelain` 출력을 보고에 포함한다.
6. 외부 상태를 변경하는 네트워크 작업(push, publish, deploy) 금지. 측정에 필요한 패키지 설치는 scratchpad 내 로컬 설치만 허용, 전역 설치 금지.

## Process

1. `git status --porcelain` 기준선 기록
2. 각 가정: 제안된 측정 방법을 scratchpad에서 수행 (`claude -p` 호출, 픽스처 구성, 러너 실행 등)
3. 관찰 결과 → 판정 (양성/음성/측정불능) + 실측 근거 기록
4. `git status --porcelain` 재실행 → 기준선 대조
5. 확정 사실표 + 양쪽 기준선 출력 반환

## Rules

- **SPEC status를 변경하지 않는다** — stateless (so-auditor와 동일 부류)
- 측정 결과에 대한 해석·권고는 최소한으로 — 판정과 근거가 산출물이다. SPEC 반영은 so-planner의 임무다
- 한 항목의 측정이 2~3분을 크게 초과할 것으로 보이면 측정불능(사유: 비용 초과)으로 표기하고 다음 항목으로 넘어간다
- 측정 중 발견한 **요청받지 않은 사실**이 배치 내 다른 가정의 판정을 바꾸면 함께 보고한다 (별도 F번호, "부수 관찰" 표기)
````

**설계 근거 (frontmatter)**:

- `model: sonnet` — SPEC R4 명세. 측정은 판단이 아니라 실행이다
- `maxTurns: 30` — C-3 반영. so-scaffold/preflight/performance와 동급
- `effort` 필드 없음 — 현행 sonnet 에이전트 전원이 effort 미보유 (opus/fable만 보유). 관행 준수
- `permissionMode: default` — 모든 Bash/Write가 권한 게이트 통과 (지침 위반 시 최종 안전장치)
- `skills: so-foundation`만 — so-context 불필요 (측정 방법이 입력으로 주어지므로 코드베이스 탐색 임무 없음)

---

## 3. 오케스트레이터 Step 3.7 제어 흐름

`.claude/so-orchestrator.md`의 Step 3.5와 Step 4 사이에 신설한다.

### 3.1 흐름도 (C-3·C-4 위치 명시)

```text
Reviewer 또는 Architect 보고 수신
  │
  ├─ 보고에 "미검증 가정" 3열 완비 항목 있음? ─ 없음 → 기존 흐름 (Step 4 등)
  │    (오케스트레이터 재필터: 2열에 R/AC/설계결정 미지목 or 3열이 구체적
  │     측정 방법이 아니면 → 일반 리스크로 간주, 스파이크 대상 제외 — N-3)
  │
  ├─ 이 SPEC의 스파이크 배치 사용 횟수 ≥ 2? ─ 예 → ⏸️ 사용자 보고 + 지시 요청 (하드 캡)
  │
  └─ so-spike 호출 (1배치 = 가정 목록 전체 + F 시작 번호 = SPEC 기존 F 최댓값+1)
       │
       ├─ 확정 사실표 반환됨
       │    │
       │    └─ so-planner 재호출: SPEC "확정 사실" 섹션에 병합 (F번호 연속)
       │         - 음성 판정 → 해당 R의 재설계를 강제 (리스크 격하 금지)
       │         - 측정불능 → "미해소 리스크"로 기재 (확정 사실 아님)
       │         ↓
       │       so-reviewer 재검토
       │         [C-4 사실 불변 원칙 — 양성·음성에만 적용]
       │         - 양성·음성: 새 측정 없이 재의문 불가, 블로커 재제기 불가
       │         - 측정불능: 미해소 리스크 — Reviewer는 계속 제기 가능
       │         - 측정불능 잔존 채 승인하려면 → 사용자에게 명시적 고지 후 확인
       │
       └─ 사실표 미반환 (크래시·세션 한도·maxTurns 소진 후 빈손 종료)
            [C-3 사망 분기]
            - 해당 배치의 모든 가정을 `측정불능`으로 간주
            - 배치는 소진된 것으로 카운트
            - ⏸️ 사용자에게 보고하고 지시를 요청 (자동 재시도 금지)
```

### 3.2 규칙 (오케스트레이터 본문에 명문화할 것)

1. **발동 시점**: Reviewer/Architect 보고 직후, Step 4 사용자 체크포인트 **전에** 자동 발동한다. 측정 가능한 가정을 안은 SPEC을 사용자에게 들이미는 것이 D3의 재발이다. 비용은 하드 캡(sonnet 1배치 ≤ 30턴, SPEC당 ≤ 2배치)으로 유계.
2. **루프 상한**: 스파이크 배치는 SPEC 1건당 **최대 2회**. 초과 필요 시 사용자 보고·지시. 스파이크 배치는 리뷰 리비전 상한(3회)에 **산입하지 않는다**.
3. **배치 구성**: 한 보고의 유자격 가정 전부를 1배치로 묶는다. Step 3.5 병렬 검토에서 Reviewer·Architect(preview)가 동시에 가정을 보고하면 **합집합-중복제거 후 1배치** (2배치 소모 아님).
4. **음성 후 흐름**: planner 병합 시 음성이 특정 R의 재설계를 강제하면 → planner가 해당 R 개정 → reviewer 재검토 → 기존 `.arch.md`가 그 R에 의존하면 so-architect 재호출로 갱신.
5. **Step 3.5와의 상호작용**: 독립 발동. 단, Step 3.5 진행 중 스파이크 결과로 planner가 SPEC을 수정하면 이는 "SPEC 변경"이므로 **preview `.arch.md`는 기존 규칙대로 폐기**하고, 재검토 통과 후 so-architect를 정식 호출한다. SPEC 변경이 확정 사실 섹션 추가뿐이고 음성이 없으면 preview 승격 규칙을 그대로 적용해도 된다 (설계 결정 — 사실 추가는 설계를 무효화하지 않는다).
6. **Agent Context Passing 표 추가 행** (sentinel: `writes scratchpad only`):

   ```text
   so-spike     → reads  가정 목록 + writes scratchpad only, no SPEC status update
   ```

7. **Full Pipeline 다이어그램 추가 행** (Greenfield 블록, [3]과 [3.5] 사이):

   ```text
   [3.7] so-spike     → 미검증 가정 실측 → 확정 사실표 (조건부, SPEC당 최대 2배치)
          ↑ Reviewer/Architect 보고에 3열 완비 가정이 있을 때 발동
   ```

---

## 4. tests/run-checks.sh 설계

### 4.1 경로 리졸버 (커밋 1 — structural, 동작 불변)

`REPO_ROOT` 결정 직후(현행 26행 뒤)에 삽입:

```bash
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
```

**치환 대상 5개 함수** (리뷰 실측과 일치 — 이 외에는 agents/orchestrator 하드코드 없음):

| 함수 | 현행 하드코드 | 치환 |
| ---- | ------------- | ---- |
| `check_frontmatter` (62행) | `"$REPO_ROOT"/.claude/agents/*.md` | `"$AGENTS_DIR"/*.md` |
| `check_new_agents_in_orchestrator` (110행) | `"$REPO_ROOT/.claude/so-orchestrator.md"` | `"$ORCH_FILE"` |
| `check_tester_outside_in_mode` (169행) | `"$REPO_ROOT/.claude/agents/so-tester.md"` | `"$AGENTS_DIR/so-tester.md"` |
| `check_architect_preview_mode` (186행) | `"$REPO_ROOT/.claude/agents/so-architect.md"` | `"$AGENTS_DIR/so-architect.md"` |
| `check_orchestrator_parallel_review` (203행) | `"$REPO_ROOT/.claude/so-orchestrator.md"` | `"$ORCH_FILE"` |

함수 주석(57행, 105행 등)의 `.claude/agents`·`.claude/so-orchestrator.md` 표현도 "agents 디렉터리" / "orchestrator 파일"로 갱신한다 (AC-R7b의 grep이 주석에 걸리는 것 방지 + 서술 정확성).

**의도적 하드코드 유지** (열린 질문 3 — SPEC-001 리베이스 시 처리 주체 결정 사항):
`check_settings_json_valid`(`.claude/settings.json`), `check_hook_*` 4종(`.claude/hooks/`). AC-R7b의 grep 패턴은 `\.claude/agents`와 `\.claude/so-orchestrator\.md`만 대상이므로 이들과 충돌하지 않는다. 커밋 1 메시지에 이 유지가 의도임을 명기한다.

### 4.2 신규 체크 8종 (AC 배정 = N-5 반영)

모든 신규 체크는 `$AGENTS_DIR` / `$ORCH_FILE` 경유 — 양 레이아웃에서 동작. sentinel 문구는 §1~§3의 문안과 **글자 단위로 일치**해야 한다 (Tester·Developer 공통 기준).

| 함수 | 대상 | grep 대상 (전부 충족) | AC |
| ---- | ---- | --------------------- | -- |
| `check_architect_bash_tool` | so-architect.md | `^tools:` 라인에 `\bBash\b`; 본문에 `허용: 읽기/검증 목적`, `금지: 저장소 파일 변경`, `scratchpad`, `스파이크를 요청` | AC-R1a, AC-R1b |
| `check_reviewer_write_tool` | so-reviewer.md | `^tools:` 라인에 `\bWrite\b` | AC-R2a |
| `check_reviewer_persistence` | so-reviewer.md | `review-v{N}` (리터럴, `grep -F`), `인라인으로 삽입하는 것을 금지`, `이전 라운드 지적 추적`, `새 정보 / 이전 누락` | AC-R2b, AC-R6d |
| `check_tool_grants` | 4개 파일 | `so-planner.md:Edit`, `so-designer.md:Edit`, `so-architect.md:Edit`, `so-quality.md:Write` — 각 `^tools:` 라인에서 `grep -qw` (word 경계 — `MultiEdit`의 `Edit` 오탐 없음) | AC-R1a, AC-R3a |
| `check_spike_agent` | so-spike.md | 파일 존재; `^maxTurns:` (C-3 갭 보완 — `check_frontmatter` 4필드 밖); `git status --porcelain` (`grep -F`), `측정불능`, `가정 ID`, `거짓일 경우 무너지는 것`, `기준선 대조` | AC-R4a, AC-R4b |
| `check_unverified_assumption_format` | reviewer + architect | 두 파일 각각: `미검증 가정`, `거짓일 경우 무너지는 것`, `제안 측정 방법`, `스파이크를 요청` | AC-R5a |
| `check_orchestrator_spike_path` | orchestrator | `Step 3\.7`, `so-spike`, `최대 2회`, `사실 불변`, `재설계를 강제`, `writes scratchpad only` (Context Passing 행 — AC-R6c 흡수), `\[3\.7\]` (다이어그램 행 — AC-R6c 흡수) | AC-R6a, AC-R6b, AC-R6c |
| `check_spike_in_install` | install.sh | `plugins/so-adk-core/agents` 디렉터리 존재 시 → `skip` (설치 방식 상이); 아니면 `grep -q so-spike install.sh` | AC-R4c |

참고: `check_frontmatter`는 `$AGENTS_DIR/*.md` glob이므로 so-spike.md를 **자동 포섭**한다 (AC-R4a의 "4필드 통과" — §8 A2로 실측 확인 필요).

### 4.3 N-7 판정 — AC-R7b는 기계 체크로 구현한다 (`check_no_hardcoded_agent_paths`, 9번째 함수)

**판정: awk 범위 배제 패턴을 재사용하여 상설 체크로 만든다.** 근거:

1. 수동 grep 1회 확인은 미래 체크 추가 시 하드코드 회귀를 못 잡는다 — 이 저장소가 막으려는 drift 클래스 그 자체
2. `check_install_calls_merge_in_normal_path`(406~418행)가 동일 문제(특정 블록 배제 후 grep)를 이미 푼 검증된 선례
3. 비용 ~15행. AC-R7c의 "신규 체크 8종 **포함** 전체 GREEN"은 상위집합을 허용한다

```bash
# check_no_hardcoded_agent_paths — 리졸버·자기 자신 밖에서 agents/orchestrator 하드코드 경로 부재 (AC-R7b)
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
```

**함정 2건 — 구현 시 반드시 지킬 것**:

- **자기 참조 오탐**: grep 패턴을 `\.claude/agents`처럼 쓰면 이 함수 자신의 소스 라인이 스캔에 걸려 영구 자가실패한다 (C-2와 같은 부류의 결함). 회피 이중 장치: (a) 패턴을 알터네이션 형태 `\.claude/(agents|so-orchestrator\.md)`로 작성 — 소스 텍스트에는 `.claude/(agents...`만 존재해 자기 매치 불가, (b) awk skip 범위에 함수 자신을 포함. 검증: §8 A3의 주입 테스트.
- **주석 배제**: `grep -vE '^[[:space:]]*#'` 선행 — 상단 매핑표·함수 주석의 서술이 오탐되지 않도록. (4.1의 주석 갱신과 이중 방어)

### 4.4 상단 AC↔함수 매핑표 갱신 (4~21행 규약 유지)

기존 15행 유지 + 아래 추가. Status 열은 커밋 시점 기준 GREEN만 기재 (규약 동일):

```text
# | AC-R1a/R1b (architect Bash+제한지침)   | check_architect_bash_tool          | GREEN  |
# | AC-R1a/R3a (툴 부여 4건)               | check_tool_grants                  | GREEN  |
# | AC-R2a (reviewer Write)                | check_reviewer_write_tool          | GREEN  |
# | AC-R2b/R6d (영속화+대조+자가점검)      | check_reviewer_persistence         | GREEN  |
# | AC-R4a/R4b (so-spike 존재+계약)        | check_spike_agent                  | GREEN  |
# | AC-R4c (install.sh AGENTS)             | check_spike_in_install             | GREEN  |
# | AC-R5a (미검증 가정 형식)              | check_unverified_assumption_format | GREEN  |
# | AC-R6a/R6b/R6c (Step 3.7 경로)         | check_orchestrator_spike_path      | GREEN  |
# | AC-R7b (하드코드 경로 부재)            | check_no_hardcoded_agent_paths     | GREEN  |
# | AC-R1c/R2c/R2d/R4d                     | 수동 스모크 — Smoke-Verified trailer| MANUAL |
# | AC-R3b (적정 10개 무변경)              | 수동 — merge-base diff 확인         | MANUAL |
# | AC-R7a (리졸버 전후 동일 GREEN)        | 커밋 1 전후 전체 실행 대조          | MANUAL |
# | AC-R7d (plugins 레이아웃 GREEN)        | SPEC-001 병합 후 스모크             | DEFER  |
```

실행부(454~468행)에 신규 9개 함수 호출 추가 (정적 검증 블록 뒤).

---

## 5. 커밋 시퀀스 (Tidy First — 구조/행위 분리)

착수 전: 롤백 앵커 `git tag pre-spec-002` (§7). 각 커밋은 `bash tests/run-checks.sh` 전체 GREEN에서만 수행.
RED 상태(신규 체크가 구현보다 먼저 존재)는 **작업 트리에서만** 존재하고 커밋되지 않는다 — 각 클러스터의 체크+구현이 함께 GREEN이 된 시점에 커밋.

| # | 유형 | 내용 | 커밋 시 GREEN 상태 |
| - | ---- | ---- | ------------------ |
| 1 | **structural** | 리졸버 2종 도입 + 5개 함수 치환 + 주석 경로 표현 갱신. `.claude/settings.json`·hooks 하드코드는 의도적 유지(메시지에 명기) | 기존 15종 전부, **커밋 전후 Summary 동일** (AC-R7a — 전후 출력을 커밋 메시지에 기록) |
| 2 | behavioral | 에이전트 5개 파일: R1(Bash+제한 섹션+C-1 치환)·R2(Write+영속화·대조 섹션)·R3(planner/designer/architect Edit, quality Write+지침)·R5(미검증 가정 섹션 2개 파일) + 신규 체크 5종(`check_architect_bash_tool`, `check_reviewer_write_tool`, `check_reviewer_persistence`, `check_tool_grants`, `check_unverified_assumption_format`) + 매핑표 5행 | 15 + 5 = 20종 |
| 3 | behavioral | `so-spike.md` 신설 + `install.sh` AGENTS 배열 + 신규 체크 2종(`check_spike_agent`, `check_spike_in_install`) + 매핑표 2행 | 20 + 2 = 22종 (check_frontmatter가 so-spike 자동 포섭 — A2 확인 지점) |
| 4 | behavioral | 오케스트레이터: Step 3.7 + Context Passing 행 + 다이어그램 행 + `check_orchestrator_spike_path` + 매핑표 1행 | 22 + 1 = 23종 |
| 5 | behavioral | `check_no_hardcoded_agent_paths` + 매핑표 1행 (+ 주입 테스트 A3 수행 기록) | 23 + 1 = 24종 |
| 6+ | 스모크 증거 | 수동 스모크 AC-R1c → AC-R2c → AC-R2d → AC-R4d 수행 후 각각 trailer `Smoke-Verified: AC-R{...}` 커밋 (N-4, SPEC-001 R11(e) 규약). AC-R4d는 커밋 3 이후 언제든 가능 | 24종 유지 |

**의존 순서 근거**: 커밋 3(so-spike 실체) → 커밋 4(오케스트레이터가 so-spike를 라우팅) — 라우팅이 실체 없는 에이전트를 가리키는 순간이 없다. 커밋 2의 에이전트들이 스파이크를 "요청"하는 것은 오케스트레이터 반영 전에도 안전하다 (보고 형식일 뿐, 호출 주체는 오케스트레이터).

**AC-R3b 확인 시점**: 커밋 5 후 `git diff $(git merge-base HEAD main)..HEAD -- .claude/agents/`로 적정 10개 파일 `tools:` 라인 무변경 확인 (so-quality 리뷰 단계에서 재확인).

---

## 6. 열린 질문 2 판정 — so-spike의 `Write`는 **유지한다**

| 관점 | 판단 |
| ---- | ---- |
| 능력 증분 | **0** — Bash 보유 시점에 리다이렉션·heredoc으로 임의 파일 생성이 이미 가능하다. Write 제거는 능력을 줄이지 않고 표현 수단만 줄인다 |
| 가시성 | Write 호출은 트랜스크립트와 권한 시스템에 **경로가 1급으로 노출**된다. heredoc 속 경로보다 사후 감사·권한 판단이 쉽다 — 제거가 오히려 관측성을 낮춘다 |
| 실용 | SPEC-001 V0 관행(스켈레톤 플러그인 구성)은 다중 파일·구조화 콘텐츠 생성이다. heredoc 강제는 이스케이프 오류로 측정 자체를 오염시킬 수 있다 |
| 안전장치 | 저장소 불변은 툴 부재가 아니라 **계약(§2 기준선 대조) + permissionMode: default**가 보장한다. Reviewer도 "위험 증분 미미, 유지 반대 안 함" |

본문 규칙 "Write 툴도 scratchpad 경로에만 사용한다"(§2 계약 2항)로 경로를 제한한다.

---

## 7. 셀프 호스팅 리스크 — 롤백 경로와 안전 적용 순서

이 SPEC은 파이프라인이 자기 자신을 수정한다. 실패 모드와 방어:

### 7.1 리스크 매트릭스

| 리스크 | 발생 지점 | 방어 |
| ------ | --------- | ---- |
| frontmatter 파손 → 에이전트 로드 실패 → 파이프라인 정지 | 커밋 2, 3 | `tools:` 라인은 전체 재작성 아닌 **라인 단위 Edit**. `check_frontmatter` + PostToolUse 훅(`post-edit-check.sh`)이 편집 직후 검출 |
| 검증기(run-checks.sh) 자체 파손 → 이후 모든 커밋의 GREEN 판정 불능 | 커밋 1 | 착수 전 기준선 실행 기록(§8 A1) → 치환 후 `bash -n tests/run-checks.sh` + 재실행 → **Summary 라인 문자 단위 대조** (AC-R7a). 검증기 변경과 피검증물 변경을 같은 커밋에 절대 섞지 않음 (커밋 1은 run-checks.sh 단독) |
| C-1 치환 실수 → architect가 SPEC status 갱신 불능 상태 지속 | 커밋 2 | 치환은 §1.1 확정 문언 복사. 스모크 AC-R1c에서 행동 확인 |
| 오케스트레이터 파손 → **다음 세션**부터 라우팅 오동작 (CLAUDE.md import) | 커밋 4 | 오케스트레이터를 마지막 behavioral 커밋으로 배치. 커밋 후 `check_orchestrator_spike_path` + 기존 `check_orchestrator_parallel_review` GREEN 확인. 현재 세션은 구버전 메모리로 동작하므로 진행 중 파이프라인은 영향 없음 |
| 진행 중 세션과 파일의 불일치 (에이전트 정의는 호출 시점에 재로드됨) | 커밋 2 이후 | **의도된 동작** — 본 SPEC의 후속 라운드에서 reviewer가 즉시 review-v 파일을 직접 저장하게 되는 것 자체가 스모크. 단, 각 커밋이 원자적 GREEN이므로 중간 상태가 노출되지 않음 |
| install.sh 오류 → curl 설치 사용자 파급 | 커밋 3 | 1줄 배열 추가뿐. 기존 `check_new_agents_in_install` + 신규 `check_spike_in_install` GREEN |

### 7.2 롤백 경로

- **앵커**: 커밋 1 전에 `git tag pre-spec-002` (main 클린 상태 — 현재 git status clean 확인됨).
- **부분 롤백**: 커밋별 원자 revert — `git revert <sha>`. 역의존 1건만 주의: **커밋 4(오케스트레이터)를 revert하지 않고 커밋 3(so-spike)만 revert하면 라우팅이 유령 에이전트를 가리킨다** → 3을 되돌리려면 4를 먼저 revert. 커밋 1(structural)은 단독 revert 안전 (리졸버는 폴백 동작이므로 이후 커밋의 신규 체크와도 독립).
- **전체 롤백**: `git reset --hard pre-spec-002` (미푸시 시) 또는 `git revert <c5>..<c1>` (푸시 후). 런타임 상태·DB·마이그레이션이 없으므로 **파일 롤백 = 완전 롤백**. 유일한 저장소 밖 파급은 curl 설치 사용자의 install.sh인데, 이는 main 푸시 이후에만 노출된다.
- **검증기 사망 시 최후 수단**: run-checks.sh가 실행 불능이면 `git checkout pre-spec-002 -- tests/run-checks.sh`로 검증기만 복원 후 재시도.
- git 조작(tag/commit/revert)은 사용자 승인 하에 수행한다 (프로젝트 규칙).

---

## 8. 미검증 가정 (R5 형식 — 오케스트레이터에 스파이크/직접 측정 요청)

설계자에게 Bash가 없어 실측하지 못했다. 전부 단일 명령 수준이므로 so-spike 1배치 또는 오케스트레이터 직접 실행으로 수초 내 확정 가능하다.

| ID | 가정 내용 | 거짓일 경우 무너지는 것 | 제안 측정 방법 |
| -- | --------- | ----------------------- | -------------- |
| A1 | 현재 main에서 `tests/run-checks.sh`가 전체 GREEN(exit 0)이다 | AC-R7a의 "도입 전과 동일하게 전체 GREEN" — 기준선이 RED면 커밋 1의 전후 대조 자체가 불성립 | `bash tests/run-checks.sh; echo $?` — Summary 라인과 exit code 기록 (이 기록이 곧 AC-R7a의 '전' 기준선) |
| A2 | `check_frontmatter`의 glob이 신설 so-spike.md를 자동 포섭하며, §2 초안의 frontmatter가 4필드 검사를 통과한다 | AC-R4a ("기존 check_frontmatter 자동 포섭") + 커밋 3의 GREEN | §2 초안을 scratchpad가 아닌 실제 경로에 만들기 전, scratchpad에 사본 디렉터리를 구성해 체크 로직만 재현 실행 — 또는 커밋 3 작업 트리에서 `bash tests/run-checks.sh` 1회 (RED→GREEN 전환 관찰) |
| A3 | §4.3의 awk 배제 + 알터네이션 grep이 (a) 자기 자신에 오탐하지 않고 (b) 주입된 하드코드를 실제로 잡는다 | AC-R7b + N-7 판정(§4.3) — (a) 거짓이면 영구 자가실패(C-2 부류), (b) 거짓이면 체크가 장식 | scratchpad에 run-checks.sh 사본 두 벌: 원본 → 매치 0 확인; 임의 함수에 `x="$REPO_ROOT/.claude/agents"` 1줄 주입 → 매치 1 확인 |
| A4 | `grep -qw Edit`가 `MultiEdit`에 매치하지 않는다 (word 경계가 인접 word 문자를 차단) | `check_tool_grants`의 정확성 — 거짓이면 quality의 기존 MultiEdit만으로 Edit 요건이 오통과하는 유사 사례 발생 가능 | `echo "tools: Read, MultiEdit, Bash" \| grep -qw Edit; echo $?` → 1 기대; `echo "tools: Read, Edit" \| grep -qw Edit; echo $?` → 0 기대 |

일반 리스크 (스파이크 대상 아님 — 측정 방법을 분 단위로 특정 불가): sentinel 문구가 향후 에이전트 본문 리라이트에서 깨질 가능성 — 매핑표 주석과 §4.2 표가 유일한 방어이며, 문구 변경 시 체크 동시 갱신 규율에 의존한다.

---

## 9. Key Design Decisions 요약

1. **AC-R7b를 상설 기계 체크로 격상** (N-7 위임 판정) — 검증된 awk 배제 선례 재사용, 자기 참조 오탐은 알터네이션 패턴 + 자기 배제 이중 장치로 차단 (§4.3)
2. **so-spike Write 유지** (열린 질문 2 위임 판정) — 능력 증분 0, 관측성은 오히려 상승, 불변 보장은 계약+권한 게이트의 몫 (§6)
3. **Step 3.7은 사용자 체크포인트 전 자동 발동** — 측정 가능한 가정을 안은 SPEC을 사용자에게 묻는 것이 D3 재발. 비용은 2배치×30턴 하드 캡으로 유계 (§3.2-1)
4. **부분 사실표 의무** — 턴 소진 시 빈손 종료 대신 잔여 항목 측정불능 표기 후 반환. C-3 사망 분기의 발생 빈도 자체를 낮춤 (§2 출력 계약)
5. **check_spike_agent에 `^maxTurns:` 검사 추가** — `check_frontmatter` 4필드 갭(C-3에서 실증)을 신규 체크가 국소 보완
6. **커밋 순서 = 검증기 → 능력 → 실체 → 라우팅 → 자가 체크** — 라우팅이 유령 에이전트를 가리키는 순간이 없고, 각 커밋이 원자 GREEN·원자 revert 가능 (§5, §7)
7. **의도적 하드코드 유지** — settings/hooks 체크의 `.claude/` 경로는 리졸버 범위 밖 (열린 질문 3의 결정은 SPEC-001 리베이스 주체에게 위임, 커밋 1 메시지에 명기)

---

## 다음 단계 (오케스트레이터)

1. **SPEC Status 갱신 위임**: `specs/SPEC-002-pipeline-verification-gap.md`의 `Status: Approved` → `Architected` — 현행 so-architect는 Edit 부재 + 쓰기 제약으로 직접 갱신 불가 (C-1 실황)
2. §8의 A1~A4를 so-spike(미존재하므로 이번엔 오케스트레이터 직접) 측정 → 음성 발견 시 본 설계 §4.3/§5 재조정
3. so-tester 호출 — §4.2/§4.3의 체크 9종을 RED로 작성 (sentinel 문구는 본 문서 §1~§3 문안 기준)
