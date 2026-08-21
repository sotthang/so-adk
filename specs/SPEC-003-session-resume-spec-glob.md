# SPEC-003: SessionStart 재개 훅의 SPEC 글롭 과매칭 수정

**Status**: Draft
**Created**: 2026-08-21

## Goal

세션 시작 시 주입되는 "진행 중인 SPEC" 안내가 SPEC 본문이 아닌 동반 문서(`.arch.md`·`.review-v{N}.md`)까지 미완료로 보고하는 문제를 없애, 사용자가 실제로 이어서 할 일 하나를 즉시 식별할 수 있게 한다.

## Background

### 결함 (SPEC-001 F24 — 실측 확인)

`plugins/so-adk-core/hooks/session-start-resume.sh:15`의 글롭이 SPEC 본문과 동반 문서를 구분하지 않는다:

```bash
for f in specs/SPEC-*.md; do
  status="$(grep -m1 -iE '^[[:space:]]*(\*\*)?Status(\*\*)?[[:space:]]*:' "$f" | ...)"
  [ -z "$status" ] && status="(unknown)"
  case "$status" in
    Done|done|DONE) ;;
    *) PENDING="${PENDING}  - ${f} (Status: ${status})"$'\n' ;;
  esac
done
```

동반 문서에는 `**Status**:` 라인이 없다 → `(unknown)`으로 떨어진다 → `case` 문이 `Done` 외 **전부**를 pending으로 취급한다.

SPEC-001 AC-R2c 스모크에서 실제로 관측된 출력:

```text
⏸️ SO-ADK: 진행 중인(미완료) SPEC이 있습니다. ...
  - specs/SPEC-001-plugin-migration.arch.md (Status: (unknown))      ← 동반 문서
  - specs/SPEC-001-plugin-migration.md (Status: In Progress)         ← 유일한 진짜 미완료
  - specs/SPEC-001-plugin-migration.review-v3.md (Status: (unknown)) ← 동반 문서
  - specs/SPEC-002-pipeline-verification-gap.arch.md (Status: (unknown))
  - specs/SPEC-002-pipeline-verification-gap.review-v1.md (Status: (unknown))
```

두 가지 피해가 있다:

1. **신호 대 잡음**: 실제 미완료 1건이 잡음 4건에 묻힌다.
2. **거짓 보고**: `SPEC-002`는 `Status: Done`이라 정상 제외되는데, **그 동반 문서 2건은 진행 중으로 표시된다.** 완료된 작업이 미완료로 보인다.

### 왜 지금까지 살아남았나

`tests/run-checks.sh`에 `session-start-resume.sh`의 **동작 테스트가 하나도 없다.** `check_hook_exists_executable`(:311)과 `check_hooks_json_valid`(:868)가 파일 존재와 실행 권한만 확인한다. `post-edit-check.sh`는 동작 테스트 4종(`check_hook_empty_dir`·`check_hook_npm_lint_ok`·`check_hook_npm_lint_fail`·`check_hook_python_no_tools`)을 갖고 있어 비대칭이다.

### 악화 요인

`.review-v{N}.md`는 SPEC-001 v3의 **리뷰 산출물 보존 관행(C-6)** 이 도입한 파일이다. SPEC이 늘고 재검토가 쌓일수록 잡음은 **단조 증가**한다. SPEC 10개 규모에서는 실제 미완료 1건이 잡음 20건 이상에 묻힌다.

### 처분 경위

SPEC-001의 Out of Scope가 "훅 스크립트 **내부 로직**의 의미 변경은 하지 않는다"로 규정하고, 이 결함은 플러그인 전환 이전부터 존재했다(C1은 100% rename). 따라서 SPEC-001에서는 F24로 등재만 하고 수정하지 않았다. 본 SPEC이 그 후속이다.

## Requirements

### R1 — SPEC 본문만 스캔 대상으로 삼는다

- 훅은 파일명이 `SPEC-{NNN}-{slug}.md` 형태인 파일만 대상으로 한다. `slug` 뒤에 추가 확장 세그먼트가 붙은 파일(`.arch.md`, `.review.md`, `.review-v{N}.md`)은 제외한다.
- 판별은 **확장 목록이 아니라 형태**로 한다: 기본명이 `^SPEC-[0-9]{3}-[^.]+\.md$`에 부합할 것. 동반 문서는 `.md` 앞에 점이 하나 더 있으므로 이 형태로 자연히 배제된다.
  - 배제 목록 방식을 쓰지 않는 이유: 장래에 새 동반 문서 종류(`.design.md` 등)가 추가되면 목록을 갱신해야 하고, 갱신 누락이 곧 결함 재발이 된다. 형태 판별은 그 클래스를 원천 차단한다.
- `specs/archive/` 하위는 계속 대상 밖이다(현행 글롭이 하위 디렉터리로 내려가지 않는 동작을 유지).

### R2 — Status 라인이 없는 SPEC 본문은 계속 보고한다

- R1을 통과했는데 `Status` 라인이 없는 파일은 **형식이 깨진 SPEC**이므로 `(unknown)`으로 **계속 보고한다**.
- 즉 "Status 라인 부재"를 배제 기준으로 삼지 않는다. 그렇게 하면 동반 문서는 사라지지만, 진짜 미완료 SPEC이 형식 오류 때문에 **조용히 누락**되는 반대 방향의 결함이 생긴다.

### R3 — 출력 계약과 그 외 동작을 보존한다

- 미완료가 없으면 아무것도 출력하지 않고 exit 0 (현행 유지).
- 출력은 `hookSpecificOutput.additionalContext`를 담은 JSON 1건 (현행 유지).
- `jq` 부재 시 최소 이스케이퍼 폴백 (현행 유지).
- `Done`/`done`/`DONE` 대소문자 허용, `**Status**:` 굵게 표기 허용 등 기존 파싱 관용도 유지.

### R4 — 회귀 방지 테스트 신설

- `tests/run-checks.sh`에 `session-start-resume.sh`의 **동작 테스트**를 추가한다. 현재 이 훅은 동작 테스트가 0종이며, 이 공백이 본 결함이 방치된 직접 원인이다.
- 임시 디렉터리에 `specs/` 픽스처를 구성해 훅을 직접 실행하고 출력 JSON을 검증한다(`post-edit-check.sh`의 기존 4종 테스트와 동일한 방식).

## Out of Scope

- `post-edit-check.sh` 등 다른 훅의 수정.
- SPEC 파일 명명 규칙 자체의 변경 — `so-spec-format` 스킬의 `SPEC-{NNN}-{slug}.md` 규칙은 그대로 둔다.
- 동반 문서(`.arch.md`·`.review-v{N}.md`)의 명명 규칙 변경 — 현행 형태를 전제로 판별한다.
- 재개 안내 문구·`Pipeline Resume Map` 서술의 개선.
- `specs/archive/` 처리 방식 변경.

## Technical Approach

- **수정 파일**: `plugins/so-adk-core/hooks/session-start-resume.sh`, `tests/run-checks.sh`
- **변경 요지**: 루프 본문 진입 전에 기본명 형태 검사를 추가한다.

  ```bash
  for f in specs/SPEC-*.md; do
    b="${f##*/}"
    # SPEC 본문만: slug에 점이 없어야 한다.
    # 동반 문서(.arch.md, .review-v{N}.md)는 .md 앞에 점이 하나 더 있어 배제된다.
    [[ "$b" =~ ^SPEC-[0-9]{3}-[^.]+\.md$ ]] || continue
    ...
  done
  ```

  - `[[ =~ ]]`는 bash 전용이나 스크립트의 shebang이 이미 `#!/usr/bin/env bash`이므로 새 의존이 아니다.
  - `nullglob`은 이미 설정되어 있어 매치 0건일 때의 동작은 그대로다.
- **테스트 설계**: 임시 디렉터리에 아래 픽스처를 만들고 훅을 실행한다.

  | 파일 | Status | 기대 |
  | ---- | ------ | ---- |
  | `SPEC-001-alpha.md` | `In Progress` | 보고됨 |
  | `SPEC-002-beta.md` | `Done` | 제외 |
  | `SPEC-003-gamma.md` | (Status 라인 없음) | `(unknown)`으로 보고됨 (R2) |
  | `SPEC-001-alpha.arch.md` | 없음 | **제외** (R1) |
  | `SPEC-002-beta.review-v1.md` | 없음 | **제외** (R1) |
  | `specs/archive/SPEC-000-old.md` | `In Progress` | 제외 (하위 디렉터리) |

- **Tidy First 분류**: R4(테스트 신설)를 먼저 커밋하면 RED가 되고, R1~R3(스크립트 수정)이 GREEN을 만든다. 두 커밋은 **행위 변경**이며 구조 변경과 섞지 않는다.
- **배포 영향**: 이 훅은 `so-adk-core` 플러그인 자산이므로 수정은 전체 사용자에게 배포된다. R12 릴리스 절차(버전 범프 → `claude plugin tag` → push)를 따른다.

## Acceptance Criteria

- [ ] **AC-R1a**: Given `SPEC-001-alpha.md`(Status `In Progress`)와 `SPEC-001-alpha.arch.md`·`SPEC-002-beta.review-v1.md`가 있는 `specs/`, When 훅을 실행하면, Then 출력 `additionalContext`에 `SPEC-001-alpha.md`가 **포함되고** `.arch.md`·`.review-v1.md`는 **포함되지 않는다**.
- [ ] **AC-R1b**: Given `specs/archive/SPEC-000-old.md`(Status `In Progress`), When 훅을 실행하면, Then 출력에 해당 경로가 포함되지 않는다(하위 디렉터리 미스캔 유지).
- [ ] **AC-R2**: Given `SPEC-003-gamma.md`에 `Status` 라인이 없을 때, When 훅을 실행하면, Then 출력에 `SPEC-003-gamma.md (Status: (unknown))`가 **포함된다** — 형식이 깨진 SPEC은 배제가 아니라 보고 대상이다.
- [ ] **AC-R3a**: Given 미완료 SPEC이 하나도 없는 `specs/`(전부 `Status: Done`이거나 동반 문서뿐), When 훅을 실행하면, Then 출력이 **빈 문자열**이고 exit 0이다.
- [ ] **AC-R3b**: Given 미완료 SPEC이 1건 이상, When 훅을 실행하면, Then 출력이 유효 JSON이고 `.hookSpecificOutput.hookEventName == "SessionStart"`이며 `.hookSpecificOutput.additionalContext`가 비어 있지 않다.
- [ ] **AC-R3c**: Given `jq`를 쓸 수 없는 환경(PATH 조작), When 훅을 실행하면, Then 폴백 이스케이퍼가 동작해 출력이 여전히 유효 JSON이다.
- [ ] **AC-R4**: Given `tests/run-checks.sh`, When 검사 함수 목록을 grep하면, Then `session-start-resume.sh`의 동작을 검증하는 검사가 1종 이상 존재하고, 전체 실행이 FAIL 0이다.
- [ ] **AC-R5** (회귀 재현): Given 본 저장소의 실제 `specs/` 디렉터리, When 훅을 실행하면, Then 보고되는 항목이 **SPEC 본문 파일만**이고 `.arch.md`·`.review-v{N}.md`는 0건이다 — SPEC-001 F24에서 관측된 출력이 재현되지 않는다.

## 관련 문서

- 결함 실측 근거: [SPEC-001-plugin-migration.md](SPEC-001-plugin-migration.md) 확정 사실표 **F24**, 및 잔여 리스크의 "범위 밖 처분 1".
