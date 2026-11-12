# SPEC-009: Claude Code 최신 동작 따라잡기 — 무효 설정 정리 · Fable 한도 전환 · 라우팅 eval

**Status**: Done
**Created**: 2026-11-12

## Goal

Claude Code 의 현행 동작(2.1.311)과 어긋난 설정을 걷어내고, Fable 사용 한도 소진을 하네스가 스스로 처리하게 하며, SPEC-006·007 류의 라우팅 회귀를 실제 모델 호출로 잡는 eval 스위트를 둔다.

## Background

공식 문서(sub-agents, model-config, plugins manifest/components, plugin-evals)와 로컬 실측으로 확인한 사실:

| # | 사실 | 근거 |
| - | ---- | ---- |
| F1 | 플러그인 에이전트는 `permissionMode`·`hooks`·`mcpServers`·`initialPrompt` 를 **무시**한다 (보안상). 16개 에이전트 전부가 `permissionMode` 를 가지고 있었다 — so-developer 의 `acceptEdits` 는 적용된 적이 없다 | code.claude.com/docs/en/sub-agents.md |
| F2 | `MultiEdit` 는 현행 도구가 아니다. 없는 도구는 오류 없이 버려진다 | 실측: `claude -p --tools "Read,MultiEdit"` → 노출 도구 `Read` 뿐. `Grep`·`Glob` 은 기본 목록에서 빠졌지만 명시 지정 시 살아 있다 |
| F3 | `claude plugin validate --strict` 가 hooks 의 따옴표 없는 `${CLAUDE_PLUGIN_ROOT}` 를 경고 → `check_plugin_validate_core` 가 **이미 RED** 였다 (CLI 갱신으로 발생) | 실측 |
| F4 | `fallbackModel` / `--fallback-model` 은 과부하·사용 불가·서버 오류에서만 발동하고 **rate limit·usage limit 에서는 발동하지 않는다**. 플러그인 `settings.json` 은 `agent`·`subagentStatusLine` 만 적용 | model-config.md, plugins/components.md |
| F5 | Agent 도구 호출의 `model` 파라미터가 frontmatter 보다 우선한다 → orchestrator 가 재디스패치로 모델을 바꿀 수 있다 | sub-agents.md (모델 결정 순서) |
| F6 | `plugin.json` 에 `dependencies` 가 생겼다. orchestrator 는 설명 문자열로만 core 의존을 밝히고 있었다 | plugins/manifest-reference.md |
| F7 | `claude plugin eval` 은 대상 디렉터리 밖 플러그인을 로드하지 못한다(containment root). 두 플러그인을 함께 로드하려면 저장소 루트를 대상으로 둬야 한다. eval 에서 orchestrator 의 `settings.json` `agent` 는 적용된다 | 실측: 첫 동작이 Step 0 의 `Glob specs/SPEC-*.md`, `subagent_type` 은 `so-adk-core:so-planner` |
| F8 | Fable 은 사이버보안으로 분류된 요청을 다른 모델로 돌리고, 서브에이전트에서는 `Agent terminated early due to an API error` 로 실패할 수 있다 | model-config.md |

## Requirements

- **R1** 플러그인 에이전트 frontmatter 에 무시되는 필드(F1)가 없다.
- **R2** 에이전트 `tools:` 에 존재하지 않는 도구(`MultiEdit`)가 없다. hooks 의 `Edit|Write|MultiEdit` 매처는 하위 호환으로 유지한다(무해).
- **R3** hooks 명령의 플러그인 루트는 따옴표로 감싼다. orchestrator `plugin.json` 은 `dependencies: ["so-adk-core"]` 를 선언한다.
- **R4** orchestrator `Step 3.1` — Fable 에이전트가 사용 한도로 실패하면 묻지 않고 `model: "opus"` 로 한 번만 재시도, 한 줄 고지, 세션 끝까지 opus 고정, opus 도 실패하면 멈추고 보고(sonnet 강등 금지). 대상 목록은 frontmatter `model: fable` 에서 동적으로 검사한다.
- **R5** `evals/route-*` 9케이스 + `tests/run-evals.sh`. `run-checks.sh` 는 필수 케이스 존재와 grader 의 에이전트 참조 실재만 정적으로 확인한다.

## Acceptance Criteria

| AC | 검증 | 결과 |
| -- | ---- | ---- |
| AC-1 (R1·R2) | `check_no_ignored_plugin_agent_fields` | RED(16+2건) → GREEN |
| AC-2 (R3) | `check_plugin_validate_core`, `check_hooks_json_valid`, `check_orchestrator_declares_core_dependency` | RED → GREEN. 실측: 따옴표 명령으로 SessionStart hook `exit 0` (eval trace) |
| AC-3 (R4) | `check_fable_fallback_rule` | RED → GREEN. 뮤테이션(대상 에이전트 누락, `한 번만` 삭제) 2종 모두 RED |
| AC-4 (R5) | `check_routing_evals` + `bash tests/run-evals.sh` | 9/9 통과 (runs=1, 총 ≈ $1.4). 뮤테이션: SPEC-006 버그(코드 리뷰 → so-reviewer) 재도입 시 `route-code-review-skill` 점수 0 |

## Notes

- `route-review-ambiguous-asks` 의 grader 는 정확한 문장이 아니라 "두 갈래(SPEC 검토 / 코드 리뷰)를 모두 제시하며 되묻는다"를 확인한다. 첫 실행에서 orchestrator 는 정규 문구 대신 번호 목록으로 되물었고, 동작은 올바랐다.
- 미검증: 실제 Fable 한도 소진 시 Agent 도구가 돌려주는 오류 문구 (문서 없음, 재현 불가). Step 3.1 의 감지 키워드는 그래서 넓게 잡았다. 실제 문구를 보면 갱신할 것.
- 범위 밖 (후속 후보): `memory:`(debugger·reviewer·auditor), `color`, `background`, Workflow 스크립트화. `so-spike` 의 `isolation: worktree` 는 기본 브랜치에서 분기해 미커밋 상태를 잃으므로 채택하지 않는다.
- so-reviewer 사전 검토 없이 진행했다 (사용자 지시로 즉시 진행).
