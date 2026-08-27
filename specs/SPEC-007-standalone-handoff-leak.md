# SPEC-007: 단독 호출 시 파이프라인 인계 문구가 새는 문제

**Status**: Done
**Created**: 2026-08-27

## Goal

파이프라인 에이전트가 **단독 호출**됐을 때도 다음 단계로 인계한다는 문구를 출력해, 실제로는 일어나지 않는 후속 단계를 사용자에게 약속하는 문제를 없앤다.

## Background

### 결함 위치 — `so-quality` 만의 문제가 아니다

조사 결과 4개 에이전트 6곳이다. **(정정: 이 조사는 전수가 아니었다 — 실제로는 7개 에이전트 11곳이며, 누락된 `so-planner`·`so-developer`·`so-performance`·`so-explainer` 는 [SPEC-008](SPEC-008-review-followups.md) R4 에서 처리했다.)**

| 파일 | 행 | 문구 |
| ---- | -- | ---- |
| `so-quality.md` | 23 | `5. Hand off to Docs Agent` (Process) |
| `so-quality.md` | 75 | `Handing off to Docs Agent.` (Output Format) |
| `so-tester.md` | 75 | `Handing off to Developer.` |
| `so-tester.md` | 97 | `Handing off to Quality Agent.` |
| `so-debugger.md` | 24 | `6. **Hand off** — pass ... to the Developer Agent` |

파이프라인 전체 실행 중에는 **올바른 문구다.** 문제는 오케스트레이터가 `Invoke \`so-quality\` only` 처럼 단독 호출했을 때도 그대로 나온다는 점이다.

### 실측 — 파이프라인이 실제로 이어지지는 않는다 (2026-08-27)

착수 시 이 문구가 오케스트레이터를 다음 단계로 끌고 갈 수 있다고 추정했다. **측정 결과 그렇지 않았다.**

수정된 오케스트레이터(SPEC-006)에 `"코드 좀 정리해줘"` → `so-quality` 단독 호출 결과가 `Handing off to Docs Agent.` 로 끝난 상황을 주고 다음 행동을 물었다.

| 시행 | 결과 |
| ---- | ---- |
| 1 | `NEXT=STOP` |
| 2 | `NEXT=STOP` |
| 3 | `NEXT=STOP` |

**3/3 모두 정지했다.** 라우팅 표의 `Invoke ... only` 지시가 인계 문구를 이긴다.

### 정정된 심각도 — 낮음 (표기 문제)

| 항목 | 실제 피해 |
| ---- | --------- |
| 파이프라인 오진행 | **없음.** 3/3 정지 확인 |
| 사용자에게 거짓 약속 | 있음. "Docs Agent 로 인계합니다"라고 했는데 아무 일도 일어나지 않는다 |
| 노출 경로 | 서브에이전트 출력은 오케스트레이터가 중계하므로, 오케스트레이터가 **문구를 그대로 옮길 때만** 사용자에게 보인다 |

**기능 결함이 아니라 표기 결함이다.** SPEC-005 의 거짓 GO 나 SPEC-006 의 환각 스킬 호출과 달리 실행 경로에 영향이 없다.

## Requirements

### R1 — 단독 호출 시 인계 문구 억제

- 해당 5곳을 가진 3개 에이전트(`so-quality`, `so-tester`, `so-debugger`)의 **Rules 에 한 줄씩** 추가한다:
  > 파이프라인 단계로 호출된 것이 아니라 **단독 호출**된 경우, 다음 단계 인계 문구를 출력하지 말고 결과 보고로 끝낸다.
- **Output Format 템플릿과 Process 단계는 수정하지 않는다.** 파이프라인 실행 경로에서는 현행 문구가 올바르며, 템플릿을 손대면 정상 경로에 회귀 위험이 생긴다. 조건은 Rules 로만 표현한다.

### R2 — 회귀 방지 테스트

- `tests/run-checks.sh` 에 검사를 추가한다: 세 에이전트 각각의 본문에 단독 호출 억제 문구가 존재할 것.
- 정적 검사이므로 **런타임 동작은 검증되지 않는다.**

## Out of Scope

- 인계 문구 자체의 제거 — 파이프라인 경로에서는 필요하다.
- 오케스트레이터의 중계 로직 — 3/3 정지가 확인됐으므로 손대지 않는다.
- `so-tester`·`so-debugger` 의 파이프라인 순서 자체.

## Technical Approach

- **수정 파일**: `plugins/so-adk-core/agents/so-quality.md`, `.../so-tester.md`, `.../so-debugger.md`, `tests/run-checks.sh`
- **버전 범프**: `so-adk-core` `1.0.2` → `1.0.3`. `plugin.json` 과 `.claude-plugin/marketplace.json` **두 곳**을 함께 올린다.
- **Tidy First 분류**: 행위 변경(프롬프트 지시 추가).
- **TDD 순서**: R2 검사 작성 → RED → 세 파일 수정 → GREEN.

## 미검증 가정 (Unverified Assumptions)

| ID | 가정 | 거짓일 경우 무너지는 것 | 제안 측정 방법 |
| -- | ---- | ----------------------- | -------------- |
| C-1 | 에이전트가 "단독 호출인지"를 스스로 판별할 수 있다 | **측정 완료 — 양성.** 착수 전 스파이크로 확인했다. 아래 "C-1 스파이크" 참조 |

C-1 은 이 SPEC 의 핵심 위험이었다. 판별이 불가능하면 R1 은 무효이고 **수정하지 않는 편이 낫다**는 판단이었으므로, 착수 전에 측정했다.

### C-1 스파이크 (2026-08-27, 구현 전)

후보 규칙을 넣은 `so-quality` 사본으로 두 문맥을 실행했다.

| 문맥 | 프롬프트 | 결과 |
| ---- | -------- | ---- |
| 단독 | "사용자가 직접 요청했다: 코드 좀 정리해줘" | `Handing off` 없음 — *"단독 요청으로 호출되어 다음 단계 인계는 생략합니다"* |
| 파이프라인 | "SO Orchestrator 가 SPEC-012 파이프라인의 [6/7] Quality 단계로 너를 호출했다" | `Handing off to Docs Agent.` **유지** |

판별이 가능함이 확인돼 구현에 착수했다.

## Acceptance Criteria

- [x] **AC-R1a**: Given 수정된 `so-quality`, When 단독 호출로 실행하면, Then 출력에 `Handing off to Docs Agent` 가 없다.
- [x] **AC-R1b** (정상 경로 보존): Given 수정된 `so-quality`, When 파이프라인 문맥임을 명시해 호출하면, Then 인계 문구가 그대로 나온다.
- [x] **AC-R2a**: Given `tests/run-checks.sh`, When 실행하면, Then 신설 검사가 포함되고 전체 FAIL 0이다.
- [x] **AC-R2b**: Given 억제 문구를 제거한 상태, When 검사를 실행하면, Then FAIL 한다.
- [x] **AC-R3**: Given 수정 완료, When 두 매니페스트를 확인하면, Then `so-adk-core` 버전이 양쪽 모두 `1.0.3` 이다.

## 관련 문서

- 발견 경위: SPEC-006 측정 중 `so-quality` 가 애드혹 리뷰 요청을 인계 문구로 끝내는 것을 관측 (2026-08-27)
- 오케스트레이터 단독 호출 지시: [so-orchestrator.md](../plugins/so-adk-orchestrator/agents/so-orchestrator.md) Step 2 라우팅 표

## 검토 이력

| 버전 | 날짜 | 내용 |
| ---- | ---- | ---- |
| v1 | 2026-08-27 | 최초 Draft. 착수 시 `so-quality` 1곳으로 알았으나 전수 조사에서 4개 에이전트 6곳으로 확대됐다. **파이프라인 오진행 추정은 3/3 측정으로 부정**돼 심각도를 표기 결함(낮음)으로 확정했다. |

## 구현 결과 (2026-08-27)

### 수정 내용

- **`so-quality.md`·`so-tester.md`·`so-debugger.md`**: 각 `## Rules` 최상단에 억제 규칙 1행 추가. **Output Format 템플릿과 Process 단계는 손대지 않았다** — 정상 경로 회귀를 피하기 위한 R1 의 설계 결정 그대로다.
- **`plugin.json` + `.claude-plugin/marketplace.json`**: `so-adk-core` `1.0.2` → `1.0.3` (두 곳 동시).
- **`tests/run-checks.sh`**: `check_standalone_handoff_rule` 신설. 46 → **47 passed / 0 failed / 1 skipped**.

### 배포 파일 런타임 검증

| AC | 대상 | 결과 |
| -- | ---- | ---- |
| AC-R1a | 배포된 `so-quality`, 단독 호출 | `Handing off` 없음 ✅ |
| AC-R1b | `so-quality`, 파이프라인 문맥 | `Handing off to Docs Agent.` 유지 ✅ (C-1 스파이크, 동일 규칙 문안) |

### 정직 표기

- **AC-R1b 는 `so-quality` 로만 확인했다.** `so-tester` 를 파이프라인 문맥으로 실행해봤으나, 픽스처에 구현이 이미 존재해 RED 테스트 작성 전제가 깨졌고 에이전트가 *"정상적인 [4/7] Tester → Developer 인계 흐름이 아닙니다"* 라며 오케스트레이터로 되돌렸다. **적합한 픽스처가 아니어서 측정이 성립하지 않았다.** `so-debugger` 도 미측정이다.
- 세 파일에 넣은 규칙 문안은 동일하므로 `so-quality` 결과가 나머지에도 적용될 것으로 보지만, **이는 추정이지 측정이 아니다.**
- 각 측정 n=1 이다.
- **본 SPEC 은 `so-reviewer` 검토를 거치지 않았다.**
| v1.1 | 2026-08-27 | **사후 검토 반영.** `so-reviewer` 검토에서 "전수 조사" 주장이 과잉임이 드러났다 — 실제 인계 문구는 7개 에이전트 11곳이고 본 SPEC 은 3개만 처리했다. 나머지 4개와 회귀 테스트 보강은 SPEC-008 로 이관했다. `so-debugger` 체인 단절 위험 제기는 3/3 측정으로 **음성 확정**. |
