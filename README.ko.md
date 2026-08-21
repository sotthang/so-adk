# SO-ADK

**Claude Code를 위한 에이전트 개발 키트** — 마크다운만으로 만든 오케스트레이션 프레임워크. Claude Code 플러그인으로 배포됩니다.

[English](README.md)

---

## SO-ADK란?

SO-ADK는 Claude Code가 **전략적 오케스트레이터**처럼 자율적으로 동작하게 만드는 프레임워크입니다. 자연어를 인식해서 상황에 맞는 에이전트를 스스로 선택하고 호출합니다. 슬래시 명령어 없이도 됩니다.

*"로그인 기능 만들어줘"* 한 마디면 전체 파이프라인이 자동으로 실행됩니다:

```text
[Greenfield — 신규 기능]
[1] Planner    → 요구사항 분석, SPEC 작성 → specs/ 에 자동 저장
[2] Reviewer   → SPEC 검토 → 사용자 확인 요청 ✋ (수정 시 Planner 재호출)
[3] Architect  → 파일 구조 및 인터페이스 설계 → specs/*.arch.md 저장
[3.5] Scaffold → stub 파일 골격 생성 (신규 프로젝트일 때)
[3.7] Spike    → 미검증 가정 실측, 저장소 사실 검증 (조건부)
[4] Tester     → 실패하는 테스트 먼저 작성 (TDD RED)
[5] Developer  → 테스트가 통과할 때까지 구현 (TDD GREEN)
     ↑ 테스트 통과까지 루프 (최대 5회)
[6] Quality    → 리팩토링 및 코드 정리 (TDD REFACTOR)
[7] Docs       → 문서 업데이트 + SPEC 상태 Done으로 변경

[Brownfield — 기존 코드 변경]
     Debugger / Developer → Tester → Quality (SPEC 불필요)

[PR 게이트 — 자동 실행]
     Preflight + Security (병렬) → PR 생성
```

**바이너리 없음. 의존성 없음. 순수 마크다운.**

SO-ADK는 하나의 마켓플레이스에서 **플러그인 2개**로 배포됩니다:

| 플러그인 | 내용 | 필수 여부 |
| -------- | ---- | --------- |
| `so-adk-core` | 에이전트 16개, 스킬 8개, 훅 2개 | 필수 |
| `so-adk-orchestrator` | 메인 스레드 에이전트를 자연어 라우터로 교체 | 선택 (자동 라우팅의 핵심) |

---

## 설치

> ⚠️ **설치 전에 아래 스코프 경고를 먼저 읽으세요.** 모든 예시에 `--scope` 플래그를 명시한 것은 의도된 것입니다 —
> CLI 기본값(`user` 스코프)은 SO-ADK에 적합하지 않습니다.

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add sotthang/so-adk

# 2. core 플러그인 설치 (에이전트 + 스킬 + 훅)
claude plugin install so-adk-core@so-adk --scope project

# 3. 오케스트레이터 설치 (선택 — 자연어 자동 라우팅 활성화)
claude plugin install so-adk-orchestrator@so-adk --scope project

# 4. 두 플러그인이 실제로 활성화됐는지 확인
claude plugin list
```

4번은 형식적인 절차가 아닙니다. 마켓플레이스 엔트리가 잘못되면 플러그인이 **아무 에러 메시지 없이** `✘ disabled` 상태가 됩니다. 반드시 두 플러그인 모두 `✔ enabled`인지 확인하세요.

저장소에 활성화 상태를 커밋하지 않고 혼자만 쓰려면 `--scope project` 대신 `--scope local`을 사용하세요.

### 스코프

| 스코프 | 기록 위치 | 적용 대상 | SO-ADK 권장 |
| ------ | --------- | --------- | ----------- |
| `--scope project` | `.claude/settings.json` (커밋됨) | 저장소 전체 팀원 | ✅ 권장 |
| `--scope local` | `.claude/settings.local.json` (gitignore됨) | 나 혼자, 이 저장소만 | ✅ 개인/실험용으로 적합 |
| `--scope user` (CLI 기본값) | `~/.claude/settings.json` | **여는 모든 프로젝트** | ⚠️ 경고 참조 |

### ⚠️ 스코프 경고

**`so-adk-orchestrator`는 Project/Local 전용입니다.** 이 플러그인은 메인 스레드 에이전트를 교체합니다. user 스코프로 설치하면 SO-ADK와 무관한 프로젝트를 포함해 **여는 모든 프로젝트**에서 메인 스레드가 교체됩니다. 절대 `--scope user`로 설치하지 마세요.

**`so-adk-core`도 Project/Local을 권장합니다.** user 스코프 설치 시 훅이 전역 발동합니다:

- `PostToolUse`가 **모든 프로젝트**의 **매** `Edit`/`Write`/`MultiEdit` 직후 lint/typecheck를 실행하고, 실패 시 `exit 2`로 편집을 차단합니다.
- `SessionStart`가 **모든 프로젝트**의 **매** 세션 시작 시 `specs/`를 스캔합니다.

이는 기술적으로 차단되지 않는 **문서상 주의사항**입니다. project 또는 local 스코프로 설치하세요.

**`so-adk-orchestrator`는 `so-adk-core`를 필요로 합니다.** 플러그인 매니페스트에 의존성 필드가 없어 이 결합은 어디에서도 강제되지 않습니다. 오케스트레이터만 설치하면 존재하지 않는 에이전트로 디스패치하는 라우터가 됩니다.

### 주의: `--scope project`는 *활성화 범위*의 격리이지 *설치 흔적*의 격리가 아닙니다

`--scope project`로 설치해도 사용자 전역 플러그인 캐시(`~/.claude/plugins/known_marketplaces.json`, `installed_plugins.json` — 후자는 `scope: "project"`와 프로젝트 경로가 함께 기록됨)에는 항목이 남습니다. 다만 `~/.claude/settings.json` 자체는 변경되지 않습니다.

### Context cost 확인

`/plugin` 패널에서 플러그인을 선택하면 **Context cost**를 볼 수 있습니다 — 해당 플러그인의 에이전트·스킬·설정이 세션에 추가하는 토큰량입니다.

---

## 업데이트

```bash
/plugin
```

마켓플레이스 패널에서 **so-adk**를 선택하고 각 플러그인의 *Update*를 실행하세요. CLI로도 가능합니다:

```bash
claude plugin update so-adk-core@so-adk
claude plugin update so-adk-orchestrator@so-adk
```

기존의 `curl ... install.sh | bash` 경로는 더 이상 아무것도 설치하지 않습니다 — [curl 설치 방식에서 마이그레이션](#curl-설치-방식에서-마이그레이션) 참조.

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

플러그인 스킬은 플러그인 이름으로 네임스페이스됩니다:

| 명령어 | 설명 |
| ------ | ---- |
| `/so-adk-core:dev "기능 설명"` | 전체 파이프라인: Plan → Review → Design → Test → Build → Quality → Docs |
| `/so-adk-core:plan "기능 설명"` | SPEC 문서만 생성 |
| `/so-adk-core:refactor` | 기존 코드 리뷰 및 리팩토링 (Quality 에이전트) |
| `/so-adk-core:pr` | 구조화된 설명과 함께 PR 생성 |

#### ⚠️ Breaking change — 스킬 호출명이 변경되었습니다

플러그인 배포로 전환하면서 모든 스킬이 네임스페이스됩니다. 기존의 짧은 이름은 더 이상 동작하지 않습니다:

| 기존 (curl 설치) | 신규 (플러그인) |
| ---------------- | --------------- |
| `/dev` | `/so-adk-core:dev` |
| `/plan` | `/so-adk-core:plan` |
| `/refactor` | `/so-adk-core:refactor` |
| `/pr` | `/so-adk-core:pr` |

자연어 라우팅은 영향받지 않습니다 — *"로그인 기능 만들어줘"*는 이전과 완전히 동일하게 동작합니다.

---

## curl 설치 방식에서 마이그레이션

기존에 `curl ... install.sh | bash`로 SO-ADK를 설치했다면 프로젝트의 `.claude/`에 SO-ADK 파일들이 남아 있습니다. **이 파일들을 반드시 치워야 합니다** — 로컬의 `.claude/agents/so-planner.md`가 동명의 플러그인 에이전트를 override하기 때문에, 그대로 두면 플러그인을 설치해도 조용히 아무 효과가 없습니다.

기존과 동일한 URL이 이제 설치 스크립트가 아니라 **마이그레이션 래퍼**를 서빙합니다. 이 래퍼는 아무것도 삭제하지 않습니다 — SO-ADK 소유 파일을 타임스탬프가 붙은 백업 디렉터리로 **이동**합니다.

```bash
# 1. 진단 — 플래그 없음, 아무것도 변경하지 않음
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash

# 2. 수행 계획 미리보기 — 아무것도 변경하지 않음
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --dry-run

# 3. 실제 마이그레이션 수행
curl -fsSL https://raw.githubusercontent.com/sotthang/so-adk/main/install.sh | bash -s -- --migrate
```

Windows PowerShell 7+ 사용자는 `install.ps1`을 내려받아 동일한 플래그로 실행하세요. **PowerShell 래퍼는 자동 테스트가 없는 베타입니다** — 반드시 `--dry-run`으로 대상을 먼저 확인하고 결과를 수동 검증하세요.

**`--migrate`가 하는 일:**

- SO-ADK 에이전트 16개, SO-ADK 스킬 디렉터리 8개, 훅 2개, `.claude/so-orchestrator.md`를 `.claude/.so-adk-backup-<timestamp>/`로 이동합니다. 사용자가 직접 수정한 파일도 그 백업에 원본 그대로 보존됩니다 — 삭제되는 것은 없습니다.
- `.claude/settings.json`에서 SO-ADK 훅 엔트리만 제거합니다. 그 외 모든 키는 보존됩니다.
- `CLAUDE.md`에서 `@.claude/so-orchestrator.md` 라인만 제거합니다. 나머지 내용은 그대로이며, 그 라인이 파일의 전부였더라도 **파일 자체는 삭제하지 않습니다**.
- 사용자 파일은 건드리지 않습니다. 에이전트와 스킬은 고정 목록 *그리고* 내용 마커를 함께 대조하므로, 직접 만든 `.claude/agents/my-agent.md` 같은 파일은 절대 이동되지 않습니다.

**고아 훅 방지:** `.claude/settings.json`에서 훅 엔트리를 제거할 수 없는 경우 — `jq`가 없거나, 파일이 유효한 JSON이 아닌 경우 — 래퍼는 **어떤 파일도 이동하지 않고** 수동 제거 절차를 출력한 뒤 비0으로 종료합니다. 훅 엔트리가 이동된 스크립트를 가리킨 채 남으면 이후 모든 편집이 실패하기 때문입니다.

**동작 변경:** 래퍼는 `specs/`·`specs/archive/`를 **생성하지 않습니다**. 구 설치 스크립트는 생성했습니다. 필요하면 직접 만드세요:

```bash
mkdir -p specs/archive && touch specs/.gitkeep specs/archive/.gitkeep
```

마이그레이션 후 [설치](#설치) 절차를 따르세요.

**마이그레이션 되돌리기:** `.claude/.so-adk-backup-<timestamp>/`의 내용을 원래 위치로 되돌리고 `CLAUDE.md`에 `@.claude/so-orchestrator.md` 라인을 다시 추가하면 됩니다. 래퍼가 삭제가 아니라 이동을 하므로 항상 가능합니다.

**플러그인 제거:** `claude plugin uninstall so-adk-core@so-adk`. 단, `--scope project`로 설치된 플러그인은 팀과 공유된 것이므로 일반 uninstall이 거부되고 `--scope local`로 disable하라는 안내가 출력됩니다.

---

## 동작 원리

SO-ADK는 세 가지 레이어로 이루어져 있습니다:

1. **`so-adk-orchestrator`** — 플러그인 `settings.json`의 `"agent"` 키로 메인 스레드 에이전트를 교체합니다. 자연어 의도 감지 → 에이전트 자율 호출 → SPEC 상태 관리 → 체크포인트 및 세션 재개 처리. **`CLAUDE.md`는 일절 건드리지 않습니다** — 오케스트레이터는 사용자의 전역/프로젝트 지침과 공존합니다.
2. **`so-adk-core` 에이전트** — 16개 전문 에이전트 (Designer, Performance, Spike, Auditor 포함). `model`, `maxTurns`, `skills`가 설정된 정식 Claude Code 에이전트입니다. 오케스트레이터는 플러그인 경계를 넘어 플레인 이름으로 이들을 호출합니다.
3. **`so-adk-core` 스킬** — 에이전트 시작 시 `skills:` 필드로 프리로드되는 공유 빌딩 블록 (공통 원칙, TDD 워크플로우, SPEC 형식 규칙). 각 스킬은 `<name>/SKILL.md` 디렉터리 형식입니다.

### Greenfield vs Brownfield 자동 감지

SO-ADK가 요청 유형을 자동으로 판단합니다:

- **Greenfield** (신규 기능) → SPEC 포함 7단계 전체 파이프라인
- **Brownfield** (기존 코드 변경) → SPEC 생략, 해당 에이전트로 직행

### 세션 재개

파이프라인이 중간에 중단된 경우, 다음 세션에서 미완료 SPEC을 감지하고 중단된 지점부터 이어서 진행할지 물어봅니다.

### 에이전트별 모델 배정

| 에이전트 | 모델 | 이유 |
| -------- | ---- | ---- |
| Planner | fable | SPEC 품질이 이후 전체를 결정 |
| Reviewer | opus | 리스크 탐지에 깊은 추론 필요 |
| Architect | fable | 설계 결정이 구현 전체에 영향 |
| Designer | opus | UI/프론트엔드 계약 명세 (선택적) |
| Scaffold | sonnet | stub 파일 생성, 반복 작업 |
| Tester | sonnet | 패턴 기반 테스트 작성, 인수→단위 역피라미드 |
| Developer | sonnet | 반복 구현 루프, 편집 직후 자동 린트 |
| Quality | sonnet | 코드 리뷰 및 리팩토링 |
| Docs | haiku | 문서 작업, 비용 효율 |
| Debugger | sonnet | 근본 원인 분석 및 재현 테스트 작성 |
| Explainer | sonnet | 코드 읽기 및 설명 |
| Auditor | sonnet | 데드코드, 레거시 의존성, drift 감지 (stateless) |
| Preflight | sonnet | 테스트/린트 실행 및 diff 검토 |
| Performance | sonnet | 병목/N+1 분석, 읽기 전용 리포트 |
| Spike | sonnet | 미검증 가정 실측, 저장소 사실 검증 |
| Security | opus | 깊은 보안 분석에 강한 추론 필요 |

---

## 저장소 구조

```text
so-adk/
├── .claude-plugin/
│   └── marketplace.json                   # 마켓플레이스 매니페스트 — 두 플러그인 엔트리
├── .claude/
│   └── settings.json                      # 커밋됨: 마켓플레이스 등록 + 활성 상태 기록
├── plugins/
│   ├── so-adk-core/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/                        # 에이전트 16개
│   │   │   ├── so-planner.md              # 요구사항 → SPEC (fable)
│   │   │   ├── so-reviewer.md             # SPEC 검토 + 체크포인트 (opus)
│   │   │   ├── so-architect.md            # 파일 구조 + 인터페이스 (fable)
│   │   │   ├── so-designer.md             # UI 설계 계약 (opus, 선택적)
│   │   │   ├── so-scaffold.md             # stub 파일 골격 생성 (sonnet)
│   │   │   ├── so-tester.md               # 테스트 먼저 작성 — TDD RED (sonnet)
│   │   │   ├── so-developer.md            # 테스트 통과까지 구현 — TDD GREEN (sonnet)
│   │   │   ├── so-quality.md              # 리팩토링 — TDD REFACTOR (sonnet)
│   │   │   ├── so-docs.md                 # 문서 업데이트 (haiku)
│   │   │   ├── so-debugger.md             # 근본 원인 분석 + 재현 테스트 (sonnet)
│   │   │   ├── so-explainer.md            # 코드 설명, 읽기 전용 (sonnet)
│   │   │   ├── so-auditor.md              # Drift 감지 (sonnet, 선택적)
│   │   │   ├── so-preflight.md            # PR 전 안전 체크 (sonnet)
│   │   │   ├── so-performance.md          # 병목 분석, 읽기 전용 (sonnet)
│   │   │   ├── so-spike.md                # 미검증 가정 검증 (sonnet)
│   │   │   └── so-security.md             # OWASP 보안 검토 (opus)
│   │   ├── skills/                        # 각 스킬은 SKILL.md를 가진 디렉터리
│   │   │   ├── so-foundation/SKILL.md     # 모든 에이전트 공통 원칙 (프리로드)
│   │   │   ├── so-tdd-workflow/SKILL.md   # TDD RED/GREEN/REFACTOR 규칙 (프리로드)
│   │   │   ├── so-spec-format/SKILL.md    # SPEC 파일 형식 및 상태 라이프사이클 (프리로드)
│   │   │   ├── so-context/SKILL.md        # 코드베이스 컨텍스트 매퍼 (프리로드)
│   │   │   ├── dev/SKILL.md               # /so-adk-core:dev
│   │   │   ├── plan/SKILL.md              # /so-adk-core:plan
│   │   │   ├── refactor/SKILL.md          # /so-adk-core:refactor
│   │   │   └── pr/SKILL.md                # /so-adk-core:pr
│   │   └── hooks/
│   │       ├── hooks.json                 # SessionStart + PostToolUse 등록
│   │       ├── post-edit-check.sh         # 편집 후 자동 린트/타입체크 (exit 2 → 에러를 에이전트에 피드백)
│   │       └── session-start-resume.sh    # 세션 시작 시 진행 중 SPEC 주입
│   └── so-adk-orchestrator/
│       ├── .claude-plugin/plugin.json
│       ├── agents/so-orchestrator.md      # 오케스트레이터 두뇌
│       └── settings.json                  # "agent": "so-orchestrator" — 메인 스레드 교체
├── install.sh / install.ps1               # 레거시 curl 설치용 마이그레이션 래퍼
├── tests/run-checks.sh                    # 정적 계약 검사
└── specs/                                 # SPEC 파일
```

---

## 개발

*이 섹션은 SO-ADK 자체를 개발하는 사람을 위한 것입니다. SO-ADK를 사용만 한다면 [설치](#설치)까지만 읽으면 됩니다.*

### `plugins/`를 편집한다면 — `plugin install`이 아니라 `--plugin-dir`

```bash
claude --plugin-dir ./plugins/so-adk-core --plugin-dir ./plugins/so-adk-orchestrator
```

이건 **편의를 위한 단축키가 아니고, 전환기의 임시 방편도 아닙니다.** 플러그인 소스를 편집하는 사람에게는 이것이 유일하게 정확한 로드 방식입니다. 이유는 명확합니다:

> `claude plugin install`은 **플러그인을 캐시로 복사해서**(`~/.claude/plugins/cache/...`) 그 사본을 로드합니다. 디렉터리 소스여도 마찬가지입니다. 작업 트리의 `plugins/` 편집 내용은 **설치본에 반영되지 않으며** — 에러도, 경고도, 어떤 증상도 없습니다. 자기 변경을 테스트했다고 믿으면서 실제로는 낡은 스냅샷을 테스트하게 됩니다.

이 저장소에 커밋된 마켓플레이스 소스는 **github 소스**이므로, `plugin install`은 기본 브랜치의 published 사본을 가져옵니다 — 로컬 편집이 반영되지 않는 두 번째 이유입니다.

원칙: **사용자는 `plugin install`, 플러그인 개발자는 `--plugin-dir`.**

### 기여자 온보딩 (이 저장소에서 SO-ADK를 사용만 하는 경우)

커밋된 `.claude/settings.json`이 해주는 것은 **등록이지 설치가 아닙니다**:

- `extraKnownMarketplaces` — `so-adk` 마켓플레이스가 세션에 자동 등록됩니다. ✅
- `enabledPlugins` — 이건 의도한 상태의 **기록**입니다. 아무것도 **활성화하지 않습니다**.

이 파일만 커밋된 상태로 세션을 열면 플러그인은 **로드되지 않습니다**. 기여자마다 설치를 1회 실행해야 합니다:

```bash
claude plugin install so-adk-core@so-adk --scope project
claude plugin install so-adk-orchestrator@so-adk --scope project
claude plugin list   # 두 플러그인 모두 ✔ enabled 확인 — 엔트리가 잘못되면 무증상으로 disabled 됩니다
```

이 설치는 멱등합니다. 이미 커밋된 `.claude/settings.json`이 있는 상태에서 재실행하면 `already installed`가 출력되고 파일은 바이트 단위로 동일하게 유지됩니다.

### 개인 설정은 `.claude/settings.json`에 넣지 마세요

`.claude/settings.json`은 커밋되며 게이트가 걸려 있습니다: `extraKnownMarketplaces`와 `enabledPlugins` 정확히 두 개 외의 키가 들어오면 `tests/run-checks.sh`가 FAIL합니다. `model`, `env`, `permissions`, `apiKeyHelper` 등 개인 설정은 gitignore되는 **`.claude/settings.local.json`**에 두세요.

### ⚠️ `claude plugin marketplace remove so-adk`를 실행하지 마세요

**커밋된 파일이 비워집니다.** 이 명령을 실행하면 저장소가 추적하는 `.claude/settings.json`의 `extraKnownMarketplaces`와 `enabledPlugins`가 **둘 다** `{}`로 초기화됩니다. 의도치 않은 `git diff`가 생기고 `tests/run-checks.sh`가 실패하기 시작합니다.

복구:

```bash
git checkout -- .claude/settings.json
```

관련 함정: 같은 마켓플레이스 이름으로 로컬 디렉터리 소스를 등록하면(예: `claude plugin marketplace add /path/to/so-adk`) **user 설정**에 기록되며 저장소에 커밋된 github 소스보다 **우선합니다**. `claude plugin marketplace list`에 `Directory`로 표시됩니다. 커밋된 project 파일 자체는 변경되지 않지만, 저장소가 선언한 것과 다른 것을 실행하게 됩니다.

### 테스트

```bash
bash tests/run-checks.sh
```

플러그인 레이아웃에 대한 정적 계약 검사입니다: 매니페스트, 훅 등록, frontmatter, 스킬 네임스페이스, 오케스트레이터↔에이전트 참조 일치성(양방향), 커밋된 `settings.json`의 키 경계와 마켓플레이스 source 스키마, 마이그레이션 래퍼의 동작. `claude` CLI가 `PATH`에 있으면 `claude plugin validate` 검사가 포함되고, 없으면 SKIP됩니다.

### 릴리스

**두 곳 모두** 버전을 올린 뒤 태그를 만듭니다:

```bash
# 1. plugins/<name>/.claude-plugin/plugin.json 과
#    .claude-plugin/marketplace.json 의 해당 엔트리 버전을 함께 올린다
# 2. 태그 — 두 버전의 일치를 검증하고 {name}--v{version} 태그를 생성한다
claude plugin tag ./plugins/so-adk-core
claude plugin tag ./plugins/so-adk-orchestrator
# 3. push
git push --follow-tags
```

`claude plugin tag`는 `plugin.json`과 마켓플레이스 엔트리가 어긋나지 않았음을 기계적으로 확인하는 수단입니다. 실제 git 태그를 생성하므로 릴리스 시점 작업이며, `tests/run-checks.sh`에는 의도적으로 **포함하지 않습니다**.

### 플러그인 전환 롤백

마이그레이션 직전 커밋에 **`pre-plugin`** 태그가 붙어 있습니다.

```bash
git tag --list pre-plugin              # 앵커 존재 확인
git diff pre-plugin..HEAD --stat       # 마이그레이션이 변경한 전체 확인
```

- **권장 (이력 보존):** `git revert -m 1 <merge-commit>`
- **비상시:** `git checkout pre-plugin -- .` 로 작업 트리를 전환 이전 레이아웃으로 되돌립니다 — 레거시 `.claude/agents`, `.claude/skills`, `.claude/hooks`, `.claude/so-orchestrator.md`가 그대로 복원됩니다.

마이그레이션 래퍼를 실행한 사용자 측 롤백은 [curl 설치 방식에서 마이그레이션](#curl-설치-방식에서-마이그레이션)을 참조하세요.

---

## 핵심 기능

- **PostToolUse 훅** — 편집 직후 자동으로 lint/typecheck 실행하고 실패를 에이전트에 피드백 (exit 2)
- **SessionStart 훅** — 세션 시작 시 진행 중 SPEC을 결정론적으로 주입 → 모델 기억에 의존하지 않는 재개
- **역피라미드 테스트** — 인수 → E2E → 단위 테스트 (역방향 접근법)
- **UI 설계 스펙** — SPEC에 프론트엔드가 있으면 Designer가 UI 계약 작성 (선택적)
- **병렬 검토 모드** — 복잡한 SPEC은 Reviewer + Architect 동시 실행으로 빠른 피드백
- **연속 Drift 감지** — Auditor가 데드코드, 레거시 의존성, 놓친 아카이브 스캔 (선택적)
- **비침습 설치** — 오케스트레이터는 `CLAUDE.md`에 주입되는 import가 아니라 플러그인 에이전트입니다

## 철학

> 엔지니어의 역할은 코드 작성에서 하네스 설계로 전환됩니다: SPEC, 품질 게이트, 피드백 루프.

- **자율 라우팅** — 슬래시 명령어 없이 자연어만으로 에이전트 자동 호출
- **SPEC 우선** — 명확한 스펙 없이는 구현하지 않음, 항상 `specs/`에 저장
- **기본 TDD** — 항상 구현 전 테스트 작성
- **사람 체크포인트** — Reviewer 완료 후 파이프라인 일시 정지, 승인 후 진행
- **Greenfield/Brownfield 인식** — 신규 기능은 전체 파이프라인, 기존 코드 변경은 직접 라우팅
- **보안 게이트** — 모든 PR은 자동으로 Preflight + Security를 병렬 검토 후 생성
- **피드백 루프** — PostToolUse 훅으로 즉시 피드백, Auditor로 지속 drift 감지

---

## 라이선스

MIT
