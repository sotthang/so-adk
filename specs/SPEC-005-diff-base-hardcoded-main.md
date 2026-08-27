# SPEC-005: 리뷰 에이전트의 diff 기준선 하드코딩

**Status**: Done
**Created**: 2026-08-27

## Goal

`so-preflight`·`so-security`·`pr` 스킬이 `main...HEAD`를 고정 기준선으로 쓰는 탓에, 트렁크가 `main`이 아니거나 사용자가 트렁크 위에서 작업 중일 때 **엉뚱한 범위를 리뷰하거나 아무것도 리뷰하지 않는** 문제를 없앤다.

## Background

### 결함 위치

세 곳이 동일한 리터럴을 쓴다.

| 파일 | 행 | 내용 |
| ---- | -- | ---- |
| `plugins/so-adk-core/agents/so-security.md` | 19 | `1. **Scope the review** — read \`git diff main...HEAD\`` |
| `plugins/so-adk-core/agents/so-preflight.md` | 21 | `4. **Diff review** — read \`git diff main...HEAD\`` |
| `plugins/so-adk-core/skills/pr/SKILL.md` | 9 | `1. Run \`git diff main...HEAD\` and \`git log main...HEAD --oneline\`` |

`so-preflight`는 **read-only 안전 게이트**이고 결과가 GO/NO-GO로 PR 생성을 막는다. `so-security`는 "Security findings are always NO-GO" 규칙을 갖는다. 즉 이 두 곳의 오작동은 **안전 게이트의 침묵**으로 직결된다.

### 두 개의 별개 결함이다

착수 시 인지한 것은 D1뿐이었으나, 측정 결과 **D2가 훨씬 지배적**이다.

- **D1 — 트렁크가 `main`이 아닌 저장소**: 기준선이 틀려 **누적 전체**를 현재 변경으로 오인한다.
- **D2 — 사용자가 트렁크 브랜치 위에 있을 때**: `<trunk>...HEAD`가 **공집합**이 되어 리뷰할 것이 없다고 판단한다. 트렁크 기반 개발(feature 브랜치 없이 직접 커밋)에서는 이것이 정상 상태다.

### 실측 (2026-08-27, 로컬 16개 저장소)

`~/Develop` 하위 git 저장소 16개를 전수 조사했다.

| 조건 | 해당 수 | 비율 |
| ---- | ------- | ---- |
| 트렁크가 `main`이 아님 (**D1 피해**) | 2 | 13% |
| 현재 트렁크 브랜치 위에 있음 (**D2 피해**) | **14** | **88%** |
| `refs/remotes/origin/HEAD` 미설정 | 1 | 6% |

**D2가 지배적이다.** 제보 시점에 인지된 D1은 16개 중 2개에만 해당한다.

#### D1 실측 — `Dcty-Agent`

트렁크가 `develop`이고 `CLAUDE.local.md`에 "feature 브랜치 생성 금지, develop에 직접 커밋"이 명시된 저장소다.

```
$ git branch --show-current
develop
$ git diff main...HEAD --stat | tail -1
 41 files changed, 4821 insertions(+), 97 deletions(-)
$ git diff develop...HEAD --stat
(빈 출력)
```

`so-preflight`가 이 저장소에서 리뷰하는 것은 **develop이 main보다 앞선 누적분 41파일 4821줄**이다. 현재 변경이 아니다.

#### D2 실측 — 본 저장소(`so-adk`) 자신

```
$ git branch --show-current
main
$ git diff main...HEAD --stat
(빈 출력)
```

**이 저장소는 자기 자신을 dogfooding하면서 `so-preflight`가 아무것도 못 보는 상태다.** `git diff HEAD~1 --stat`은 5파일 318줄 변경을 보여준다 — 리뷰할 것이 있는데도 게이트는 공집합을 본다.

`so-preflight`의 출력 계약상 공집합은 다음으로 이어진다:

```text
### ✅ Diff review
- 0 files changed
- High-risk areas: (none)
...
## 🟢 GO — 머지 준비 완료
```

즉 **거짓 GO**다. 실패 모드가 "오류"가 아니라 "조용한 통과"라서 사용자가 알아챌 수 없다.

### 탐지 수단 실측

| 방법 | 결과 |
| ---- | ---- |
| `git symbolic-ref --short refs/remotes/origin/HEAD` | 16개 중 **15개에서 성공**. `Dcty-Agent`·`deepreview`에서 정확히 `origin/develop` 반환 |
| `git config init.defaultBranch` | `Dcty-Agent`에서 `main` 반환 — **틀린 답**. 사용 불가 |
| `git rev-parse --abbrev-ref @{u}` | `origin/HEAD`가 없던 `sogul`에서도 `origin/main` 반환 — 유효한 보완재 |
| `gh repo view --json defaultBranchRef` | `gh` 2.96.0 설치 확인. 네트워크·인증 의존이라 최후 수단 |

`init.defaultBranch`는 **측정 결과 틀린 답을 주므로 탐지 체인에서 제외한다.**

### 대체 범위 실측

D2 상황에서 무엇을 리뷰해야 하는지 확인했다.

| 저장소 | 미푸시 커밋 | 미커밋 변경 | 유효한 범위 |
| ------ | ----------- | ----------- | ----------- |
| `Dcty-Agent` | 3 | 0 | `@{u}..HEAD` |
| `Dcty-Hub` | 0 | 2 | `git diff HEAD` |
| `so-adk` | 0 | 0 | `HEAD~1` (직전 커밋) |

세 저장소가 각각 다른 층에서 잡힌다. **단일 대체 명령으로는 부족하고 우선순위 체인이 필요하다.**

## Requirements

### R1 — 트렁크 브랜치 탐지 (D1)

- `main` 리터럴을 제거하고 다음 순서로 트렁크를 탐지한다:
  1. `git symbolic-ref --short refs/remotes/origin/HEAD` → `origin/` 접두 제거
  2. 실패 시 `git rev-parse --abbrev-ref @{u}` → `origin/` 접두 제거
  3. 실패 시 `main` → `master` → `develop` 순으로 **실재하는** 첫 브랜치
  4. 전부 실패하면 트렁크 비교를 포기하고 R2의 하위 단계로 내려간다
- `git config init.defaultBranch`는 **사용하지 않는다** — 실측에서 틀린 답을 반환했다.

### R2 — 리뷰 범위 결정 (D2)

- 트렁크를 안다고 해서 `<trunk>...HEAD`를 무조건 쓰지 않는다. 다음 우선순위로 **비어 있지 않은 첫 범위**를 채택한다:
  1. 현재 브랜치 ≠ 트렁크 이고 `<trunk>...HEAD`가 비어 있지 않으면 → `<trunk>...HEAD`
  2. 미커밋 변경(`git diff HEAD`)이 있으면 → 그것
  3. 미푸시 커밋(`@{u}..HEAD`)이 있으면 → `git diff @{u}...HEAD`
  4. 전부 비면 → `git diff HEAD~1` (직전 커밋)
- 4단계까지 모두 비면 **"리뷰할 변경이 없습니다"를 명시적으로 보고한다.** 이 경우에도 GO를 내지 않는다 — 판정 자체를 유보한다.

### R3 — 사용한 기준선을 출력에 명시

- 세 곳 모두 리뷰 결과 첫머리에 **실제로 사용한 범위**를 한 줄로 적는다. 예: `기준선: origin/develop...HEAD (3 files)`.
- 탐지가 빗나가도 사용자가 즉시 알아볼 수 있게 하는 것이 목적이다. R1·R2의 휴리스틱이 완벽할 수 없다는 전제에서 나온 요구사항이다.

### R4 — 세 파일 일괄 적용

- `so-preflight.md`, `so-security.md`, `pr/SKILL.md` 전부에 동일 규칙을 적용한다.
- `pr` 스킬은 `git log`도 같은 기준선을 쓰도록 함께 고친다.

### R5 — 회귀 방지 테스트

- `tests/run-checks.sh`에 검사를 추가한다:
  - 세 파일에 `main...HEAD` 리터럴이 **존재하지 않을 것**
  - 세 파일에 트렁크 탐지 문구가 존재할 것
- 프롬프트 파일이므로 정적 문자열 검사로만 고정 가능하다. **에이전트의 실제 런타임 동작은 이 테스트로 검증되지 않는다** (아래 미검증 가정 참조).

## Out of Scope

- `so-quality`·`so-debugger` 등 diff를 명시적으로 쓰지 않는 나머지 13개 에이전트.
- 사용자의 git 워크플로를 강제하거나 권고하는 것 — 트렁크 기반이든 feature 브랜치든 양쪽 모두에서 동작시키는 것이 목표다.
- 내장 `/code-review`와의 통합·경계 정리 — 별건이다.
- `install.sh` 계열 — 본 결함과 무관하다.
- 새 `so-code-reviewer` 에이전트 신설 — 별건으로 보류됐다.

## Technical Approach

- **수정 파일**: `plugins/so-adk-core/agents/so-preflight.md`, `.../so-security.md`, `plugins/so-adk-core/skills/pr/SKILL.md`, `tests/run-checks.sh`
- **중복 처리 — 인라인 3벌을 택한다.** 공유 내부 스킬(`so-diff-scope`) 신설을 검토했으나 기각한다:
  - `pr`은 에이전트가 아니라 스킬이고, **스킬이 다른 스킬을 프리로드하는 기제가 이 저장소에 없다** (`skills:` frontmatter는 16개 에이전트에만 존재).
  - 9번째 스킬 신설은 `check_asset_counts`의 `skills=8` 기대값을 건드린다.
  - 결과적으로 에이전트 2곳은 스킬로, 스킬 1곳은 인라인으로 갈라져 **오히려 두 벌 관리**가 된다.
  - 따라서 ~8행 블록을 3벌 인라인하고, 이 중복은 SPEC에 명시된 **의도적 수용**으로 남긴다.
- **버전 범프**: `so-adk-core` 자산이 바뀌므로 `plugins/so-adk-core/.claude-plugin/plugin.json`의 `version`을 `1.0.1` → `1.0.2`로 올린다. 사용자는 `claude plugin update`로 받는다.
- **Tidy First 분류**: 전부 **행위 변경**이다. 구조 변경은 포함하지 않는다.
- **TDD 순서**: R5의 정적 검사를 먼저 작성해 RED를 확인하고(현재 세 파일에 리터럴이 있으므로 즉시 FAIL), 그다음 세 파일을 고쳐 GREEN으로 만든다. RED는 커밋하지 않고 한 커밋으로 묶는다 (SPEC-003·004와 동일).

## 미검증 가정 (Unverified Assumptions)

| ID | 가정 | 상태 |
| -- | ---- | ---- |
| A-1 | 에이전트가 프롬프트에 적힌 탐지 체인을 **실제로 순서대로 수행**한다 | **측정 완료 — 양성.** 아래 "A-1 스파이크 결과" 참조. 5회 측정 전부 통과 |
| A-2 | `origin` 없는 로컬 전용 저장소에서 R1 체인이 안전하게 떨어진다 | **부분 측정 — 양성.** 원격 없는 저장소(픽스처 C)는 확인. **shallow clone은 측정하지 않았다 — 정직 표기** |
| A-3 | R5의 정적 문자열 검사가 회귀를 실질적으로 막는다 | **미측정.** 리터럴만 지우고 탐지 로직을 안 넣어도 통과할 수 있다. 탐지 문구 존재 검사를 함께 걸어 완화하되 **런타임 동작 보증은 아니다** |

## A-1 스파이크 결과 (2026-08-27)

프롬프트 기반 수정의 실효성 자체가 걸려 있어 착수 전 측정했다. 후보 블록(R1+R2+R3)을 작성하고 `claude -p --model sonnet`(so-preflight의 선언 모델과 동일)으로 픽스처 4종에 실행했다.

| 픽스처 | 구성 | 정답 | 실제 채택 | 판정 |
| ------ | ---- | ---- | --------- | ---- |
| **A** | 트렁크=main, 트렁크 위, 미커밋·미푸시 0 (`so-adk` 구성) | `HEAD~1` | `git diff HEAD~1` | ✅ |
| **B** | 트렁크=develop, 트렁크 위, 미푸시 2 (`Dcty-Agent` 구성) | `@{u}...HEAD` | `git diff @{u}...HEAD` | ✅ |
| **C** | 원격 전혀 없음, 커밋 2 (AC-R1c) | 3단계 폴백 → `HEAD~1` | `git diff HEAD~1`, 오류 없음 | ✅ |
| **D** | 커밋 1개뿐, 전 단계 공집합 (AC-R2d) | GO 없이 유보 | "리뷰할 변경이 없습니다. GO를 내지 않습니다." | ✅ |

### 체인 순서 실행 확인 (픽스처 B, `--output-format stream-json`)

"정답을 맞혔다"와 "체인을 순서대로 수행했다"는 다르므로 실제 실행된 Bash 명령을 추출했다.

```
1. git symbolic-ref --short refs/remotes/origin/HEAD        ← 1단계-1, 최초 실행
2. git branch --show-current
   git diff develop...HEAD --stat                           ← 2단계-(a), 공집합
   git diff HEAD --stat                                     ← 2단계-(b), 공집합
   git rev-parse --abbrev-ref @{u}
3. git diff @{u}...HEAD --stat                              ← 2단계-(c), 채택
   git diff HEAD~1 --stat
4. git diff @{u}...HEAD -- secret.py                        ← 채택 범위만 리뷰
```

- 1단계-1이 **가장 먼저** 실행됐고, 2단계는 (a)→(b)→(c) 순서를 지켰다.
- `git config init.defaultBranch`는 **0회 호출**됐다 — 제외 지시가 지켜졌다.

### 통합 검증 — 전체 so-preflight 프롬프트에 삽입

블록이 다른 6단계와 경쟁할 때도 살아남는지가 최대 잔여 위험이었다. 실제 `so-preflight.md` 본문의 4단계를 치환하고 블록을 삽입한 전체 프롬프트로 픽스처 B에 재실행했다.

- 출력 첫머리에 `기준선: git diff @{u}...HEAD (1 files)` + 선택 근거 표기 (R3 충족)
- **`base.py`(develop 누적분)를 "이번 diff에 포함되지 않은 기존 파일"로 명시 제외** — D1 결함이 정확히 회피됐다
- `secret.py`의 하드코딩 시크릿·SQL 인젝션 2건 검출 → 🔴 **NO-GO**
- Preflight 출력 형식(Tests/Lint/Security/Diff review/SPEC compliance/GO-NO-GO) 전부 유지

### 스파이크의 한계 (정직 표기)

- **각 픽스처 n=1이다.** 반복 실행으로 분산을 측정하지 않았다.
- **Sonnet으로만 측정했다.** `so-preflight`의 선언 모델과는 일치하지만 `so-security`는 `model: opus`이며 별도 측정하지 않았다.
- **`pr` 스킬은 측정하지 않았다.** 에이전트가 아니라 스킬이라 로딩 경로가 다르다.
- shallow clone은 픽스처에 포함하지 않았다 (A-2).

## Acceptance Criteria

- [x] **AC-R1a**: Given 트렁크가 `develop`인 저장소, When `so-preflight`를 호출하면, Then 기준선으로 `develop`이 선택되고 `main`이 아니다.
- [x] **AC-R1b**: Given `refs/remotes/origin/HEAD`가 없고 upstream만 있는 저장소(`sogul` 구성), When 탐지를 수행하면, Then 2단계 `@{u}`로 트렁크를 얻는다.
- [x] **AC-R1c**: Given 원격이 전혀 없는 로컬 저장소, When 탐지를 수행하면, Then 오류 없이 3단계 또는 R2 하위로 떨어진다.
- [x] **AC-R2a**: Given 트렁크 브랜치 위에 있고 미커밋 변경이 2개인 저장소(`Dcty-Hub` 구성), When 범위를 결정하면, Then `git diff HEAD`가 채택되고 공집합이 아니다.
- [x] **AC-R2b**: Given 트렁크 위에 있고 미푸시 커밋이 3개인 저장소(`Dcty-Agent` 구성), When 범위를 결정하면, Then `@{u}...HEAD`가 채택된다.
- [x] **AC-R2c**: Given 트렁크 위에 있고 미커밋·미푸시가 모두 0인 저장소(`so-adk` 구성), When 범위를 결정하면, Then `HEAD~1`이 채택되고 리뷰 대상이 비어 있지 않다.
- [x] **AC-R2d** (거짓 GO 차단): Given 4단계까지 모두 공집합인 저장소, When `so-preflight`를 실행하면, Then **GO가 아니라 "리뷰할 변경 없음"으로 판정을 유보**한다.
- [x] **AC-R3**: Given 임의의 저장소, When 리뷰 결과를 확인하면, Then 첫머리에 실제 사용한 기준선이 한 줄로 표기되어 있다.
- [x] **AC-R4**: Given `plugins/` 전체, When `grep -rn 'main\.\.\.HEAD'`를 실행하면, Then 결과가 **0건**이다.
- [x] **AC-R5a**: Given `tests/run-checks.sh`, When 실행하면, Then 신설 검사가 포함되고 전체 FAIL 0이다.
- [x] **AC-R5b** (회귀 고정): Given 세 파일 중 하나에 `main...HEAD`를 되돌려 놓은 상태, When 검사를 실행하면, Then FAIL한다.
- [x] **AC-R6** (배포): Given 수정 완료, When `plugin.json`을 확인하면, Then `version`이 `1.0.2`다.

## 관련 문서

- 결함 발견 경위: `Dcty-Agent`의 로컬 `code-review` 스킬 검토 중 동일 하드코딩을 발견하고 `plugins/` 전수 조사로 확대 (2026-08-27)
- `so-preflight`의 read-only·NO-GO 계약: [so-preflight.md](../plugins/so-adk-core/agents/so-preflight.md)
- SPEC 작성 규약: [so-spec-format](../plugins/so-adk-core/skills/so-spec-format/SKILL.md)

## 검토 이력

| 버전 | 날짜 | 내용 |
| ---- | ---- | ---- |
| v1 | 2026-08-27 | 최초 Draft. 착수 시 인지한 결함은 D1(트렁크≠main)뿐이었으나, 16개 저장소 전수 측정에서 **D2(트렁크 위에서 공집합)가 88%로 지배적**임이 드러나 범위를 확장했다. 본 저장소 자신이 D2 피해자다. |
| v1.2 | 2026-08-27 | `so-security`(opus)·`pr` 스킬 런타임 검증 등재. 세 수정 대상 모두 실제 호출로 확인 완료 — 정직 표기의 미검증 항목 해소. |
| v1.1 | 2026-08-27 | **A-1 스파이크 완료 — 양성.** 후보 블록을 픽스처 4종 + 전체 so-preflight 프롬프트 통합으로 5회 측정, 전부 통과. 체인 순서 실행을 stream-json으로 확인했고 `init.defaultBranch` 미호출도 확인했다. A-2는 부분 측정(원격 없음 ✅ / shallow clone 미측정). 프롬프트 기반 수정이 실효가 있음이 확정되어 **구현 착수 가능**. |

## 구현 결과 (2026-08-27)

### 수정 내용

- **`so-preflight.md`**: 4단계를 「리뷰 범위 결정」 참조로 바꾸고 블록을 삽입. 출력 템플릿 첫머리에 `기준선:` 행 추가. **판정 3번째 상태 `⏸️ 판정 유보` 신설** — 기준선 후보가 모두 비면 GO 대신 유보. Rules 에 "변경이 없으면 GO 가 아니다" 추가.
- **`so-security.md`**: 1단계(Scope the review)를 블록 참조로 교체, 출력 템플릿에 `기준선:` 행 추가.
- **`pr/SKILL.md`**: 기준선 절차를 문서 말미에 별도 절로 배치(번호 목록·PR 템플릿을 깨지 않도록). **PR 은 커밋된 변경이 대상이므로 미커밋(`git diff HEAD`)을 후보에서 제외**한 3단 체인으로 조정했다 — 에이전트 2종과 의도적으로 다르다.
- **`plugin.json` + `.claude-plugin/marketplace.json`**: `1.0.1` → `1.0.2`. **버전은 두 곳에 있다** — `marketplace.json`의 `plugins[].version`이 `plugin.json`과 어긋나면 `claude plugin validate --strict`가 실패한다(`check_plugin_validate_marketplace`). 구현 중 실제로 밟았다.
- **`tests/run-checks.sh`**: `check_diff_base_detection` 신설. 44 → **45 passed / 0 failed / 1 skipped**.

### 테스트 설계 정정 (RED 중 발견)

최초 작성한 검사는 세 파일에 `init.defaultBranch` 문자열이 **없을 것**을 요구했다. 그러나 블록 자체가 "`git config init.defaultBranch` 는 사용하지 않는다"라는 **금지 문장**으로 그 문자열을 포함하므로, 정적 검사는 '언급'과 '사용'을 구분할 수 없어 오탐했다. 검사 의도를 뒤집어 **금지 지시의 존재**를 요구하도록 정정했다.

### 배포 파일 런타임 검증 (픽스처 6종, 실제 `so-preflight.md` 본문 사용)

| 픽스처 | 구성 | 채택된 기준선 | 판정 | AC |
| ------ | ---- | ------------- | ---- | -- |
| **A** | 트렁크=main, 트렁크 위, 깨끗 | `HEAD~1` (d) | 🔴 NO-GO (ZeroDivisionError 검출) | AC-R2c |
| **B** | 트렁크=develop, 미푸시 2 | `@{u}...HEAD` (c) | 🔴 NO-GO (시크릿·SQLi 검출) | AC-R1a, AC-R2b |
| **C** | 원격 전혀 없음 | `HEAD~1`, 오류 없음 | 🟢 GO | AC-R1c |
| **D** | 커밋 1개, 전 단계 공집합 | 없음 | ⏸️ **판정 유보** | AC-R2d |
| **E** | `origin/HEAD` 없음 + upstream 있음 | 1단계-2 `@{u}` → `origin/main`, (c) 채택 | 🟢 GO | AC-R1b |
| **F** | 트렁크 위 + 미커밋 변경 | `git diff HEAD` (b) | 🔴 NO-GO (`eval(user_input)` RCE 검출) | AC-R2a |

6종 전부 기준선을 출력 첫머리에 표기했다(AC-R3). **픽스처 B 에서 `base.py`(develop 누적분)를 명시적으로 범위 밖으로 제외**하는 것을 확인해 D1 결함 해소를 실증했다.

### `so-security` 런타임 검증 (2026-08-27 추가, `model: opus`)

선언 모델과 동일하게 opus 로 픽스처 B 에 실행했다.

```
Scope confirmed: 2 unpushed commits, one new file.
base.py is unchanged (context only, no `uid` defined there).
기준선: git diff @{u}...HEAD (1 file)
```

- 기준선 표기 정상(AC-R3), 채택 범위 `@{u}...HEAD` 정상.
- **`base.py`(develop 누적분)를 명시적으로 범위 밖 처리** — D1 결함 회피를 `so-preflight` 와 독립적으로 재확인했다.
- Critical 2건(SQLi·하드코딩 자격증명) 검출. `uid` 미정의로 현재 실행 경로에서는 악용 불가하나 "방어 장치가 아니라 미완성 코드"라며 Critical 을 유지했다.

### `pr` 스킬 런타임 검증 (2026-08-27 추가)

`pr` 은 에이전트 2종과 **의도적으로 다른 3단 체인**(미커밋 제외)이므로 두 경로를 각각 확인했다.

| 픽스처 | 구성 | 채택 기준선 | 결과 |
| ------ | ---- | ----------- | ---- |
| **I** | feature 브랜치, 트렁크=develop | `develop...HEAD` (1 files) | ✅ 구 동작이면 `main...HEAD`=2파일로 누적분 포함 |
| **J** | 트렁크 위, 미커밋 1건, 미푸시 0건 | 없음 | ✅ "PR 은 커밋된 변경을 대상으로 하므로 기준선을 잡을 수 없다" — 커밋을 먼저 요구 |

- 픽스처 I 에서 확인 요청 후 정지했고 `gh pr create` 는 **0회 호출**, 워킹트리 변경도 없었다.
- 픽스처 J 는 미커밋 제외 설계가 의도대로 작동함을 보인다 — 에이전트 2종이었다면 `git diff HEAD` 를 채택했을 상황이다.

### 정직 표기

- **각 픽스처 n=1이다.** 반복 실행으로 분산을 측정하지 않았다.
- **세 대상 모두 런타임 검증을 마쳤다** — `so-preflight`(sonnet, 픽스처 6종), `so-security`(opus, 1종), `pr` 스킬(sonnet, 2종). 다만 `so-security` 와 `pr` 은 각 모델·경로당 **1회씩**이다.
- 모델은 `so-preflight`·`pr` 은 sonnet, `so-security` 는 opus 로 각각 선언 모델과 일치시켰다. 교차 모델 측정은 하지 않았다.
- shallow clone 은 픽스처에 없다 (A-2 부분 측정).
- **본 SPEC 은 `so-reviewer` 검토를 거치지 않았다.** SPEC-001·004 와 달리 `review-v*.md` 가 없다.
