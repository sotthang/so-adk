# SPEC-002: 파이프라인 검증 격차 해소 — 툴 권한 정정 + 검증 스파이크 편입 + 리뷰 산출물 보존

**Status**: Approved
**Created**: 2026-08-21
**Revised**: 2026-08-21 (v1.1 — 승인 조건 C-1~C-4 + N-1~N-6 + Goal 범위 정합 반영. 오케스트레이터 직접 반영, 재검토 불요 판정에 따름)
**Reviewed**: 2026-08-21 (v1 검토 — **조건부 Approved**. 착수 전 반영 필수인 문언 정정 4건(C-1~C-4)이 있다. 리뷰 전문: `SPEC-002-pipeline-verification-gap.review-v1.md` — Reviewer에 Write 툴이 없어 파일 생성 실패, 오케스트레이터가 대신 저장. 이 사건 자체가 R2의 추가 실증 근거다)

> **승인 조건 C-1~C-4 — 반영 완료 (v1.1, 2026-08-21)**
>
> Reviewer가 교정문을 확정 형태로 제시하고 "재검토 불요"로 판정하여, 오케스트레이터가 직접 반영했다.
> 함께 반영: N-1(경로 충돌 서술 정정 + 카운트 3개소 구체화), N-2(architect Bash ↔ so-spike 경계),
> N-3(스파이크 2차 비용 필터), N-4(수동 스모크 trailer 규약), N-5(AC↔체크 함수 배정), N-6(AC-R3b 기준 ref),
> 열린 질문 1(Goal 범위 정합). 상세는 리뷰 전문과 아래 개정 이력 참조.
>
> 미반영(구현 시 판단 위임): N-7(AC-R7b는 `check_install_calls_merge_in_normal_path`의 awk 범위 배제 패턴 재사용),
> 열린 질문 2(so-spike의 Write는 Bash 리다이렉션으로 대체 가능한 편의 — 유지/제거는 구현자 판단),
> 열린 질문 3(리베이스 시 `check_settings_json_valid`·`check_hook_*` 4종의 처리 주체).

## Goal

SPEC-001 진행 중 실증된 하네스 구조 결함 3계열 — (1) 검증 수단 없는 실현성 판정(so-architect Bash 부재), (2) 산출물을 남길 수 없는 리뷰(so-reviewer Write 부재, 리뷰 미보존으로 인한 대조 불가 실손 포함), (3) 미검증 가정에서 검증으로 넘어가는 경로 부재(3라운드 내내 오케스트레이터가 수동 측정) — **및 전수 감사로 드러난 잔여 툴 권한 정정(R3)** 을 고쳐, 파이프라인이 **가정을 측정으로 승격시키는 능력**을 스스로 갖추게 한다.

## Background — 실증 근거 (추측 아님)

| # | 결함 | 실제 발생한 사건 (SPEC-001) |
| - | ---- | -------------------------- |
| D1 | so-architect `tools: Read, Grep, Glob, Write, Skill` — 실행 수단 전무 | 1차 설계에서 핵심 가정 4건에 "실기기 검증 필요"로 판정 유보. 오케스트레이터가 대신 검증 |
| D2 | so-reviewer `tools: Read, Grep, Glob, Edit, Skill` — 파일 생성 불가 | 3차 검토에서 `review.md` 별도 파일 생성 실패 → 리뷰 전문을 SPEC 본문에 인라인 → 오케스트레이터가 사후 분리 |
| D3 | 미검증 가정 → 스파이크 경로 부재 | v1 블로커 4건 중 2건, v2 중대 2건이 전부 미검증 가정. 측정으로 즉시 해소. 특히 v2의 **음성 1건**(F12)은 R11 전면 재설계를 강제 — 측정 없이 승인했다면 `git mv` 완료 후에야 발견했을 결함 |
| D4 | 리뷰 산출물 미영속화 (D2의 귀결) | v1 리뷰 미보존 → 3차 검토에서 "v1 지적 #9 흡수/누락 대조 불가" → SPEC-001은 해당 항목을 "확인 불가"로 표기한 채 승인됨 |

D4는 D2가 원인이므로 별도 요구사항으로 분리하지 않고 **R2의 수용 기준으로 흡수**한다.

### 툴 권한 전수 감사 결과 (2026-08-21, `.claude/agents/` 15개 파일 실측)

| 에이전트 | 현재 tools | 임무 대비 판정 |
| -------- | ---------- | -------------- |
| so-planner | Read, Grep, Glob, Write, WebSearch, Skill | **부족**: SPEC 수정 루프(리비전)에서 부분 수정 필요 — Edit 없음. Write 전체 덮어쓰기는 클로버 위험 |
| so-reviewer | Read, Grep, Glob, Edit, Skill | **부족 (D2)**: 리뷰 파일 생성 불가 — Write 없음 |
| so-designer | Read, Grep, Glob, Write | **부족**: SPEC status → `Designed` 갱신 임무가 있는데 Edit 없음 |
| so-architect | Read, Grep, Glob, Write, Skill | **부족 (D1)**: 실현성 검증용 Bash 없음. 또한 status → `Architected` 갱신 임무 대비 Edit 없음 |
| so-scaffold | Read, Grep, Glob, Write, Skill | 적정 (status 갱신 임무 없음) |
| so-tester | Read, Grep, Glob, Write, Edit, Bash, Skill | 적정 |
| so-developer | Read, Grep, Glob, Write, Edit, MultiEdit, Bash, Skill | 적정 |
| so-quality | Read, Grep, Glob, Edit, MultiEdit, Bash, Skill | **부족**: Extract Module/Class 등 파일 신설형 리팩토링에 Write 필요 |
| so-docs | Read, Grep, Glob, Edit, Write, Bash, Skill | 적정 (archive 이동용 Bash 보유) |
| so-debugger | Read, Grep, Glob, Bash, Write, Edit, Skill | 적정 |
| so-explainer | Read, Grep, Glob, Skill | 적정 (읽기 전용 임무) |
| so-security | Read, Grep, Glob, Bash, Skill | 적정 (보고 전용) |
| so-preflight | Read, Grep, Glob, Bash, Skill | 적정 |
| so-performance | Read, Grep, Glob, Bash, Skill | 적정 (보고 전용) |
| so-auditor | Read, Grep, Glob, Bash | 적정 (읽기 전용 + Skill 미보유는 frontmatter `skills:` 프리로드로 충분) |

**부여하지 않는 것** (최소 권한 원칙 — 요청 방향의 "전수 점검" 결과 의도적 제외):

- so-designer에 Skill 툴 — 필요 스킬(so-foundation, so-context)은 frontmatter `skills:`로 프리로드됨. 추가 스킬 호출 임무 없음
- so-explainer/so-security/so-performance/so-auditor에 쓰기 계열 — 보고 전용 임무 유지가 안전장치
- so-reviewer에 Bash — 측정은 so-spike의 임무(R4). Reviewer가 직접 측정하면 판정자와 측정자가 섞여 검토 독립성이 깨지고, opus 리뷰 턴이 측정에 소모됨

## Requirements

#### R1 — so-architect에 Bash 부여 (실현성 검증 능력)

- `.claude/agents/so-architect.md` frontmatter `tools:`에 `Bash`를 추가한다.
- 본문에 Bash 사용 제한 지침 섹션을 추가한다:
  - 허용: 읽기/검증 목적 명령만 — 예: `ls`, `cat`, 버전 확인, `--dry-run`, `validate`, `git status/log/diff`(읽기), 테스트 러너 실행
  - 금지: 저장소 파일 변경, `git add/commit/push/mv/rm`, 패키지 설치, 네트워크 쓰기
  - 임시 산출물이 필요하면 세션 scratchpad 디렉터리만 사용
  - **so-spike와의 경계 (N-2)**: 단일 명령으로 수초 내 확인 가능한 것(버전, 파일 존재, `--dry-run`, `validate`)은 직접 실행한다. **픽스처 구성·다단계 셋업·상태 변경 실험이 필요하면 직접 하지 말고 R5 형식으로 스파이크를 요청**한다 — 저장소 불변 계약을 지키는 것은 so-spike의 임무다. 경계가 없으면 R1이나 R4 중 하나가 사문화된다
- `permissionMode: default`를 **유지**한다 — 모든 Bash 호출이 권한 시스템을 통과하는 것이 지침 위반 시의 최종 안전장치다.
- **파일 쓰기 제약 문언 정정 (C-1)**: `.claude/agents/so-architect.md:63`의 현행 문언 (`Only write to specs/SPEC-*.arch.md — do not write to any other path`)은 R3이 부여하는 status 갱신 Edit과 **정면 충돌**한다(status는 `specs/SPEC-{NNN}-{slug}.md`에 있다). 다음으로 **교체**한다: **`.arch.md` 신규 작성 + `specs/SPEC-{NNN}-{slug}.md`의 Status 라인 Edit만 허용, 그 외 경로 금지.**

#### R2 — so-reviewer에 Write 부여 + 리뷰 산출물 보존 강제 (D2·D4)

- `.claude/agents/so-reviewer.md` frontmatter `tools:`에 `Write`를 추가한다.
- 본문에 리뷰 영속화 지침을 추가한다:
  - 매 검토 완료 시 리뷰 전문을 `specs/SPEC-{NNN}-{slug}.review-v{N}.md`로 저장한다. `N`은 기존 `review-v*` 파일의 최대 번호 + 1 (없으면 1)
  - Write는 `specs/SPEC-*.review-v*.md` 경로에만 사용한다 — SPEC 본문 수정은 기존대로 Edit(status 갱신)만
  - 리뷰 전문을 SPEC 본문에 인라인으로 삽입하는 것을 **명시적으로 금지**한다 (SPEC-001 3차에서 실제 발생한 오동작)
- 본문에 **이전 리뷰 대조 의무**를 추가한다: 검토 시작 시 기존 `review-v*` 파일을 모두 읽고, 리뷰 출력에 "이전 라운드 지적 추적" 섹션(각 항목: 흡수됨 / 미해결 / 의도적 기각 + 근거)을 포함한다. 이전 리뷰 파일이 없으면 "대조 대상 없음(v1)"으로 명기한다. — D4의 "대조 불가" 실손 재발 방지.

#### R3 — 감사 결과에 따른 잔여 툴 권한 정정

- `.claude/agents/so-planner.md` `tools:`에 `Edit` 추가 (SPEC 리비전 루프의 부분 수정).
- `.claude/agents/so-designer.md` `tools:`에 `Edit` 추가 (status → `Designed` 갱신).
- `.claude/agents/so-architect.md` `tools:`에 `Edit` 추가 (status → `Architected` 갱신 — R1과 같은 파일, 같은 커밋).
- `.claude/agents/so-quality.md` `tools:`에 `Write` 추가 (파일 신설형 리팩토링). 본문에 "Write는 기존 코드에서 추출한 새 파일 생성에만 사용, 신규 기능 파일 생성 금지" 지침 추가.
- 감사 표의 "적정" 판정 에이전트는 **변경하지 않는다**.

#### R4 — 검증 스파이크 에이전트 `so-spike` 신설

- `.claude/agents/so-spike.md`를 신설한다. frontmatter: `name: so-spike`, `description`(미검증 가정 실측 검증. 저장소 불변), `tools: Read, Grep, Glob, Bash, Write, Skill`, `model: sonnet`, `permissionMode: default`, **`maxTurns: 30`** (C-3 — 현행 15개 에이전트 전원이 `maxTurns`를 보유하는데 명세에서 누락돼 있었고, `check_frontmatter`는 4필드만 검사하므로 이 누락을 잡지 못한다), `skills: so-foundation`. **1배치는 `maxTurns` 내 완료 가능한 규모로 분할한다.**
- **입력 계약**: 가정 목록 — 각 항목은 `가정 ID / 가정 내용 / 거짓일 경우 무너지는 것 (R번호·AC·설계 결정) / 제안된 측정 방법`.
- **출력 계약**: 확정 사실표 행 — 각 항목은 `F{n} / 판정(양성·음성·측정불능) / 실측 근거(실행한 명령·관찰 결과) / SPEC 반영 지점`. 판정 `측정불능`을 허용한다 — 측정 못 한 것을 측정한 것처럼 보고하는 것을 금지한다 (SPEC-001 정직 표기 관행의 제도화).
- **저장소 불변 계약** (SPEC-001 V0 스파이크 관행의 제도화):
  - 모든 픽스처·스켈레톤·임시 파일은 세션 scratchpad 디렉터리에서만 생성한다
  - Write·Bash로 저장소 경로를 변경하는 것을 본문에서 명시적으로 금지한다
  - **기준선 대조 (C-2)**: 스파이크 **시작 시** `git status --porcelain`을 기록하고, **종료 시** 재실행하여 **시작 시점 출력과 동일하지 않으면 실패로 보고**한다. 양쪽 출력을 보고에 포함한다. — 종료 시점의 공백 여부를 보는 방식은 **정상 파이프라인에서 100% 오탐한다**: 스파이크 발동 시점(Reviewer/Architect 보고 직후)에 `specs/SPEC-*.md`는 방금 planner가 만들었거나 reviewer가 status를 고쳐 untracked/modified 상태이기 때문이다
- so-spike는 SPEC status를 변경하지 않는다 (stateless — so-auditor와 동일 부류).
- `install.sh`의 `AGENTS=(...)` 배열에 `so-spike`를 추가한다 (SPEC-002가 SPEC-001보다 먼저 병합되는 경우의 누락 버그 방지 — so-scaffold 누락 버그와 동일 클래스). SPEC-001이 먼저 병합된 경우 이 항목은 자동 소멸한다(디렉터리 통째 배포).

#### R5 — 미검증 가정 보고 표준 (Reviewer·Architect 출력 형식)

- `.claude/agents/so-reviewer.md`와 `.claude/agents/so-architect.md` 본문의 출력 형식에 "미검증 가정" 섹션을 추가한다. 각 항목은 다음 3열을 **모두** 채워야 한다:
  1. 가정 내용
  2. **거짓일 경우 무너지는 것** — 특정 R번호, AC, 또는 설계 결정을 지목. 지목할 수 없으면 스파이크 대상이 아니라 일반 리스크로만 기재 (비용 통제 — 모든 가정을 재지 않는다)
  3. 제안 측정 방법 (몇 분 안에 실행 가능한 수준으로 구체적으로). **측정 방법을 그 수준으로 기술할 수 없으면 스파이크 대상이 아니라 일반 리스크로 기재한다 (N-3 — 2차 비용 필터)**
- 두 에이전트 모두 "미검증 가정을 근거로 승인/판정 유보하지 말 것 — 위 형식으로 보고하고 오케스트레이터에 스파이크를 요청할 것"을 명시한다. (D1의 "유보로 끝남" 재발 방지)

#### R6 — 오케스트레이터에 스파이크 경로 편입 + 루프 상한

- `.claude/so-orchestrator.md`에 **Step 3.7 — Verification spike** 단계를 신설한다 (Step 3.5 복잡도 게이트와 독립적으로, Reviewer/Architect 보고 직후 발동):
  1. Reviewer 또는 Architect의 보고에 "무너지는 것"이 지목된 미검증 가정이 있으면 → `so-spike`를 가정 목록과 함께 호출
  2. so-spike의 확정 사실표를 받아 → `so-planner`를 재호출하여 SPEC의 "확정 사실" 섹션에 병합 (F번호 연속 부여, SPEC-001의 F1~F14 형식). **음성 판정 사실은 해당 R의 재설계를 강제한다** — 리스크 항목으로 격하 금지
  3. 병합 후 → `so-reviewer` 재검토
- **사실 불변 원칙 (C-4로 범위 한정)**: 확정 사실표의 **`양성`·`음성` 판정에만** 적용한다 — 이 두 판정은 새 측정 없이 재의문 대상이 될 수 없고 Reviewer는 다시 블로커로 제기할 수 없다. **`측정불능`은 사실이 아니라 미해소 리스크이며 Reviewer는 계속 제기할 수 있다.** 측정불능 항목이 남은 채 승인하려면 **사용자에게 명시적으로 고지**한다. — 범위를 한정하지 않으면 '스파이크 2회 모두 실패 → 측정불능 등재 → 재론 불가 → 미해소 위험을 안은 채 자동 승인'이라는 **검증 회피 경로**가 생긴다(C-3의 사망 분기와 겹칠 때 특히 위험).
- **스파이크 사망 분기 (C-3)**: so-spike가 확정 사실표를 반환하지 않고 종료하면(세션 한도 초과·크래시 등 — SPEC-001에서 so-architect가 실제로 세션 한도로 중단된 전례가 있다) 해당 배치의 **모든 가정을 `측정불능`으로 간주**하고, 배치를 소진 처리한 뒤 **사용자에게 보고하고 지시를 요청**한다.
- **루프 상한**: 스파이크 배치는 SPEC 1건당 최대 2회 (1배치 = 여러 가정 동시 측정 가능). 2회 초과 필요 시 사용자에게 보고하고 지시를 받는다. 기존 리뷰 리비전 상한 3회는 유지하며 스파이크 배치는 리비전 횟수에 산입하지 않는다.
- **Reviewer 자가 점검 상설화**: `.claude/agents/so-reviewer.md` 본문에 "이번 라운드에서 새로 제기하는 지적이 이전 리뷰 파일(R2의 대조 의무)에 없었다면 그 이유(새 정보 / 이전 누락)를 명시할 것"을 추가한다. — SPEC-001에서 오케스트레이터의 일회성 지시("승인 기준 자가 점검")로만 3라운드 수렴이 가능했던 것을 지침으로 제도화.
- Agent Context Passing 표와 Full Pipeline 다이어그램에 `so-spike` 행을 추가한다 (`reads 가정 목록 + writes scratchpad only, no SPEC status update`).

#### R7 — 테스트 하네스: 경로 리졸버 + 신규 체크 (SPEC-001 공존)

- `tests/run-checks.sh`에 경로 리졸버를 도입한다:

  ```bash
  # plugins/ 레이아웃(SPEC-001 적용 후)이 있으면 그것을, 없으면 기존 .claude/ 레이아웃을 사용
  resolve_agents_dir()        # plugins/so-adk-core/agents || .claude/agents
  resolve_orchestrator_file() # plugins/so-adk-orchestrator/agents/so-orchestrator.md || .claude/so-orchestrator.md
  ```

  기존 체크 함수의 `.claude/agents`·`.claude/so-orchestrator.md` 하드코드 경로를 전부 리졸버 경유로 치환한다. **이 치환은 동작 불변의 구조 변경이며 별도 선행 커밋으로 분리한다** (Tidy First).
- 신규 체크를 추가한다 (전부 현재 레이아웃과 SPEC-001 이후 레이아웃 양쪽에서 동작해야 함):
  - `check_architect_bash_tool` — so-architect frontmatter `tools:`에 `Bash` 포함
  - `check_reviewer_write_tool` — so-reviewer frontmatter `tools:`에 `Write` 포함
  - `check_reviewer_persistence` — so-reviewer 본문에 `review-v` 파일 저장 지침 + 이전 리뷰 대조 지침 존재
  - `check_tool_grants` — R3의 4건 (planner Edit, designer Edit, architect Edit, quality Write) frontmatter 확인
  - `check_spike_agent` — so-spike.md 존재 + frontmatter 4필드(기존 `check_frontmatter` 자동 포섭 확인) + 본문에 저장소 불변 계약(`git status --porcelain` 문구) 존재
  - `check_unverified_assumption_format` — reviewer·architect 본문에 "미검증 가정" 섹션 형식 존재
  - `check_orchestrator_spike_path` — 오케스트레이터에 so-spike 호출 경로 + 배치 상한(2회) 문구 존재
  - `check_spike_in_install` — `install.sh`에 `so-spike` 존재 (`plugins/` 레이아웃에서는 스킵 — 설치 방식이 다름)

## Out of Scope

- **SPEC-001의 플러그인 전환 자체** — 두 SPEC은 독립 진행. 본 SPEC은 경로 충돌 대비만 다룬다 (Technical Approach 참조)
- 오케스트레이터 인텐트 라우팅 테이블 개편, 에이전트 `model`/`effort` 조정
- 훅(`post-edit-check.sh`, `session-start-resume.sh`) 변경
- settings 수준의 Bash 명령 deny 규칙 배포 (`Bash(git push:*)` 등) — 사용자 환경 설정 영역. 지침 + permissionMode로 충분한지 운용 후 재평가
- so-spike의 병렬 다중 인스턴스 실행 최적화
- 과거 SPEC-001 리뷰 v1·v2의 소급 복원 (이미 소실됨 — 복원 불가를 인정)

## Technical Approach

### 변경 파일

| 파일 | 변경 | 요구사항 |
| ---- | ---- | -------- |
| `.claude/agents/so-architect.md` | tools에 Bash·Edit + Bash 제한 지침 + 미검증 가정 형식 | R1, R3, R5 |
| `.claude/agents/so-reviewer.md` | tools에 Write + 영속화·대조·자가점검 지침 + 미검증 가정 형식 | R2, R5, R6 |
| `.claude/agents/so-planner.md` | tools에 Edit | R3 |
| `.claude/agents/so-designer.md` | tools에 Edit | R3 |
| `.claude/agents/so-quality.md` | tools에 Write + 사용 제한 지침 | R3 |
| `.claude/agents/so-spike.md` | **신설** | R4 |
| `.claude/so-orchestrator.md` | Step 3.7 신설 + Context Passing 표 + 파이프라인 다이어그램 | R6 |
| `install.sh` | AGENTS 배열에 so-spike | R4 |
| `tests/run-checks.sh` | 리졸버 + 신규 체크 8종 | R7 |

### SPEC-001과의 경로 충돌 대응 (어느 쪽이 먼저 병합되든 동작)

> **전제 (N-1)**: 두 SPEC 모두 `tests/run-checks.sh`를 대규모로 수정하므로 **충돌은 회피 대상이 아니라 확정 사항**이다. 실질 해법은 **한쪽 병합 완료 후 다른 쪽을 리베이스**하는 것이다. 리베이스 시 SPEC-001 R7의 "기존 15개 전수 매핑표"는 SPEC-002의 신규 8종을 더해 23개가 되므로 **매핑표 갱신이 필요**하다. 또한 `check_settings_json_valid`·`check_hook_*` 4종은 `.claude/` 하드코드를 유지하는데 SPEC-001이 훅을 `plugins/so-adk-core/hooks/`로 옮기므로, 리베이스 시 이 4종의 처리 주체를 명확히 할 것(열린 질문 3).

- **SPEC-002 먼저 병합** — 위 표의 기존 경로(`.claude/`)에 그대로 적용. 이후 SPEC-001의 **디렉터리 단위 `git mv`** 는 파일을 나열하지 않으므로 신설된 `so-spike.md`를 자동 포섭한다. 단 두 가지를 SPEC-001 구현 시점에 반영해야 한다:
  1. SPEC-001 본문의 "에이전트 15개" 카운트가 16개로 변경됨 — **총 3개소**(N-1): (a) R1 구조도 주석, (b) R2·Background의 "에이전트 15개", **(c) R6 마이그레이션 래퍼의 고정 목록** ← 기능적으로 중요. 누락 시 curl 설치 사용자의 `.claude/agents/so-spike.md`만 레거시 경로에 고아로 남아, SPEC-001 R8이 경고한 "로컬 정의가 동명 플러그인 에이전트를 override"가 발동한다
  2. SPEC-001의 "본문 무수정" 불변식은 **SPEC-002 반영 후의 본문**을 기준선으로 삼는다 — 이동 커밋의 100% rename 판정에는 영향 없음
- **SPEC-001 먼저 병합** (N-1 — 종전 서술 정정) — SPEC-001 R7이 이미 `tests/run-checks.sh`를 `plugins/` 경로로 재작성하고 R9가 레거시 경로(`.claude/agents` 등)를 **삭제**하므로, R7의 리졸버는 **불필요해지므로 생략**하고 신규 체크 8종만 `plugins/` 경로 기준으로 추가한다. **AC-R7a·AC-R7b는 SPEC-002 선병합 시에만 적용되며, SPEC-001 선병합 시 AC-R7d로 대체된다.** (종전 서술 "리졸버가 자동 감지하므로 무수정 동작"은 부정확했다 — 리졸버의 폴백 대상 자체가 소멸한다.) R1~R6의 에이전트/오케스트레이터 수정은 리졸버와 같은 규칙으로 **구현 시점에 존재하는 경로**에 적용한다 (`plugins/so-adk-core/agents/`, `plugins/so-adk-orchestrator/agents/so-orchestrator.md`). so-spike 신설 위치도 `plugins/so-adk-core/agents/`. install.sh 변경(R4 마지막 항목)은 불필요해지므로 생략.
- 두 SPEC을 같은 시기에 병행 구현하지 않는다 — 한쪽 병합 완료 후 다른 쪽을 리베이스한다.

### 커밋 경계 (본 SPEC은 동작 변경이다)

- SPEC-001(구조 변경)과 달리 본 SPEC은 에이전트 능력과 파이프라인 단계를 바꾸는 **behavioral change**다. SPEC-001 커밋과 절대 섞지 않는다.
- 내부 분리: 커밋 1 (structural) — R7 리졸버 치환 (체크 동작 불변, 전후 전체 GREEN 확인). 커밋 2+ (behavioral) — 툴 부여·지침·so-spike·오케스트레이터·신규 체크.

### 패턴

- 신규 체크는 기존 `check_*` 함수 + 상단 매핑표 주석 형식을 따른다 (`tests/run-checks.sh` 기존 관행).
- so-spike 본문 구조는 so-auditor(stateless, 보고 전용)를 참조 패턴으로 삼되, scratchpad 작업 계약을 추가한다.

## Acceptance Criteria

> **수동 스모크 증거 기록 (N-4)**: "(수동 스모크)" 표기된 AC는 SPEC-001 R11(e)의 규약을 재사용한다 — 수행 후 커밋 메시지 trailer `Smoke-Verified: AC-...`를 남기고 `git log --grep`으로 선후를 기계 검증한다. trailer가 증명하는 것은 스모크 *선언*의 존재와 선후 관계이며, 통과 사실 자체는 자기 신고다.

기계 검증은 `tests/run-checks.sh` 실행으로 확인한다. 런타임 에이전트 행동은 정적 grep으로 강제 불가하므로 "(수동 스모크)"로 정직 표기한다.

### R1 — Architect Bash

- [ ] **AC-R1a** — Given so-architect 파일, When frontmatter `tools:` 라인을 grep, Then `Bash`와 `Edit`가 포함된다 (`check_architect_bash_tool`, `check_tool_grants`)
- [ ] **AC-R1b** — Given so-architect 본문, When Bash 제한 지침을 grep, Then 읽기/검증 전용 + 저장소 변경 금지 + scratchpad 문구가 존재한다 (`check_architect_bash_tool`에 흡수 — N-5)
- [ ] **AC-R1c** (수동 스모크) — Given 실행 검증이 필요한 가정을 포함한 SPEC, When so-architect를 호출, Then "실기기 검증 필요" 유보 대신 직접 실행 결과 또는 R5 형식의 스파이크 요청을 반환한다

### R2 — Reviewer Write + 영속화

- [ ] **AC-R2a** — Given so-reviewer 파일, When frontmatter `tools:` 라인을 grep, Then `Write`가 포함된다 (`check_reviewer_write_tool`)
- [ ] **AC-R2b** — Given so-reviewer 본문, When 영속화 지침을 grep, Then `review-v{N}` 파일 저장 규칙 + SPEC 본문 인라인 금지 + 이전 리뷰 대조 의무가 존재한다 (`check_reviewer_persistence`)
- [ ] **AC-R2c** (수동 스모크) — Given 임의 Draft SPEC, When so-reviewer가 검토를 완료, Then `specs/SPEC-{NNN}-{slug}.review-v1.md`가 실제 생성되고 SPEC 본문에는 리뷰 전문이 삽입되지 않는다
- [ ] **AC-R2d** (수동 스모크) — Given `review-v1.md`가 존재하는 SPEC의 재검토, When so-reviewer가 v2 검토를 완료, Then `review-v2.md`가 생성되고 출력에 "이전 라운드 지적 추적" 섹션이 포함된다

### R3 — 잔여 권한 정정

- [ ] **AC-R3a** — Given planner·designer·quality 3개 파일, When frontmatter `tools:`를 grep, Then planner에 `Edit`, designer에 `Edit`, quality에 `Write`가 포함된다 (`check_tool_grants`)
- [ ] **AC-R3b** (수동/리뷰 시 확인) — Given 감사 표의 "적정" 판정 10개 에이전트 파일, When `git diff $(git merge-base HEAD main)..HEAD -- <에이전트 디렉터리>`를 확인하면, Then 해당 10개 파일의 frontmatter `tools:` 라인이 변경되지 않았다 (N-6 — 기준 ref를 명시하지 않으면 검증 불가)

### R4 — so-spike

- [ ] **AC-R4a** — Given 에이전트 디렉터리, When so-spike.md를 확인, Then 존재하며 기존 `check_frontmatter`(name/description/tools/model 4필드)를 통과한다 (`check_spike_agent`)
- [ ] **AC-R4b** — Given so-spike 본문, When 계약 문구를 grep, Then 입력(가정 ID/거짓 시 붕괴 대상/측정 방법)·출력(F번호/양성·음성·측정불능/실측 근거)·저장소 불변(**시작·종료 `git status --porcelain` 기준선 대조 + 동일하지 않으면 실패**) 계약이 모두 존재한다 (`check_spike_agent`)
- [ ] **AC-R4c** — Given `.claude/` 레이아웃의 `install.sh`, When AGENTS 배열을 grep, Then `so-spike`가 존재한다. `plugins/` 레이아웃에서는 본 체크를 스킵한다 (`check_spike_in_install`)
- [ ] **AC-R4d** (수동 스모크) — Given 검증 가능한 가정 1건, When so-spike를 실행, Then 확정 사실표가 반환되고 **실행 전후 `git status --porcelain` 출력이 동일하다** (C-2)

### R5 — 미검증 가정 보고 표준

- [ ] **AC-R5a** — Given reviewer·architect 본문, When "미검증 가정" 섹션 형식을 grep, Then 두 파일 모두에 3열 형식(가정 / 거짓일 경우 무너지는 것 / 측정 방법)과 "유보 대신 스파이크 요청" 문구가 존재한다 (`check_unverified_assumption_format`)

### R6 — 오케스트레이터 편입

- [ ] **AC-R6a** — Given 오케스트레이터 파일, When Step 3.7을 grep, Then so-spike 호출 → planner 사실표 병합 → reviewer 재검토 경로와 "음성 판정은 해당 R 재설계 강제" 문구가 존재한다 (`check_orchestrator_spike_path`)
- [ ] **AC-R6b** — Given 오케스트레이터 파일, When 상한 문구를 grep, Then 스파이크 배치 최대 2회 + 사실 불변 원칙이 존재한다 (`check_orchestrator_spike_path`)
- [ ] **AC-R6c** — Given 오케스트레이터의 Agent Context Passing 표와 파이프라인 다이어그램, When grep, Then so-spike 행이 존재한다
- [ ] **AC-R6d** — Given so-reviewer 본문, When 자가 점검 문구를 grep, Then "신규 지적이 이전 리뷰에 없었던 이유 명시" 지침이 존재한다 (`check_reviewer_persistence`에 흡수 — N-5)

### R7 — 테스트 하네스

- [ ] **AC-R7a** — Given 리졸버 도입 커밋(구조 변경) 직후, When `tests/run-checks.sh`를 현재 `.claude/` 레이아웃에서 실행, Then 도입 전과 동일하게 전체 GREEN이다
- [ ] **AC-R7b** — Given `tests/run-checks.sh` 본문, When 리졸버 함수 외부에서 `.claude/agents` 또는 `.claude/so-orchestrator.md` 하드코드를 grep, Then 매치가 없다
- [ ] **AC-R7c** — Given 본 SPEC 구현 완료 상태, When `tests/run-checks.sh` 실행, Then 신규 체크 8종 포함 전체 GREEN이다
- [ ] **AC-R7d** (수동 스모크 — SPEC-001 병합 후에만 가능) — Given `plugins/` 레이아웃, When `tests/run-checks.sh` 실행, Then 리졸버가 새 경로를 감지하여 전체 GREEN이다
