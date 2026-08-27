---
name: pr
description: Shortcut to create a pull request with structured description. Claude normally triggers this automatically — use this for explicit control.
user-invocable: true
---

Create a pull request for the current branch.

1. 아래 「기준선 결정」 절차로 기준선을 정한 뒤, 그 기준선으로 `git diff <기준선>` 과 `git log <기준선> --oneline` 을 실행해 변경을 파악한다
2. Draft PR title and body:

```
## Summary
- (2-3 bullet points)

## Changes
- Key files modified

## Test plan
- [ ] Tests written and passing
- [ ] Manual verification steps

## SPEC reference
- (SPEC file path if applicable)
```

3. Ask: "이 내용으로 PR을 생성할까요?"
4. Only create after user confirms via `gh pr create`

## 기준선 결정

`main` 을 기준선으로 가정하지 말 것. 아래 순서를 **그대로** 수행한다.

### 1단계 — 트렁크 브랜치 탐지 (첫 성공에서 멈춘다)

1. `git symbolic-ref --short refs/remotes/origin/HEAD` → 출력에서 `origin/` 접두를 뗀다
2. 실패하면 `git rev-parse --abbrev-ref @{u}` → `origin/` 접두를 뗀다
3. 실패하면 `main`, `master`, `develop` 순으로 `git rev-parse --verify <name>` 이 성공하는 첫 이름
4. 전부 실패하면 트렁크 비교를 건너뛰고 2단계의 (b)부터 시작한다

`git config init.defaultBranch` 는 사용하지 않는다 — 실측에서 틀린 답을 반환했다.

### 2단계 — 범위 선택 (비어 있지 않은 첫 범위를 채택)

- (a) 현재 브랜치가 트렁크와 **다르면** `<트렁크>...HEAD`
- (b) `@{u}...HEAD` — 미푸시 커밋
- (c) `HEAD~1` — 직전 커밋

PR 은 커밋된 변경을 대상으로 하므로 미커밋 변경(`git diff HEAD`)은 기준선 후보에서 제외한다.
셋 다 비면 **PR 을 만들지 않고** "PR 로 만들 변경이 없습니다"라고 보고한다.

### 3단계 — 기준선 명시

PR 생성 확인을 요청할 때 사용한 기준선을 함께 알린다: `기준선: <사용한 범위> (<N> files)`
