# SO-ADK

**Claude Code를 위한 에이전트 개발 키트** — 마크다운만으로 만든 오케스트레이션 프레임워크.

[English](README.md)

---

## SO-ADK란?

SO-ADK는 Claude Code가 **전략적 오케스트레이터**처럼 자율적으로 동작하게 만드는 프레임워크입니다. 자연어를 인식해서 상황에 맞는 에이전트를 스스로 선택하고 호출합니다. 슬래시 명령어 없이도 됩니다.

*"로그인 기능 만들어줘"* 한 마디면 전체 파이프라인이 자동으로 실행됩니다:

```text
[1] Planner    → 요구사항 분석, SPEC 작성 → specs/ 에 자동 저장
[2] Reviewer   → SPEC 검토 → 사용자 확인 요청 ✋
[3] Architect  → 파일 구조 및 인터페이스 설계
[4] Tester     → 실패하는 테스트 먼저 작성 (TDD RED)
[5] Developer  → 테스트가 통과할 때까지 구현 (TDD GREEN)
     ↑ 테스트 통과까지 루프
[6] Quality    → 리팩토링 및 코드 정리 (TDD REFACTOR)
[7] Docs       → 문서 업데이트 + SPEC 상태 Done으로 변경
```

**바이너리 없음. 의존성 없음. 순수 마크다운.**

---

## 설치

### 전역 설치 (모든 프로젝트에서 에이전트·스킬 사용 가능)

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# Windows PowerShell 7+
irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex
```

### 로컬 설치 (현재 프로젝트에만, CLAUDE.md도 함께 추가)

```bash
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --local
```

---

## 사용법

### 그냥 말하면 됩니다

SO-ADK가 자연어에서 의도를 감지하고 자동으로 라우팅합니다:

| 말하면 | 동작 |
| ------ | ---- |
| "로그인 기능 만들어줘" | 7단계 전체 파이프라인 자동 실행 |
| "결제 모듈 스펙 짜줘" | Planner 에이전트가 SPEC을 `specs/`에 저장 |
| "이 코드 리팩토링해줘" | Quality 에이전트가 검토 및 리팩토링 |
| "PR 만들어줘" | PR 초안 작성 후 확인 요청 |
| "도움말" | 사용 가능한 기능 안내 |

### 선택적 슬래시 명령어 (단축키)

꼭 필요하지 않지만, 명시적으로 제어하고 싶을 때 사용합니다:

| 명령어 | 설명 |
| ------ | ---- |
| `/dev "기능 설명"` | 전체 파이프라인: Plan → Review → Design → Test → Build → Quality → Docs |
| `/plan "기능 설명"` | SPEC 문서만 생성 |
| `/simplify` | 기존 코드 리뷰 및 리팩토링 |
| `/pr` | 구조화된 설명과 함께 PR 생성 |

---

## 동작 원리

SO-ADK는 세 가지로 이루어져 있습니다:

1. **`CLAUDE.md`** — 오케스트레이터 두뇌. 자연어 의도 감지 → Agent tool로 에이전트 자율 호출 → SPEC 상태 관리 → 체크포인트 처리
2. **`.claude/agents/`** — 7개 전문 에이전트. `model`, `maxTurns`, `skills`가 설정된 정식 Claude Code 에이전트
3. **`.claude/skills/internal/`** — 에이전트 시작 시 로드되는 공유 빌딩 블록 (공통 원칙, TDD 워크플로우, SPEC 형식 규칙)

### 에이전트별 모델 배정

| 에이전트 | 모델 | 이유 |
| -------- | ---- | ---- |
| Planner | opus | SPEC 품질이 이후 전체를 결정 |
| Reviewer | opus | 리스크 탐지에 깊은 추론 필요 |
| Architect | opus | 설계 결정이 구현 전체에 영향 |
| Tester | sonnet | 패턴 기반 테스트 작성 |
| Developer | sonnet | 반복 구현 루프 |
| Quality | sonnet | 코드 리뷰 및 리팩토링 |
| Docs | haiku | 문서 작업, 비용 효율 |

---

## 파일 구조

```text
so-adk/
├── CLAUDE.md                        # 오케스트레이터 두뇌 (항상 활성화)
├── install.sh                       # macOS/Linux 설치 스크립트
├── install.ps1                      # Windows 설치 스크립트
├── specs/                           # SPEC 파일 자동 저장 폴더
└── .claude/
    ├── agents/
    │   ├── planner.md               # 요구사항 → SPEC (opus)
    │   ├── reviewer.md              # SPEC 검토 + 체크포인트 (opus)
    │   ├── architect.md             # 파일 구조 + 인터페이스 (opus)
    │   ├── tester.md                # 테스트 먼저 작성 — TDD RED (sonnet)
    │   ├── developer.md             # 테스트 통과까지 구현 — TDD GREEN (sonnet)
    │   ├── quality.md               # 리팩토링 — TDD REFACTOR (sonnet)
    │   └── docs.md                  # 문서 업데이트 (haiku)
    └── skills/
        ├── internal/
        │   ├── so-foundation.md     # 모든 에이전트 공통 원칙
        │   ├── so-tdd-workflow.md   # TDD RED/GREEN/REFACTOR 규칙
        │   └── so-spec-format.md    # SPEC 파일 형식 및 명명 규칙
        ├── dev.md                   # /dev — 선택적 단축키
        ├── plan.md                  # /plan — 선택적 단축키
        ├── simplify.md              # /simplify — 선택적 단축키
        └── pr.md                    # /pr — 선택적 단축키
```

---

## 철학

> 엔지니어의 역할은 코드 작성에서 하네스 설계로 전환됩니다: SPEC, 품질 게이트, 피드백 루프.

- **자율 라우팅** — 슬래시 명령어 없이 자연어만으로 에이전트 자동 호출
- **SPEC 우선** — 명확한 스펙 없이는 구현하지 않음, 항상 `specs/`에 저장
- **기본 TDD** — 항상 구현 전 테스트 작성
- **사람 체크포인트** — Reviewer 완료 후 파이프라인 일시 정지, 승인 후 진행
- **최소 코드** — 필요한 것만 구현하고, 이후 정리

---

## 라이선스

MIT
