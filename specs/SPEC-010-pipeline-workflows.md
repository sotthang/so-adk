# SPEC-010: 파이프라인 결정적 구간의 Workflow 스크립트화

**Status**: Done
**Created**: 2026-11-12

## Goal

TDD 루프와 Pre-PR 게이트를 orchestrator 프롬프트 지시("max 5 loops", "in parallel", "both must pass")에서 Workflow 스크립트로 옮겨, 루프 상한·병렬 실행·판정표를 코드가 강제하게 한다. 사람 확인 지점과 의도 라우팅은 orchestrator 에 남긴다.

## Background — 실측 (scratchpad 스파이크, Claude Code 2.1.311)

| # | 사실 | 근거 |
| - | ---- | ---- |
| F1 | 플러그인 `workflows/*.js` 는 매니페스트 선언 없이 `/<plugin>:<name>` 으로 발견된다. 실행마다 "Review dynamic workflow before running" 승인을 요구한다 | `/spk:hello` 실행 |
| F2 | `agent(..., { agentType: '<plugin>:<agent>' })` 는 그 에이전트의 `model` 을 적용한다. agentType 없으면 세션 모델 상속 | typed=`claude-haiku-5-5`, untyped=`claude-sonnet-5-5` |
| F3 | `-p` 에서도 워크플로 완료를 기다려 반환값을 받는다 | 스파이크 |
| F4 | orchestrator 형 시스템 지시가 있으면 자연어 요청만으로 `Workflow({name})` 를 호출한다 | stream-json 의 tool_use |
| F5 | 실제 core 플러그인으로 토이 저장소에서 `tdd-cycle` → `{"status":"green","loops":1}`, `npm test` 7/7 통과 (≈ $0.64) | 스모크 |

## Requirements

- **R1** `workflows/tdd-cycle.js` — args `{spec, arch?}`. RED(스키마: testFiles, failingCount) → GREEN 루프 `MAX_LOOPS = 5`(developer 후 tester 검증, 실패 목록을 다음 developer 프롬프트로) → so-quality → 재검증. status: `green | exhausted | not-red | refactor-broke | error(stage)`.
- **R2** `workflows/pr-gate.js` — so-preflight·so-security 병렬, 스키마 enum verdict. 고정 표: GO+PASS→`proceed`, GO+CONDITIONAL→`ask`, 그 외(NO-GO, BLOCK, HOLD, null)→`stop` (fail closed, SPEC-005 R2 유지).
- **R3** 정적 무결성: `meta.name` == 파일명, agentType 은 실재 에이전트, `Date.now`·`Math.random`·`new Date()` 금지(재개를 깨뜨림).
- **R4** orchestrator Step 5·6 이 워크플로를 실행하고 모든 status/decision 을 처리한다. Workflow 를 쓸 수 없으면 기존 수동 Agent 절차로 내려간다.

## Acceptance Criteria

| AC | 검증 | 결과 |
| -- | ---- | ---- |
| AC-1 (R1·R2) | `node --test tests/workflows.test.mjs` (15건, 스텁 agent) via `check_workflow_unit_tests` | RED(파일 없음) → GREEN. 뮤테이션: pr-gate 를 순차 호출로 바꾸면 병렬성 테스트 RED |
| AC-2 (R3) | `check_workflows_static` | GREEN |
| AC-3 (R4) | `check_orchestrator_uses_workflows` | RED(12건) → GREEN |
| AC-4 | 런타임 스모크 (F5) | tdd-cycle 통과. pr-gate 는 단위 테스트만 (opus 비용) |

## Notes

- 워크플로 안에는 사람 확인 지점을 두지 않는다 — 백그라운드로 돌며 사용자와 대화할 수 없다.
- Fable 에이전트(Planner·Architect)는 워크플로에 들어가지 않으므로 SPEC-009 Step 3.1 과 겹치지 않는다.
- 후속 후보: 구현 후 리뷰 팬아웃(quality·security·performance 병렬), Brownfield 경로.
