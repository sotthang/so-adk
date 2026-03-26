# SO-ADK

**Claude Code를 위한 에이전트 개발 키트** — 마크다운만으로 만든 오케스트레이션 프레임워크.

[English](README.md)

---

## SO-ADK란?

SO-ADK는 Claude Code가 **전략적 오케스트레이터**처럼 자율적으로 동작하게 만드는 프레임워크입니다. 자연어를 인식해서 상황에 맞는 에이전트를 스스로 선택하고 호출합니다. 슬래시 명령어 없이도 됩니다.

*"로그인 기능 만들어줘"* 한 마디면 전체 파이프라인이 자동으로 실행됩니다:

```text
[Greenfield — 신규 기능]
[1] Planner    → 요구사항 분석, SPEC 작성 → specs/ 에 자동 저장
[2] Reviewer   → SPEC 검토 → 사용자 확인 요청 ✋
[3] Architect  → 파일 구조 및 인터페이스 설계
[4] Tester     → 실패하는 테스트 먼저 작성 (TDD RED)
[5] Developer  → 테스트가 통과할 때까지 구현 (TDD GREEN)
     ↑ 테스트 통과까지 루프
[6] Quality    → 리팩토링 및 코드 정리 (TDD REFACTOR)
[7] Docs       → 문서 업데이트 + SPEC 상태 Done으로 변경

[Brownfield — 기존 코드 변경]
     Debugger / Developer → Tester → Quality (SPEC 불필요)

[PR 게이트 — 자동 실행]
     Preflight → Security → PR 생성
```

**바이너리 없음. 의존성 없음. 순수 마크다운.**

---

## 설치

SO-ADK를 사용할 프로젝트 안에서 실행하세요:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# Windows PowerShell 7+
irm https://raw.githubusercontent.com/sotthang/so-adk/main/install.ps1 | iex
```

이게 전부입니다. 현재 프로젝트의 `.claude/` 폴더에 모두 설치됩니다.

`.claude/` 폴더를 git에 커밋하면 팀원 전체가 동일한 환경을 사용할 수 있습니다.

---

## 사용법

### 그냥 말하면 됩니다

SO-ADK가 자연어에서 의도를 감지하고 자동으로 라우팅합니다:

| 말하면 | 동작 |
| ------ | ---- |
| "로그인 기능 만들어줘" | 7단계 전체 파이프라인 자동 실행 |
| "이 버그 고쳐줘" | Debugger → Developer → Tester |
| "이 코드 설명해줘" | Explainer 에이전트가 읽고 설명 |
| "이 코드 리팩토링해줘" | Quality 에이전트가 검토 및 리팩토링 |
| "보안 검토해줘" | Security 에이전트가 OWASP 기준으로 분석 |
| "PR 만들어줘" | Preflight + Security → PR 초안 생성 |
| "도움말" | 사용 가능한 기능 안내 |

### 선택적 슬래시 명령어 (단축키)

| 명령어 | 설명 |
| ------ | ---- |
| `/dev "기능 설명"` | 전체 파이프라인: Plan → Review → Design → Test → Build → Quality → Docs |
| `/plan "기능 설명"` | SPEC 문서만 생성 |
| `/simplify` | 기존 코드 리뷰 및 리팩토링 |
| `/pr` | 구조화된 설명과 함께 PR 생성 |

---

## 동작 원리

SO-ADK는 세 가지 레이어로 이루어져 있습니다:

1. **`CLAUDE.md`** — 오케스트레이터를 import합니다. 자연어 의도 감지 → 에이전트 자율 호출 → SPEC 상태 관리 → 체크포인트 및 세션 재개 처리
2. **`.claude/agents/`** — 11개 전문 에이전트. `model`, `maxTurns`, `skills`가 설정된 정식 Claude Code 에이전트
3. **`.claude/skills/internal/`** — 에이전트 시작 시 로드되는 공유 빌딩 블록 (공통 원칙, TDD 워크플로우, SPEC 형식 규칙)

### Greenfield vs Brownfield 자동 감지

SO-ADK가 요청 유형을 자동으로 판단합니다:

- **Greenfield** (신규 기능) → SPEC 포함 7단계 전체 파이프라인
- **Brownfield** (기존 코드 변경) → SPEC 생략, 해당 에이전트로 직행

### 세션 재개

파이프라인이 중간에 중단된 경우, 다음 세션에서 미완료 SPEC을 감지하고 중단된 지점부터 이어서 진행할지 물어봅니다.

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
| Debugger | sonnet | 근본 원인 분석 및 재현 테스트 작성 |
| Explainer | sonnet | 코드 읽기 및 설명 |
| Preflight | sonnet | 테스트/린트 실행 및 diff 검토 |
| Security | opus | 깊은 보안 분석에 강한 추론 필요 |

---

## 파일 구조

```text
your-project/
├── CLAUDE.md                          # @.claude/so-orchestrator.md
├── specs/                             # SPEC 파일 자동 저장 폴더
└── .claude/
    ├── so-orchestrator.md             # 오케스트레이터 두뇌
    ├── agents/
    │   ├── so-planner.md              # 요구사항 → SPEC (opus)
    │   ├── so-reviewer.md             # SPEC 검토 + 체크포인트 (opus)
    │   ├── so-architect.md            # 파일 구조 + 인터페이스 (opus)
    │   ├── so-tester.md               # 테스트 먼저 작성 — TDD RED (sonnet)
    │   ├── so-developer.md            # 테스트 통과까지 구현 — TDD GREEN (sonnet)
    │   ├── so-quality.md              # 리팩토링 — TDD REFACTOR (sonnet)
    │   ├── so-docs.md                 # 문서 업데이트 (haiku)
    │   ├── so-debugger.md             # 근본 원인 분석 + 재현 테스트 (sonnet)
    │   ├── so-explainer.md            # 코드 설명, 읽기 전용 (sonnet)
    │   ├── so-preflight.md            # PR 전 안전 체크 (sonnet)
    │   └── so-security.md             # OWASP 보안 검토 (opus)
    └── skills/
        ├── internal/
        │   ├── so-foundation.md       # 모든 에이전트 공통 원칙
        │   ├── so-tdd-workflow.md     # TDD RED/GREEN/REFACTOR 규칙
        │   └── so-spec-format.md      # SPEC 파일 형식 및 상태 라이프사이클
        ├── dev.md                     # /dev — 선택적 단축키
        ├── plan.md                    # /plan — 선택적 단축키
        ├── simplify.md                # /simplify — 선택적 단축키
        └── pr.md                      # /pr — 선택적 단축키
```

---

## 철학

> 엔지니어의 역할은 코드 작성에서 하네스 설계로 전환됩니다: SPEC, 품질 게이트, 피드백 루프.

- **자율 라우팅** — 슬래시 명령어 없이 자연어만으로 에이전트 자동 호출
- **SPEC 우선** — 명확한 스펙 없이는 구현하지 않음, 항상 `specs/`에 저장
- **기본 TDD** — 항상 구현 전 테스트 작성
- **사람 체크포인트** — Reviewer 완료 후 파이프라인 일시 정지, 승인 후 진행
- **Greenfield/Brownfield 인식** — 신규 기능은 전체 파이프라인, 기존 코드 변경은 직접 라우팅
- **보안 게이트** — 모든 PR은 자동으로 Preflight + Security 검토를 거침

---

## 라이선스

MIT
