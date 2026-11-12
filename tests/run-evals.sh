#!/usr/bin/env bash
# tests/run-evals.sh — SO-ADK 라우팅 회귀 eval (SPEC-009 R5)
#
# 실제 모델을 호출하므로 비용이 든다 (실측: 케이스 1회 ≈ $0.3, 기본 9케이스 × runs).
# run-checks.sh 에 넣지 않은 이유가 이것이다 — 커밋마다가 아니라 orchestrator/에이전트
# description 을 바꿨을 때 돌린다.
#
#   bash tests/run-evals.sh                 # 전 케이스, runs=1
#   bash tests/run-evals.sh --runs 3        # 흔들림 확인
#   bash tests/run-evals.sh --case 'route-merge*'
#
# 메모:
# - 대상은 저장소 루트(.) — 케이스가 orchestrator 와 core 를 함께 로드해야 하는데, eval 은
#   대상 디렉터리 밖 플러그인을 로드하지 못한다 (containment root).
# - --ablation none: 플러그인 없는 기준선은 이 스위트에서 의미가 없다 (so-* 에이전트가 없으면 전부 실패).
# - --scaffold: route-spec-review-reviewer 의 fixture.sh (저장소에 커밋된, 우리가 작성한 스크립트).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec claude plugin eval . --ablation none --scaffold --trust-plugin --no-publish --runs 1 "$@"
