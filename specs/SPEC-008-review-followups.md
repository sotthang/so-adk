# SPEC-008: SPEC-005~007 사후 검토 지적 처리

**Status**: Done
**Created**: 2026-08-27

## Goal

`so-reviewer` 사후 검토가 SPEC-005·006·007 에서 찾아낸 결함 중 **재현 확인된 것**을 처리한다. 핵심은 SPEC-005 가 없애려던 "안전 게이트의 침묵"이 남은 경로에서 재현되는 것을 막고, 세 SPEC 의 회귀 그물 구멍을 닫는 것이다.

## Background

SPEC-005·006·007 은 모두 `so-reviewer` 검토 없이 `Done` 처리됐다. 사후에 세 건을 검토받았고, 지적을 **직접 재현해 검증**한 뒤 본 SPEC 의 범위를 정했다.

### D1 (High) — `@{u}` 가 트렁크를 자기 자신으로 오탐한다

SPEC-005 R1 의 탐지 체인 2단계는 `git rev-parse --abbrev-ref @{u}` 에서 `origin/` 접두를 떼면 트렁크가 나온다고 가정한다. **틀렸다** — 이 명령은 트렁크가 아니라 **현재 브랜치의 upstream** 을 반환한다.

실측 (픽스처 P: `origin/HEAD` 미설정 + feature 브랜치 + upstream 설정):

```
현재 브랜치: feat/x
1단계-1 origin/HEAD: fatal (미설정)
1단계-2 @{u}       : origin/feat/x → 트렁크='feat/x'
⇒ 트렁크 == 현재 브랜치 → 2단계 (a) 건너뜀
(b)=0  (c)=0  (d) HEAD~1 → sql.py                    ← 1파일만 리뷰
정답 main...HEAD → rce.py secret.py sql.py           ← 3파일
```

누락된 `secret.py`(하드코딩 시크릿)·`sql.py`(SQL 인젝션)는 정확히 `so-security` 가 잡아야 할 대상이다. **오류가 아니라 부분 리뷰 후 조용한 통과** — SPEC-005 가 없애려던 D2 의 실패 모드와 동일하다.

발생 조건: `origin/HEAD` 미설정(실측 16개 중 1개, 6%) **+** feature 브랜치 **+** upstream 설정.

SPEC-005 의 픽스처 E 가 이 조합을 덮지 못한 이유도 확인됐다 — E 는 **트렁크 위**에 있어 `@{u}` 가 우연히 `origin/main` 을 반환했다. 실측 표에서 `sogul` 을 "유효한 보완재"로 판정한 것도 같은 이유이며, **트렁크 위라는 조건이 빠지면 보완재가 아니라 오답원이다.**

`pr` 스킬은 더 나쁘다 — 미커밋 제외 설계 때문에 (a) 건너뜀 → `@{u}...HEAD` 공집합 → `HEAD~1` 로 떨어져 **PR 본문이 마지막 커밋 하나만 요약**한다.

### D2 (High) — 회귀 테스트가 요구사항을 고정하지 못한다

세 SPEC 의 검사 모두 뮤테이션에 뚫린다. 사본에서 재현했다.

| 검사 | 뮤테이션 | 결과 |
| ---- | -------- | ---- |
| `check_diff_base_detection` | SPEC-005 R2(`판정을 유보`)·R3(`기준선 명시` 절)·Rules 행 **전부 삭제** | **PASS** |
| `check_review_intent_routing` | 위임 대상을 `so-adk-core:code-review`(환각 스킬)로 되돌림 | **PASS** (`.*code-review` 부분 일치) |
| `check_review_intent_routing` | `"리뷰해줘" (대상 불명)` 행 **통째 삭제** | **PASS** (R3 검사 부재) |
| `check_standalone_handoff_rule` | 규칙을 `단독 호출이어도 인계 문구를 반드시 출력한다` 로 **의미 반전** | **PASS** (`단독 호출` 4글자만 확인) |

즉 각 SPEC 이 없애려던 **핵심 결함만** 회귀 그물을 빠져나간다:

- SPEC-005 의 D2(88% 지배적)를 막는 유일한 안전장치가 `판정 유보` 인데 그것만 무방비였다. SPEC-005 는 A-3 를 "미측정"으로 표기했으나 **측정 결과 음성**이다.
- SPEC-006 의 F1(환각 스킬 호출)은 유일하게 실질 피해가 있다고 판정한 항목인데 그것만 통과한다.
- SPEC-007 의 규칙은 의미가 뒤집혀도 GREEN 이다.

### D3 (Medium) — `pr` 스킬의 `git log <기준선> --oneline`

`pr/SKILL.md:9` 는 기준선을 `git diff` 와 `git log` 양쪽에 쓰라고 지시하는데, `git log` 는 후보에 따라 다르게 동작한다.

```
git log @{u}...HEAD --oneline  →  2건  (의도대로)
git log HEAD~1 --oneline       →  4건  (전체 이력 — 의도는 1건)
```

`HEAD~1` 기준선에서 PR 본문이 저장소 전체 이력을 요약한다.

### D4 — SPEC-007 의 "전수 조사" 는 전수가 아니었다

SPEC-007 은 인계 문구를 "4개 에이전트 6곳"으로 적었다. 재조사 결과 **7개 에이전트 11곳**이다.

| 에이전트 | 행 | SPEC-007 처리 |
| -------- | -- | ------------- |
| `so-quality` | 23, 76 | ✅ |
| `so-tester` | 75, 89, 97 | ✅ |
| `so-debugger` | 15, 24 | ✅ |
| `so-planner` | 56 | ❌ 누락 |
| `so-developer` | 25 | ❌ 누락 |
| `so-performance` | 15 | ❌ 누락 |
| `so-explainer` | 62 | ❌ 누락 |

### 음성 판정 — 처리하지 않는 것

- **`so-debugger` 체인 단절 위험**: SPEC-007 검토가 "실행 경로 결함(SPEC-005급)일 수 있다"고 제기했다. 측정 결과 **음성**이다. 인계 문구 없는 `so-debugger` 결과를 주고 다음 행동을 물으면 **3/3 `NEXT=so-developer`** — 라우팅 표(`Invoke so-debugger → then so-developer`)가 인계 문구보다 우선한다. SPEC-007 의 수정은 안전하다.

## Requirements

### R1 — `@{u}` 자기참조 차단 (D1)

- 탐지 체인 1단계-2 에서 얻은 이름이 **현재 브랜치와 같으면 트렁크로 채택하지 않고** 1단계-3(`main` → `master` → `develop` 실재 확인)으로 내려간다.
- 세 파일(`so-preflight`·`so-security`·`pr`) 모두에 적용한다.
- 기존 픽스처 B(트렁크=develop, 트렁크 위)·E(`origin/HEAD` 없음, 트렁크 위)를 깨지 않아야 한다 — 두 경우 모두 `@{u}` 결과가 현재 브랜치와 다르거나 같더라도 3단계가 같은 답을 낸다.

### R2 — `pr` 스킬의 `git log` 기준선 정정 (D3)

- `git log` 는 **커밋 범위 표기가 유효한 후보에서만** 사용한다:
  - `<트렁크>...HEAD` → `git log <트렁크>..HEAD --oneline`
  - `@{u}...HEAD` → `git log @{u}..HEAD --oneline`
  - `HEAD~1` → `git log -1 --oneline`
- 위 대응을 스킬 본문에 명시한다.

### R3 — 회귀 테스트 강화 (D2)

세 검사를 뮤테이션에 견디도록 보강한다.

- **`check_diff_base_detection`**: `so-preflight` 에 `판정 유보`(R2)·`기준선:`(R3) 문자열이 존재할 것을 추가한다.
- **`check_review_intent_routing`**:
  - `so-adk-core:code-review` 문자열이 **존재하면 FAIL**(F1 재오염 차단).
  - 대상 불명 되묻기 행(`리뷰해줘`)이 존재할 것(R3/AC-R3).
- **`check_standalone_handoff_rule`**: 단어 존재가 아니라 **정규 문안**(`인계 문구를 출력하지 않는다`)이 `## Rules` 절 안에 있을 것을 확인한다. 의미 반전과 위치 이탈을 모두 잡는다.
- 각 보강은 **해당 뮤테이션으로 RED 를 실측 확인**한 뒤 GREEN 으로 만든다.

### R4 — 인계 억제 규칙을 나머지 4개 에이전트로 확장 (D4)

- `so-planner`·`so-developer`·`so-performance`·`so-explainer` 에 SPEC-007 과 **동일 문안**의 규칙을 추가한다.
- `check_standalone_handoff_rule` 의 대상을 7개로 확장한다.
- SPEC-007 의 "4개 에이전트 6곳" 문언을 **7개 11곳**으로 정정하고, 정정 사유를 검토 이력에 남긴다.

## Out of Scope

- SPEC-005·006·007 의 Status 되돌리기 — 사후 검토이며 이미 배포됐다. 본 SPEC 이 후속으로 처리한다.
- 세 리뷰의 Low 등급 지적(문서 문언 불일치) — 본 SPEC 의 문서 수정에 부수적으로 흡수되는 것만 처리한다.
- `so-reviewer` 가 제기한 스파이크 요청 중 심각도·우선순위에만 영향을 주는 항목.
- 모델 교차 측정(sonnet/opus) — 세 SPEC 공통 잔여 한계로 남긴다.

## Technical Approach

- **수정 파일**: `plugins/so-adk-core/agents/{so-preflight,so-security,so-planner,so-developer,so-performance,so-explainer}.md`, `plugins/so-adk-core/skills/pr/SKILL.md`, `tests/run-checks.sh`, `specs/SPEC-007-standalone-handoff-leak.md`
- **버전 범프**: `so-adk-core` `1.0.3` → `1.0.4`. `plugin.json` 과 `.claude-plugin/marketplace.json` **두 곳**.
- **Tidy First 분류**: 행위 변경.
- **TDD 순서**: R3 의 보강 검사를 먼저 작성하고 **D2 표의 뮤테이션으로 RED 를 확인**한다(단어 존재 검사로는 잡히지 않던 것이 잡혀야 한다) → R1·R2·R4 수정 → GREEN.

## 미검증 가정 (Unverified Assumptions)

| ID | 가정 | 상태 |
| -- | ---- | ---- |
| D-1 | R1 의 자기참조 가드가 기존 픽스처 B·E 를 깨지 않는다 | **측정 완료 — 양성.** 둘 다 SPEC-005 때와 동일한 `@{u}...HEAD` 채택. 픽스처 E 의 출력이 가드 발동을 명시했다 — *"`@{u}`(origin/main)가 strip 시 현재 브랜치(main)와 동일해 2단계 (a)를 건너뛰고"* |
| D-2 | 나머지 4개 에이전트도 단독/파이프라인 판별이 된다 | **측정 완료 — 양성(n=1).** `so-planner` 단독 호출이 *"이 SPEC 은 단발 요청으로 작성되었습니다"* 로 끝나고 Reviewer 인계 문구 없음. **첫 시행은 측정 불성립** — 요구사항이 모호해 되묻느라 완료 지점에 도달하지 않았고, 명확한 요청으로 재측정했다. `so-developer`·`so-performance`·`so-explainer` 는 미측정 |

## Acceptance Criteria

- [x] **AC-R1a**: Given 픽스처 P(`origin/HEAD` 없음 + feature 브랜치 + upstream), When `so-preflight` 를 실행하면, Then 트렁크가 `feat/x` 가 아니라 `main` 으로 잡히고 3파일 전부가 리뷰 범위에 든다.
- [x] **AC-R1b** (회귀 보존): Given 픽스처 B·E, When `so-preflight` 를 실행하면, Then SPEC-005 때와 동일한 기준선이 채택된다.
- [x] **AC-R2**: Given `pr/SKILL.md`, When 본문을 확인하면, Then 후보별 `git log` 표기 대응이 명시되어 있다.
- [x] **AC-R3a**: Given SPEC-005 R2·R3 문구를 삭제한 사본, When 검사를 실행하면, Then **FAIL 한다**.
- [x] **AC-R3b**: Given 위임 대상을 `so-adk-core:code-review` 로 되돌린 사본, When 검사를 실행하면, Then **FAIL 한다**.
- [x] **AC-R3c**: Given 대상 불명 되묻기 행을 삭제한 사본, When 검사를 실행하면, Then **FAIL 한다**.
- [x] **AC-R3d**: Given 억제 규칙을 의미 반전시킨 사본, When 검사를 실행하면, Then **FAIL 한다**.
- [x] **AC-R4a**: Given 7개 에이전트, When 본문을 확인하면, Then 전부 억제 규칙을 갖는다.
- [x] **AC-R4b**: Given SPEC-007, When 결함 위치 절을 확인하면, Then 7개 11곳으로 정정되어 있다.
- [x] **AC-R5**: Given `tests/run-checks.sh`, When 실행하면, Then 전체 FAIL 0이다.
- [x] **AC-R6**: Given 수정 완료, When 두 매니페스트를 확인하면, Then `so-adk-core` 버전이 양쪽 모두 `1.0.4` 다.

## 관련 문서

- [SPEC-005 리뷰](SPEC-005-diff-base-hardcoded-main.review-v1.md) — D1·D2·D3 의 출처
- [SPEC-006 리뷰](SPEC-006-review-intent-routing.review-v1.md) — D2 의 F1·R3 그물 구멍
- [SPEC-007 리뷰](SPEC-007-standalone-handoff-leak.review-v1.md) — D2 의 의미 반전, D4, 체인 위험(음성)

## 검토 이력

| 버전 | 날짜 | 내용 |
| ---- | ---- | ---- |
| v1 | 2026-08-27 | 최초 Draft. `so-reviewer` 사후 검토 3건의 지적 중 **직접 재현해 검증된 것만** 범위에 넣었다. `so-debugger` 체인 단절 위험은 3/3 측정으로 **음성 확정**해 제외했다. |

## 구현 결과 (2026-08-27)

### 수정 내용

- **R1 자기참조 가드** — `so-preflight`·`so-security`·`pr/SKILL.md` 3곳의 탐지 체인 1단계-2 에 "얻은 이름이 현재 브랜치와 같으면 채택하지 말고 3단계로 내려간다" 를 추가.
- **R2 `git log` 표기 대응** — `pr/SKILL.md` 에 후보별 `git diff`/`git log` 대응표 추가(`HEAD~1` → `git log -1`).
- **R3 회귀 테스트 강화** — 세 검사 전부 보강. 자기참조 가드 존재, `판정을 유보`·`기준선 명시`·`변경이 없으면 GO 가 아니다`(SPEC-005 R2/R3), `so-adk-core:code-review` 부재(SPEC-006 F1), 대상 불명 되묻기 행 존재(SPEC-006 R3), 정규 문안이 `## Rules` 절 안에 존재(SPEC-007).
- **R4 억제 규칙 확장** — `so-planner`·`so-developer`·`so-performance`·`so-explainer` 4개 추가, 검사 대상을 **7개로 확장**. SPEC-007 본문에 정정 주석과 검토 이력 v1.1 추가.
- **`plugin.json` + `marketplace.json`** — `so-adk-core` `1.0.3` → `1.0.4`.
- 검사 수는 47 로 동일하나 **각 검사의 단언이 늘었다**(신설이 아니라 보강).

### 뮤테이션 검증 (AC-R3a~d)

보강 전 전부 통과하던 4종이 이제 전부 FAIL 한다. 대조군(뮤테이션 없음)은 PASS.

| 뮤테이션 | 보강 전 | 보강 후 |
| -------- | ------- | ------- |
| SPEC-005 R2·R3 문구 삭제 | PASS | **FAIL** `check_diff_base_detection` |
| 위임 대상 → `so-adk-core:code-review` | PASS | **FAIL** `check_review_intent_routing` |
| 대상 불명 되묻기 행 삭제 | PASS | **FAIL** `check_review_intent_routing` |
| 억제 규칙 의미 반전 | PASS | **FAIL** `check_standalone_handoff_rule` |
| (대조) 뮤테이션 없음 | PASS | PASS — 47/0/1 |

### 런타임 검증

| AC | 픽스처 | 채택 기준선 | 결과 |
| -- | ------ | ----------- | ---- |
| AC-R1a | **P** (`origin/HEAD` 없음 + feature 브랜치 + upstream) | `main...HEAD` (**3 files**) | ✅ 수정 전 1파일 → **3파일 전부**. `rce.py`(command injection)·`secret.py`(시크릿)·`sql.py`(SQLi) 모두 검출 |
| AC-R1b | B (트렁크=develop) | `@{u}...HEAD` | ✅ SPEC-005 와 동일 — 회귀 없음 |
| AC-R1b | E (`origin/HEAD` 없음, 트렁크 위) | `@{u}...HEAD` | ✅ 동일. 출력이 가드 발동을 명시 |

**D1 해소 실증**: 픽스처 P 는 SPEC-005 가 없애려던 "부분 리뷰 후 조용한 통과" 를 재현하던 구성이며, 이제 트렁크가 `feat/x` 가 아니라 `main` 으로 잡힌다.

### 정직 표기

- **`so-security`·`pr` 스킬은 R1 가드를 런타임 검증하지 않았다.** 동일 문안을 넣었으나 실제 호출로 확인한 것은 `so-preflight` 뿐이다.
- R4 로 추가한 4개 중 **`so-planner` 만** 런타임 측정했다(n=1). 나머지 3개는 동일 문안이라는 추정에 기댄다.
- 각 픽스처 n=1 이고 sonnet 으로만 측정했다.
- 세 리뷰의 Low 등급 지적 중 본 SPEC 이 다루지 않은 것들이 남아 있다.
- **본 SPEC 자신은 `so-reviewer` 검토를 거치지 않았다.** SPEC-005~007 과 같은 공백이 재발한 상태다.
