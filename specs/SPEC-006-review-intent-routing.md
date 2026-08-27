# SPEC-006: "리뷰" 인텐트가 SPEC 평가자로 오배송되는 문제

**Status**: Done
**Created**: 2026-08-27

## Goal

라우팅 표에 코드 리뷰 행이 없어 오케스트레이터가 매번 즉흥적으로 대상을 지어내던 문제를 없애고, SPEC 검토와 코드 리뷰 두 인텐트를 명시적으로 분리한다.

## Background

### 결함 위치

[so-orchestrator.md:83](../plugins/so-adk-orchestrator/agents/so-orchestrator.md#L83) 한 줄이다.

```
| "검토 / review / 리뷰" | Invoke `so-reviewer` only |
```

`so-reviewer`는 이름과 달리 **코드 리뷰어가 아니다**. frontmatter 가 그것을 증명한다:

```yaml
name: so-reviewer
description: Critical SPEC evaluator. ...
tools: Read, Grep, Glob, Edit, Write, Skill      # ← Bash 없음
skills: [so-foundation, so-spec-format]
```

**`Bash`가 없어 `git diff`를 실행할 수 없다.** 본문 절차도 전부 SPEC 기준이며(`Read the SPEC carefully`, 체크리스트는 Goal/requirements testable/Out of scope/Acceptance criteria), 산출물은 `specs/SPEC-{NNN}-{slug}.review-v{N}.md`다.

바로 다음 행이 `"정리 / 리팩토링 / simplify / refactor / clean / 개선" → so-quality`인데, "코드 리뷰"라는 발화를 두고 두 행이 경합한다.

### 실측 (2026-08-27) — 측정 도구 편향을 먼저 밝힌다

오케스트레이터 본문을 프롬프트로 주고 `claude -p --model sonnet` 으로 라우팅 결정만 물었다.
**초기 측정은 답변 형식을 "이름 하나로 답하라"로 강제했고, 이것이 에이전트명 패턴매칭을 유도해 결과를 왜곡했다.**
같은 프롬프트에 근거를 함께 물으면 다른 답이 나왔다. 따라서 아래 표는 **중립 형식**(`ROUTE=<에이전트명 또는 스킬명 또는 ASK>`)으로 재측정한 것이다.

#### 중립 도구 기준 — 수정 전/후 대조

| 사용자 발화 | 수정 전 | 수정 후 | 판정 |
| ----------- | ------- | ------- | ---- |
| "코드 리뷰해줘" | **`so-adk-core:code-review`** | `code-review` | 🔴 → ✅ |
| "방금 바꾼 코드 리뷰 좀 해줘" | `code-review` | `code-review` | ✅ → ✅ |
| "SPEC 검토해줘" | `so-reviewer` | `so-reviewer` | ✅ → ✅ |
| "리뷰해줘" (대상 불명) | `so-reviewer` | **`ASK`** | 🔴 → ✅ |

#### 확정된 결함 세 가지

- **F1 — 존재하지 않는 스킬 호출.** 수정 전 "코드 리뷰해줘"는 `so-adk-core:code-review` 로 라우팅됐다. **이 스킬은 실존하지 않는다** — `plugins/so-adk-core/skills/` 에는 `dev`·`plan`·`pr`·`refactor`·`so-context`·`so-foundation`·`so-spec-format`·`so-tdd-workflow` 8개뿐이다. 호출 시점에 실패한다.
- **F2 — 대상 불명 발화의 오배송.** 수정 전 `"리뷰해줘"` 단독 발화는 `so-reviewer`(SPEC 평가자)로 갔다. 두 측정 도구 모두에서 재현됐으므로 도구 편향이 아니다.
- **F3 — 라우팅이 측정 도구에 민감했다.** 라우팅 표에 코드 리뷰 행이 아예 없어 모델이 **매번 즉흥적으로 메워야 했고**, 그래서 도구·표현에 따라 답이 흔들렸다(F1의 환각도 여기서 나온다). 명시적 행을 넣는 것이 본 SPEC 의 핵심 처방이다.

#### 초기(편향된) 측정 기록 — 정직 표기

착수 시 "이름 하나로 답하라" 형식으로 얻은 결과는 다음과 같았고, **SPEC 초안의 근거였으나 재측정으로 뒤집혔다.**

| 발화 | 편향 도구 결과 | 중립 도구 결과 |
| ---- | -------------- | -------------- |
| "코드 리뷰해줘" | `so-reviewer` | `so-adk-core:code-review` |
| "방금 바꾼 코드 리뷰 좀 해줘" | `so-quality` | `code-review` |

즉 **"so-quality 로 오배송된다"는 초안의 주장은 도구 산물이었다.** 실제 결함은 F1·F2·F3 이다.

### 실측 — `so-quality` 는 리뷰 요청에 코드를 수정하지 않았다

착수 시 `so-quality` 가 리뷰 요청에 코드를 고쳐버릴 것으로 추정했으나 **측정 결과 그렇지 않았다.**

| 픽스처 | 실측 결과 |
| ------ | --------- |
| 버그만 있는 2줄 파일 | 파일 해시 불변. "버그는 조용히 고치지 말고 별도 보고" 규칙 작동 |
| 리팩터링 여지가 있는 코드(중복 함수·매직 넘버) | 파일 해시 불변. *"이번 diff 범위 밖의 기존 코드라 임의로 손대지 않았습니다"* 라고 명시하며 물러섬 |

`so-quality` 는 `Edit`·`MultiEdit`·`Write` + `permissionMode: acceptEdits` 권한을 실제로 갖는다. 위험이 없다는 뜻은 아니지만, 관측된 2회 모두 수정하지 않았다. R4(성격 병기)는 예방적 조치로 유지한다.

### 정정된 심각도

**중간.** F1 은 호출 실패로 이어지므로 실질 피해가 있고, F2·F3 은 예측 불가·부적합 배송이다. 다만 SPEC-005 의 "거짓 GO"처럼 조용히 잘못된 판정을 내지는 않는다.

### SO-ADK 에는 코드 리뷰 에이전트가 없다

16개 에이전트를 전수 확인한 결과 `git diff`를 읽는 진단형(비수정) 에이전트는 다음뿐이다.

| 에이전트 | 성격 | 코드 리뷰 대체 가능? |
| -------- | ---- | -------------------- |
| `so-preflight` | 머지 직전 게이트 — 전체 테스트 스위트 실행 + go/no-go | ❌ 애드혹 리뷰에 과함 |
| `so-security` | 보안 한정 심층 분석 | ❌ 범위 한정 |
| `so-quality` | 리팩터링 **실행** | ❌ 진단이 아님 |

즉 이 칸은 비어 있고, 본 SPEC 은 **에이전트를 신설하지 않고** Claude Code 내장 `code-review` 스킬로 위임해 메운다.

## Requirements

### R1 — `so-reviewer` 라우팅을 SPEC 전용으로 좁힌다

- `"검토 / review / 리뷰"` 행을 `"SPEC 검토 / 스펙 리뷰 / spec review"`로 교체한다.
- 해당 행에 **"SPEC 문서 평가 — 코드 리뷰 아님"** 을 병기해 오해를 차단한다.
- `so-reviewer` 에이전트 파일 자체는 수정하지 않는다 — 동작은 올바르고 라우팅만 틀렸다.

### R2 — 코드 리뷰 인텐트를 `code-review` 스킬로 위임

- `"코드 리뷰 / code review / 변경사항 봐줘 / 이 코드 봐줘"` 행을 신설하고 `code-review` 스킬 호출로 라우팅한다.
- 오케스트레이터는 `tools:` 제한이 없고(`check_orchestrator_frontmatter`가 강제) 이미 `so-adk-core:pr` 스킬을 호출하므로 기제는 이미 존재한다.
- 위임 대상은 **Claude Code 내장 `code-review`** 다. 사용자 프로젝트에 동명의 로컬 스킬이 있으면 그쪽이 우선하는데, 이는 **의도된 동작**이다 — 프로젝트 고유 리뷰어가 있으면 그것을 쓰는 편이 낫다.

### R3 — 대상이 불명한 "리뷰해줘"는 되묻는다

- 대상을 특정하지 않은 `"리뷰해줘"` 단독 발화는 어느 쪽으로도 단정하지 않고 **한 번만** 되묻는다: "SPEC 검토인가요, 코드 리뷰인가요?"
- 오케스트레이터에 이미 있는 규칙("When intent is ambiguous, ask **one** clarifying question")과 같은 방식이다.

### R4 — `so-quality` 행의 성격 명시

- `"정리 / 리팩토링 / ..."` 행은 그대로 두되 **"코드를 실제로 수정함"** 을 병기한다. 리뷰(진단)와 리팩터링(수정)의 경계를 사용자에게 드러내는 것이 목적이다.

### R5 — 회귀 방지 테스트

- `tests/run-checks.sh`에 검사를 추가한다:
  - 오케스트레이터에 구 라우팅 행(`"검토 / review / 리뷰"`)이 **없을 것**
  - `so-reviewer` 라우팅 행에 `SPEC`이 포함될 것
  - 코드 리뷰 위임 행이 존재할 것
- 정적 문자열 검사이므로 **런타임 라우팅 동작은 이 테스트로 검증되지 않는다.** 착수 후 실측으로 별도 확인한다.

## Out of Scope

- **`so-code-reviewer` 에이전트 신설** — 별도 판단 사항이며 본 SPEC 은 라우팅만 고친다. 신설 시 에이전트 17개가 되어 `check_asset_counts`·`plugin.json` 문언·오케스트레이터 참조를 함께 손봐야 한다.
- `so-reviewer`·`so-quality` 에이전트 본문 수정 — 각자 자기 일은 올바르게 한다.
- `so-quality`의 `Handing off to Docs Agent` 잔재 — 별건(낮은 심각도)으로 남긴다.
- 내장 `code-review` 스킬 자체의 동작.

## Technical Approach

- **수정 파일**: `plugins/so-adk-orchestrator/agents/so-orchestrator.md`, `tests/run-checks.sh`
- **버전 범프**: `so-adk-orchestrator` `1.0.0` → `1.0.1`. **`plugin.json`과 `.claude-plugin/marketplace.json` 두 곳을 함께 올린다** — SPEC-005 구현 중 한쪽만 올려 `claude plugin validate --strict`가 실패한 전례가 있다.
- **Tidy First 분류**: 행위 변경이다.
- **TDD 순서**: R5 검사를 먼저 작성해 RED 확인 → 라우팅 수정 → GREEN. RED 는 커밋하지 않는다.

## 미검증 가정 (Unverified Assumptions)

| ID | 가정 | 상태 |
| -- | ---- | ---- |
| B-1 | 오케스트레이터가 `code-review` 스킬을 실제로 호출 대상으로 선택할 수 있다 | **측정 완료 — 양성.** 수정 후 "코드 리뷰해줘" 3회 연속 `ROUTE=code-review`. 단 **라우팅 선택까지만 측정했고 실제 스킬 호출은 확인하지 않았다** — 헤드리스 세션에는 플러그인이 로드되지 않는다 |
| B-2 | 라우팅 문언 변경이 실제 분기를 바꾼다 | **측정 완료 — 양성.** 동일 중립 도구로 수정 전/후 4개 발화 대조. F1(환각 스킬)·F2(대상 불명 오배송) 모두 해소 |
| B-3 | 측정 도구가 라우팅 결과에 영향을 주지 않는다 | **거짓으로 판명.** 답변 형식 강제가 결과를 바꿨다 — 위 "측정 도구 편향" 참조. 이 SPEC 의 모든 라우팅 수치는 중립 도구 기준이다 |

## Acceptance Criteria

- [x] **AC-R1**: Given 수정된 오케스트레이터, When `"SPEC 검토해줘"`로 라우팅을 물으면, Then `so-reviewer`가 선택된다.
- [x] **AC-R2a**: Given 수정된 오케스트레이터, When `"코드 리뷰해줘"`로 라우팅을 물으면, Then `so-reviewer`가 **아니라** `code-review` 스킬이 선택된다.
- [x] **AC-R2b**: Given 수정된 오케스트레이터, When `"방금 바꾼 코드 리뷰 좀 해줘"`로 물으면, Then `so-quality`가 **아니라** `code-review` 스킬이 선택된다.
- [x] **AC-R3**: Given 수정된 오케스트레이터, When 대상 불명의 `"리뷰해줘"`로 물으면, Then 단정하지 않고 되묻는다.
- [x] **AC-R4**: Given 오케스트레이터 본문, When `so-quality` 라우팅 행을 확인하면, Then 코드를 수정한다는 표기가 있다.
- [x] **AC-R5a**: Given `tests/run-checks.sh`, When 실행하면, Then 신설 검사가 포함되고 전체 FAIL 0이다.
- [x] **AC-R5b** (회귀 고정): Given 구 라우팅 행을 되돌려 놓은 상태, When 검사를 실행하면, Then FAIL 한다.
- [x] **AC-R6**: Given 수정 완료, When 두 매니페스트를 확인하면, Then `so-adk-orchestrator` 버전이 양쪽 모두 `1.0.1`이다.

## 관련 문서

- 결함 발견 경위: SPEC-005 작업 중 `so-reviewer`가 코드 리뷰어가 아님을 확인하고 라우팅까지 추적 (2026-08-27)
- 버전 이중 관리: [SPEC-005](SPEC-005-diff-base-hardcoded-main.md) Technical Approach

## 검토 이력

| 버전 | 날짜 | 내용 |
| ---- | ---- | ---- |
| v1 | 2026-08-27 | 최초 Draft. 라우팅 4개 발화 실측으로 분기 갈림을 확인했고, **`so-quality`가 코드를 수정할 것이라는 착수 시 추정을 실측으로 정정**했다(3회 모두 미수정). 심각도를 안전 문제에서 적합성 문제로 하향했다. |
| v1.1 | 2026-08-27 | **측정 도구 편향 발견 — Background 전면 정정.** 초안의 근거였던 "so-reviewer/so-quality 오배송"은 답변 형식을 강제한 측정의 산물이었다. 중립 도구로 재측정해 실제 결함을 F1(존재하지 않는 `so-adk-core:code-review` 환각)·F2(대상 불명 발화 오배송)·F3(라우팅 표 공백으로 인한 즉흥 대응)으로 재정의했다. Goal 문언도 함께 정정했다. 구현·검증 완료. |

## 구현 결과 (2026-08-27)

### 수정 내용

- **`so-orchestrator.md`**: 구 라우팅 행 1개를 3개로 분할(`SPEC 검토` / `코드 리뷰` / `리뷰해줘`(대상 불명 → 되묻기)). `so-quality` 행에 "코드를 실제로 수정한다" 병기. 표 아래에 「리뷰 인텐트 분기 (SPEC-006)」 절을 추가해 위임 근거를 명시.
- **`plugin.json` + `.claude-plugin/marketplace.json`**: `so-adk-orchestrator` `1.0.0` → `1.0.1` (두 곳 동시).
- **`tests/run-checks.sh`**: `check_review_intent_routing` 신설. 45 → **46 passed / 0 failed / 1 skipped**.

### 런타임 검증 (중립 도구, `claude -p --model sonnet`)

| 발화 | 수정 전 | 수정 후 |
| ---- | ------- | ------- |
| "코드 리뷰해줘" | `so-adk-core:code-review` (실존하지 않음) | `code-review` — **3회 연속 동일** |
| "방금 바꾼 코드 리뷰 좀 해줘" | `code-review` | `code-review` |
| "SPEC 검토해줘" | `so-reviewer` | `so-reviewer` |
| "리뷰해줘" | `so-reviewer` | `ASK` |

### 정직 표기

- **라우팅 선택까지만 측정했다.** 실제로 `code-review` 스킬이 호출·실행되는지는 확인하지 않았다 — 헤드리스 세션에 플러그인이 로드되지 않아 측정 불가였다(B-1 잔여).
- 안정성 측정은 "코드 리뷰해줘" 발화 **1종에 대해서만 3회**다. 나머지 발화는 n=1이다.
- Sonnet 으로만 측정했다.
- **`so-reviewer` 검토를 거치지 않았다** — `review-v*.md` 가 없다.
