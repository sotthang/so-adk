#!/usr/bin/env bash
# Status 는 Done — 그 외 값이면 orchestrator Step 0 이 "이어서 진행할까요?" 로 멈춘다
set -euo pipefail
mkdir -p specs
cat > specs/SPEC-001-todo-reminder.md <<'SPEC'
# SPEC-001: 할 일 마감일 알림

**Status**: Done

## Goal
마감 24시간 전에 사용자에게 알림을 보낸다.

## Acceptance Criteria
- AC-1: 마감 24시간 전 알림이 1회 발송된다.
SPEC
