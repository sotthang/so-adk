# SPEC-001: SO-ADK Claude Code 플러그인 전환

**Status**: Approved
**Created**: 2026-08-21
**Reviewed**: 2026-08-21 (v3 3차 검토 — **Approved**. 리뷰 전문: [`SPEC-001-plugin-migration.review-v3.md`](SPEC-001-plugin-migration.review-v3.md))
**Revised**: 2026-08-21 (v3.1 — 승인 조건이던 M-1·M-2 문언 수정 반영 + I-1 `--plugin-dir` 역할축 재프레이밍. 재검토 불요 판정에 따라 오케스트레이터가 직접 반영)
**Revised**: 2026-08-21 (v3 — Reviewer 재검토 C-1~C-10 대응 + V0 추가 실측 F11~F14 반영, R11 재설계)

## Goal

curl 기반 파일 나열 설치 방식(누락 버그 재발 가능, CLAUDE.md 침습 수정, 업데이트 메커니즘 부재)을 Claude Code 네이티브 플러그인 + 마켓플레이스 배포로 교체하여, **같은 자산을 동작 변경 없이** 구조적으로 안전하게 포장·배포한다.

## Background

### 전환 동기

- `install.sh`의 `AGENTS=(...)` 수동 나열 때문에 `so-scaffold` 누락 버그가 실제 발생했음(커밋 7819bda로 수정). 디렉터리 통째 배포인 플러그인 방식은 이 버그 클래스를 원천 차단한다.
- `install.sh`가 사용자 프로젝트의 `CLAUDE.md`에 `@.claude/so-orchestrator.md`를 append하는 침습적 방식 → 플러그인 `settings.json`의 `"agent"` 키(메인 스레드 에이전트 교체)로 대체.
- 핵심 설계 판단(사용자 합의됨): 플러그인을 **두 개로 분리**한다.
  - **`so-adk-core`** — 에이전트 15개 + 스킬 8개 + 훅 2개.
  - **`so-adk-orchestrator`** — 메인 스레드 에이전트 교체(자연어 인텐트 라우팅). **Project/Local 스코프 전용**으로 안내.
- **스코프 안내 정정 (Reviewer MAJOR 5)**: v1의 "core는 메인 에이전트를 교체하지 않으므로 User 스코프도 안전"이라는 서술은 **사실이 아니다**. core의 훅은 User 스코프 설치 시 **모든 프로젝트에서 전역 발동**한다 — `PostToolUse`가 매 Edit마다 lint/typecheck를 돌리고 실패 시 exit 2로 차단하며, `SessionStart`가 모든 프로젝트에서 specs를 스캔한다. 본 SPEC은 선택지 (b)를 채택한다: **core에도 User 스코프 경고를 확장**하고, 두 플러그인 모두 Project/Local 스코프 설치를 기본 권장한다(R2, R8).
- 설계 결정: 사용자 호출 스킬(dev/plan/pr/refactor)은 `so-adk-core`에 포함되므로 네임스페이스는 `/so-adk-core:dev` 형태가 된다. 이는 사용자 관점 **breaking change**다(→ 인지된 허용 동작 변경 참조).

### V0 스파이크로 확정된 사실 (2026-08-21 실기기 실측 — 추측 아님)

scratchpad에 스켈레톤 플러그인 2개 + 로컬 마켓플레이스를 구성해 실제 Claude Code로 검증했다. 아래는 모두 **실측으로 확정된 사실**이다. F1~F10은 v2 시점 측정, F11~F14는 v3 시점 추가 측정(Reviewer 재검토 C-1·C-2 확정용)이다.

| # | 확정 사실 | 실측 근거 | SPEC 반영 |
| - | --------- | --------- | --------- |
| F1 | 플러그인 루트 `settings.json`의 `"agent": "<name>"` 키는 메인 스레드 에이전트를 실제로 교체한다 | 교체 에이전트의 매직 토큰이 응답 첫 줄에 출력됨 | R3 |
| F2 | 에이전트 교체 후에도 사용자 전역/프로젝트 CLAUDE.md 지침이 그대로 적용된다 | 교체된 에이전트가 전역 CLAUDE.md의 "git add, commit, push 승인" 지침과 Kent Beck TDD 섹션을 원문 인용함 — **Reviewer BLOCKER 1(안전장치 소실 우려) 해소** | R3 (회귀 방지 스모크 AC 유지) |
| F3 | 스코프 키 확정: `--scope project` → `.claude/settings.json`의 `enabledPlugins`, `--scope local` → `.claude/settings.local.json`의 `enabledPlugins`, 값은 `"<plugin>@<marketplace>": true` | 설치 후 파일 직접 확인 | R4, R9, R11 |
| F4 | 에이전트 frontmatter의 `skills:` 필드는 플러그인 내부 스킬을 **플레인 이름으로 정상 해석**한다 | 스켈레톤 플러그인에서 프리로드 확인 | R2 — 에이전트 15개는 본문 완전 무수정 |
| F5 | `${CLAUDE_PLUGIN_ROOT}`는 hooks.json에서 플러그인 루트 절대경로로 정확히 치환된다 | 훅 실행 로그 확인 | R2 |
| F6 | 플러그인 2개 + 루트 marketplace.json 모노레포 레이아웃은 `claude plugin validate` 통과. author/description 누락은 warning(`--strict`로 에러 승격 가능) | validate 직접 실행 | R2, R4, R7 |
| F7 | `claude plugin marketplace add`는 **user settings**에 마켓플레이스를 기록한다. 팀/기여자에게 마켓플레이스를 자동 **등록**시키려면 repo의 `.claude/settings.json`에 `extraKnownMarketplaces`를 직접 커밋해야 한다. **단, 등록 ≠ 설치 — F12에서 범위 정정됨** | 설치 후 settings 확인 | R4, R9 |
| F8 | 신규 CLI 확인: `claude plugin tag [path]` — `{name}--v{version}` git 태그 생성 + plugin.json↔marketplace 엔트리 버전 **일치 검증**. `claude plugin eval [target]` — 플러그인 eval 케이스 러너 | 직접 실행 | R12 (tag), R7 (eval 검토) |
| F9 | project 스코프로 설치된 플러그인은 일반 uninstall이 거부되고 "팀과 공유됨" 안내와 함께 `--scope local`로 disable하라는 메시지가 출력된다 | 직접 실행 | R6 (마이그레이션 문서 설계 참고) |
| F10 | 오케스트레이터 frontmatter에 `model` 필드를 넣지 않으면 세션의 `--model` 지정이 그대로 존중된다 | `--model` 지정 세션에서 확인 | R3 — `model` 필드 **생략 확정** |
| F11 | **교차 플러그인 에이전트 디스패치는 플레인 이름으로 동작한다.** 플러그인 A(orchestrator)의 메인 스레드 에이전트가 플러그인 B(core)에 정의된 서브에이전트를 플레인 이름으로 Agent 툴 호출하는 데 성공 | 응답에 오케스트레이터 토큰과 워커 토큰이 모두 출력됨 | **C-1 해소** — 최상위 불변식(에이전트 15개·오케스트레이터 본문 무수정) **유지**. 네임스페이스 폴백 조항 불필요. 회귀 방지로 AC-R3e에 실제 교차 플러그인 디스패치 1회 포함 |
| F12 | **커밋된 project `.claude/settings.json`만으로는 플러그인이 활성화되지 않는다.** `extraKnownMarketplaces`(정규 형태) + `enabledPlugins`를 커밋한 상태로 새 세션을 열어도 플러그인 미로드(상대경로·절대경로 양쪽 모두 음성). 명시적 `claude plugin install <name>@<mkt> --scope project` 실행 후에야 활성화(대조군 양성) | 신규 세션 로드 여부 직접 확인 + 대조군 실험 | **C-2 확정 — v2 R11의 "settings.json 커밋으로 dogfooding 즉시 복구" 메커니즘은 작동하지 않음 → R11 재설계.** `extraKnownMarketplaces` 커밋은 마켓플레이스 **자동 등록**까지만 유효하고 **설치는 하지 않는다** — R4 문언에서 구분 기술 |
| F13 | **잘못된 `extraKnownMarketplaces` source 형태는 에러 없이 플러그인을 조용히 `disabled`로 만든다.** `{"source":{"source":"local","path":"."}}`처럼 쓰면 `claude plugin list`에서 `✘ disabled`, 에러 메시지 없음. 정규 형태로 고치자 즉시 `✔ enabled` | `claude plugin list` 상태 직접 확인 | R4 — 커밋된 settings.json의 source 스키마를 `tests/run-checks.sh`에서 형태 검증 (AC-R4d) |
| F14 | **`extraKnownMarketplaces`의 정규 source 형태**: 로컬 디렉터리 `{"source":{"source":"directory","path":"<경로>"}}`, GitHub `{"source":{"source":"github","repo":"owner/repo"}}`. CLI(`claude plugin marketplace add`)가 디렉터리 소스를 기록할 때는 **절대경로**를 쓴다 — 커밋 값으로 부적합 | settings 기록값 직접 확인 | R4 — 배포용 커밋 값은 **github 형태**(`{"source":{"source":"github","repo":"sotthang/so-adk"}}`) 확정 |

## Requirements

#### R1 — 저장소 재구성: 자산의 플러그인 디렉터리 이동

- 저장소를 다음 구조로 재구성한다:

  ```text
  so-adk/
  ├── .claude-plugin/
  │   └── marketplace.json                  # R4
  ├── .claude/
  │   └── settings.json                     # R4/R9 (extraKnownMarketplaces + enabledPlugins — 신규 커밋)
  ├── plugins/
  │   ├── so-adk-core/
  │   │   ├── .claude-plugin/plugin.json    # R2
  │   │   ├── agents/                       # 기존 .claude/agents/ 15개 파일 (git mv)
  │   │   ├── skills/                       # 기존 .claude/skills/ 8개 디렉터리 (git mv)
  │   │   └── hooks/
  │   │       ├── hooks.json                # R2 (신규)
  │   │       ├── post-edit-check.sh        # git mv
  │   │       └── session-start-resume.sh   # git mv
  │   └── so-adk-orchestrator/
  │       ├── .claude-plugin/plugin.json    # R3
  │       ├── agents/so-orchestrator.md     # 기존 .claude/so-orchestrator.md (git mv + frontmatter만 추가)
  │       └── settings.json                 # R3 ("agent" 키)
  ├── install.sh / install.ps1              # R6 (마이그레이션 래퍼로 축소)
  ├── tests/run-checks.sh                   # R7 (전수 매핑표 기반 갱신)
  └── README.md / README.ko.md              # R8
  ```

- 모든 이동은 파일 나열이 아니라 **디렉터리 단위 `git mv`** 로 수행한다(`git mv .claude/agents plugins/so-adk-core/agents` 형태 — 나열 누락 버그 클래스를 이동 작업 자체에서도 배제).
- R5·R10에서 명시한 텍스트 치환과 오케스트레이터 frontmatter 추가를 제외하고 **파일 본문을 변경하지 않는다**. F4·F11에 따라 에이전트 15개 파일은 **원칙적으로 본문 무수정**이다. 단 **예외 1건**(**M-2**): `.claude/agents/so-quality.md:3`의 `Also invoked by /refactor command.`는 구 스킬 호출명이므로 **R5의 치환 대상이며 커밋 3에서 갱신된다.** F4·F11이 확정한 것은 `skills:` 필드와 에이전트 *이름*의 무수정 가능성이지 슬래시 명령 문자열이 아니다 — v3까지의 '완전 무수정' 문언은 과잉 일반화였다. 이동 커밋(커밋 1)에서는 이 파일도 100% rename이므로 AC-R1a에는 영향이 없다.
- **커밋 경계 (C-5 정리)**: frontmatter 추가·텍스트 치환은 이동 커밋이 아니라 **별도의 후속 커밋**(Technical Approach 커밋 3) 소관이다. 따라서 **이동 커밋에서는 오케스트레이터를 포함한 전 파일이 유사도 100% rename**이어야 한다.

#### R2 — `so-adk-core` 플러그인 매니페스트 및 구성

- `plugins/so-adk-core/.claude-plugin/plugin.json`을 작성한다: `name: "so-adk-core"`, description, version `1.0.0`, author (F6: `--strict` 통과를 위해 모두 기재).
- `hooks/hooks.json`을 신규 작성한다. 내용은 현행 `install.sh`의 `SETTINGS_TEMPLATE`과 **동일한 이벤트/매처 구성**이어야 한다:
  - `SessionStart` → `${CLAUDE_PLUGIN_ROOT}/hooks/session-start-resume.sh`
  - `PostToolUse` (matcher `Edit|Write|MultiEdit`) → `${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-check.sh`
  - (F5: `${CLAUDE_PLUGIN_ROOT}` 치환은 실측 확인됨)
- 훅 스크립트 2개는 실행 권한(`+x`)을 유지한다.
- 에이전트 frontmatter의 `skills:` 필드는 플레인 이름 그대로 유지한다(F4 확정).
- **스코프 경고 (MAJOR 5 대응, 선택지 b)**: plugin.json description과 R8 문서에 "User 스코프 설치 시 훅이 모든 프로젝트에서 전역 발동(매 Edit lint/typecheck + 실패 시 차단, 매 세션 specs 스캔) — Project/Local 스코프 권장"을 명시한다.

#### R3 — `so-adk-orchestrator` 플러그인 매니페스트 및 구성

- `plugins/so-adk-orchestrator/.claude-plugin/plugin.json`을 작성한다: `name: "so-adk-orchestrator"`, description에 **"so-adk-core 필요, Project/Local 스코프 전용"** 명시(plugin.json에 의존성 필드가 없으므로 문서 + R7 테스트로 강제).
- `agents/so-orchestrator.md`: 기존 `.claude/so-orchestrator.md` 본문을 그대로 유지하고, 최소 frontmatter만 상단에 추가한다:
  - `name: so-orchestrator`, `description`만 기재.
  - **`model` 필드 금지** (F10: 생략 시 세션 `--model` 지정이 존중됨).
  - **`tools` 필드 생략** (전체 툴 상속). 기존 `check_frontmatter`(4필드 요구)는 orchestrator에 적용할 수 없으므로 R7에서 검사 분리.
- `settings.json`에 `"agent": "so-orchestrator"`를 설정하여 플러그인 활성 시 메인 스레드 에이전트를 교체한다(F1 실측 확정). CLAUDE.md는 일절 건드리지 않는다.
- **교차 플러그인 디스패치 확정 (C-1 해소, F11)**: orchestrator(플러그인 A)가 core(플러그인 B)의 서브에이전트를 **플레인 이름으로 Agent 툴 호출 가능**함이 실측 확정되었다. 오케스트레이터 본문의 에이전트 참조는 일절 수정하지 않는다. CLI 업데이트 회귀 방지를 위해 AC-R3e에 **실제 교차 플러그인 디스패치 1회**를 포함한다.
- **CLAUDE.md 공존 확정 및 회귀 방지 (BLOCKER 1 해소)**: F2 실측 확정. CLI 업데이트 회귀 방지를 위해 수동 스모크를 AC로 유지한다(AC-R3e).
- `initialPrompt` 필드는 사용하지 않는다 — session resume은 기존 SessionStart 훅(core 플러그인) 방식을 유지한다(동작 보존).

#### R4 — 마켓플레이스 매니페스트 및 기여자 자동 등록

- repo 루트에 `.claude-plugin/marketplace.json`을 작성한다: 마켓플레이스 `name: "so-adk"`, owner, 두 플러그인 엔트리(`source: "./plugins/so-adk-core"`, `"./plugins/so-adk-orchestrator"`).
- **사용자 설치 경로 (C-3 대응 — 대표 명령에 명시적 스코프)**:

  ```text
  claude plugin marketplace add sotthang/so-adk
  claude plugin install so-adk-core@so-adk --scope project
  claude plugin install so-adk-orchestrator@so-adk --scope project   # 선택
  ```

  개인 실험용은 `--scope local`. **스코프 플래그 없는 설치 명령을 대표 예시로 쓰지 않는다** — CLI 기본값(user 스코프)이 R2/R8이 경고하는 전역 훅 발동 위험의 happy path가 되기 때문이다. User 스코프는 경고문과 함께 명시적 선택지로만 소개한다.
- **기여자 자동 등록 — 역할 경계 정확화 (F7·F12)**: repo의 `.claude/settings.json`에 `extraKnownMarketplaces`(so-adk 마켓플레이스)와 `enabledPlugins`(두 플러그인, F3의 키 형식)를 직접 커밋한다. 이를 위해 `.gitignore`에서 `.claude/settings.json` 등재를 해제한다. 단, 이 커밋의 효력은 다음과 같이 **구분해서 기술**한다(v2는 이를 혼동했다):
  - `extraKnownMarketplaces` 커밋 → 기여자 세션에 마켓플레이스가 **자동 등록**된다 (여전히 가치 있음).
  - 그러나 **설치·활성화까지 되지는 않는다** (F12 실측). 기여자는 `claude plugin install <name>@so-adk --scope project`를 **명시적으로 1회 실행**해야 한다(R9·R11, README 개발 섹션에 명문화).
- **source 형태 확정 (F13·F14)**: 커밋되는 `extraKnownMarketplaces`의 source는 **github 정규 형태** `{"source":{"source":"github","repo":"sotthang/so-adk"}}`를 쓴다. directory 형태는 CLI가 절대경로를 기록하므로 커밋 값으로 부적합(F14). 잘못된 형태는 에러 없이 조용히 `disabled`가 되므로(F13) `tests/run-checks.sh`에 **source 스키마 형태 검증**을 추가한다(AC-R4d).
- **커밋 내용 경계 강제 (Reviewer 신규 위험 대응)**: `.gitignore` 해제로 `.claude/settings.json`이 추적 파일이 되면 장래에 `permissions`·`env`·`model`·`apiKeyHelper` 등 개인/위험 설정이 게이트 없이 유입될 수 있다. 방어:
  - 커밋된 settings.json의 최상위 키는 **정확히 `extraKnownMarketplaces`, `enabledPlugins` 두 개뿐**이어야 한다 — `tests/run-checks.sh`에서 `jq -r 'keys[]'`로 검증(AC-R4c).
  - `.gitignore` 2행의 `.claude/settings.local.json` 등재는 유지한다(개인 설정 배출구 보존).
  - README에 "개인 설정은 `.claude/settings.local.json`에 둘 것" 한 줄을 기재한다(R8).

#### R5 — 스킬 네임스페이스 변경 대응

- 플러그인 스킬은 `/so-adk-core:dev`, `/so-adk-core:plan`, `/so-adk-core:pr`, `/so-adk-core:refactor`로 네임스페이스된다.
- `plugins/` 하위의 모든 구(舊) 호출명 참조를 갱신한다. 대상은 **슬래시 접두형**(`/pr` 등)과 **무슬래시 스킬 언급형** 둘 다이다 (C-4): 오케스트레이터 본문에는 `` `pr` skill ``(백틱형)과 `pr skill`(무백틱형)이 실물 기준 4곳 존재한다(`.claude/so-orchestrator.md` 88·228행 백틱형, 234·277행 무백틱형). 모두 네임스페이스 서술로 치환한다.
- **`dev` 스킬의 CLAUDE.md 참조 수정**: `skills/dev/SKILL.md`의 "pipeline defined in CLAUDE.md" 문구는 전환 후 사실이 아니게 되므로, 오케스트레이터 플러그인 기준 서술로 치환한다(허용 텍스트 치환에 포함).
- README/README.ko의 슬래시 명령어 표를 신 이름으로 갱신하고, 구→신 대응표를 마이그레이션 노트로 제공한다(R8).
- 이 rename은 **사용자 관점 breaking change**다(인지된 허용 동작 변경 목록 참조).
- **참조 검색 범위 (MAJOR 6 대응)**: 구 호출명 0건 요구는 `plugins/` 하위로 한정한다. README의 마이그레이션 대응표와 `specs/` 디렉터리는 검색 대상에서 제외한다.

#### R6 — `install.sh` / `install.ps1`의 마이그레이션 래퍼 전환 (BLOCKER 3 대응)

`curl | bash` 실행은 TTY가 없어 확인 프롬프트가 불가능하므로, 파괴적 동작을 다음과 같이 비파괴·옵트인 구조로 설계한다:

- **명시적 옵트인**: 플래그 없이 실행하면 **어떤 파일도 변경하지 않고** 현재 상태 진단(레거시 감지 여부)과 안내만 출력한다. 실제 정리는 `--migrate` 플래그를 명시했을 때만 수행한다.
- **`--dry-run` 플래그**: 수행할 작업 목록(백업·제거 대상 전체 경로)을 출력만 하고 파일을 변경하지 않는다.
- **삭제가 아닌 백업 이동**: `--migrate` 시 SO-ADK 소유 파일을 삭제하지 않고 `.claude/.so-adk-backup-<timestamp>/`로 **이동**한다. 사용자가 수정한 SO-ADK 에이전트도 이 백업에 그대로 보존된다.
- **고정 목록 기반**: 이동 대상은 글롭이 아니라 **고정 목록**으로 확정한다 — `.claude/agents/`의 SO-ADK 에이전트 15개, `.claude/skills/`의 SO-ADK 스킬 디렉터리 8개, `.claude/hooks/`의 훅 2개, `.claude/so-orchestrator.md`. (이 목록은 더 이상 자라지 않는 동결된 레거시 집합이므로 나열 누락 버그 클래스에 해당하지 않는다 — 주석으로 명시)
- **마커 grep 가드 — 스킬·에이전트 대칭 적용 (Reviewer 구현 주의 2)**: 스킬 디렉터리(dev/plan/pr/refactor)는 현행 `install.sh:99-102`의 선례를 따라 SO-ADK 마커를 grep으로 확인한 파일만 백업 대상으로 삼는다. **에이전트 15개 고정 목록에도 동일한 마커 grep 가드를 적용한다**(예: `so-foundation` 스킬 참조 또는 SO-ADK 파이프라인 마커 확인) — 동명의 사용자 파일 오이동 방지를 스킬과 대칭으로 맞춘다.
- **CLAUDE.md 삭제 금지**: `CLAUDE.md`에서 정확히 `@.claude/so-orchestrator.md` 라인만 제거하고 그 외 내용을 보존한다. 제거 결과 파일이 비더라도 **파일을 삭제하지 않는다**(빈 파일 유지).
- **고아 훅 방지 — 순서 강제 (Reviewer 구현 주의 1)**: `.claude/settings.json`에서 SO-ADK가 등록한 SessionStart/PostToolUse 훅 엔트리만 jq로 제거한다(다른 키 보존). **훅 엔트리 제거가 성공했음을 확인한 뒤에만 훅 스크립트를 이동한다** — 이 선행 조건 순서를 요구사항으로 강제한다. 실패 경로는 두 가지 모두 처리한다:
  - jq 부재 (AC-R6g)
  - **사용자 settings.json이 유효 JSON이 아니어서 파싱 실패** — 실제로 더 흔한 케이스 (AC-R6h)
  - 어느 쪽이든 훅 스크립트를 이동하지 않고, 실패 사실과 수동 제거 절차를 출력한 뒤 exit 비0으로 종료한다(엔트리만 남고 스크립트가 사라지면 모든 Edit가 고아 훅으로 실패하기 때문).
- 정리 완료 후 플러그인 설치 명령 안내를 출력한다(스코프 플래그 포함, R4의 대표 명령과 동일). 자동 실행은 하지 않는다.
- 레거시 미감지 시(신규 사용자): 정리 단계를 건너뛰고 설치 안내만 출력한다.
- 마이그레이션 안내 문구에 F9(project 스코프 플러그인은 일반 uninstall 거부, `--scope local` disable 안내)를 반영해 스코프별 제거/비활성 방법을 정확히 기술한다.
- **`specs/archive/` 생성 동작 소멸 (MODERATE 12)**: 현행 install.sh의 `specs/`·`specs/archive/` 디렉터리 생성은 래퍼에서 수행하지 않는다. 이 변화를 R8 마이그레이션 노트에 명시한다.
- `install.ps1`도 동일 동작으로 갱신하되 **best-effort + 수동 검증**으로 한다(Out of Scope 참조). **단, ps1의 `--migrate` 경로 출력에 "이 스크립트는 자동 테스트가 없는 베타입니다 — 실행 전 `--dry-run`으로 대상을 확인하고 수동 검증하세요" 경고를 포함한다** (C-8 — 파괴적 스크립트를 AC 없이 두는 데 대한 최소 방어).
- curl 재실행이 기존 사용자의 유일한 업데이트 경로였으므로, 기존 URL(`.../main/install.sh`)은 그대로 이 마이그레이션 래퍼를 서빙한다.

#### R7 — 검증 체계 편입: 기존 15개 검사 전수 매핑 + 신규 계약 검사 (MAJOR 7 대응)

- **검사 신설의 실제 명분**: 플러그인은 디렉터리 통째 배포이므로 "install.sh 나열 누락" 위협 자체는 소멸한다. 신설 파일-참조 일치성 검사가 실제로 방어하는 것은: (1) 오케스트레이터 본문의 에이전트 이름 오타 및 rename 후 미갱신, (2) **오케스트레이터 플러그인이 core 플러그인의 에이전트를 참조하는데 plugin.json에 의존성 필드가 없어 이 결합이 어디에도 선언되지 않는다는 사실 — 이 검사가 두 플러그인을 잇는 유일한 기계적 계약이다.**
- **파일-참조 일치성 검사 (양방향)**:
  - 순방향: 오케스트레이터 본문이 참조하는 모든 `so-*` 에이전트 이름이 `plugins/so-adk-core/agents/`에 실제 파일로 존재.
  - 역방향: `plugins/so-adk-core/agents/`의 에이전트 중 오케스트레이터 본문에서 참조되지 않는 고아 에이전트 탐지.
- `claude plugin validate ./plugins/so-adk-core`와 `claude plugin validate ./plugins/so-adk-orchestrator` 및 마켓플레이스 루트 validate를 추가한다(`claude` CLI가 PATH에 없으면 SKIP).
- 훅 검사: `hooks.json`이 유효 JSON이고 `${CLAUDE_PLUGIN_ROOT}` 경로를 사용하며, 참조 스크립트 2개가 존재+실행 가능한지 검증.
- `claude plugin eval` 활용 가능성을 검토해 결과를 테스트 주석 또는 README 개발 섹션에 기재한다(도입은 필수 아님).
- **기존 15개 검사 전수 매핑표** (`tests/run-checks.sh` 기준 — 이 표대로 갱신/대체/삭제한다):

  | # | 기존 검사 | 처분 | 내용 |
  | - | -------- | ---- | ---- |
  | 1 | `check_frontmatter` | 갱신+분리 | 대상 경로 → `plugins/so-adk-core/agents/*.md`(4필드 유지). orchestrator는 별도 검사로 분리 — `name`/`description`만 요구, `model`·`tools` **부재**를 요구 (R3) |
  | 2 | `check_new_agents_in_install` | 대체 | install.sh 나열이 사라지므로 삭제 → 파일-참조 일치성 검사(순방향)로 대체 |
  | 3 | `check_new_agents_in_orchestrator` | 갱신 | 경로 → `plugins/so-adk-orchestrator/agents/so-orchestrator.md` ↔ `plugins/so-adk-core/agents/` |
  | 4 | `check_settings_json_valid` | 대체+확장 | **현재도 통과 불가** — `.claude/settings.json`이 `.gitignore` 등재로 저장소에 부재. R4에서 신규 커밋하므로 다음 3종으로 재정의: (a) `extraKnownMarketplaces`/`enabledPlugins` 존재·유효성, (b) **최상위 키가 정확히 그 두 개뿐**(내용 경계, AC-R4c), (c) **source가 github 정규 스키마**(F13 조용한 disable 방지, AC-R4d) |
  | 5 | `check_hook_exists_executable` | 갱신 | 경로 → `plugins/so-adk-core/hooks/*.sh` |
  | 6 | `check_tester_outside_in_mode` | 갱신 | 경로만 변경 |
  | 7 | `check_architect_preview_mode` | 갱신 | 경로만 변경 |
  | 8 | `check_orchestrator_parallel_review` | 갱신 | 경로 → `plugins/so-adk-orchestrator/agents/so-orchestrator.md` |
  | 9 | `check_hook_empty_dir` | 갱신 | 훅 스크립트 경로만 변경 |
  | 10 | `check_hook_npm_lint_ok` | 갱신 | 훅 스크립트 경로만 변경 |
  | 11 | `check_hook_npm_lint_fail` | 갱신 | 훅 스크립트 경로만 변경 |
  | 12 | `check_hook_python_no_tools` | 갱신 | 훅 스크립트 경로만 변경 |
  | 13 | `check_install_dry_run_preserves` | 대체 | 병합 로직 제거 → 래퍼의 `--migrate` 백업·보존 동작 검사로 대체 (AC-R6a/f) |
  | 14 | `check_install_calls_merge_in_normal_path` | 대체 | 병합 로직 제거 → 훅 엔트리 제거 및 고아 훅 방지 동작 검사로 대체 (AC-R6g/h) |
  | 15 | `check_install_dry_run_empty` | 대체 | 래퍼의 무플래그/`--dry-run`/빈 디렉터리 무변경 검사로 대체 (AC-R6c/d/e) |

- **신규 검사**: plugin validate ×3(SKIP 가능), 파일-참조 일치성(순방향/역방향), hooks.json 검증, orchestrator frontmatter 분리 검사, settings.json 내용 경계 검사(AC-R4c), extraKnownMarketplaces source 스키마 검사(AC-R4d).
- **run-checks.sh에 넣지 않는 것 (C-9)**: `claude plugin tag` 실행 검증(AC-R12a)은 실제 git 태그를 생성하는 부작용이 있으므로 자동 테스트에 포함하지 않는다 — 릴리스 시 1회 수행하는 AC로 분리한다.

#### R8 — README / README.ko 갱신

- Installation 섹션을 플러그인 설치 방식으로 교체: 마켓플레이스 추가 → 플러그인 설치, 스코프 3종(User/Project/Local) 설명. **모든 설치 예시 명령에 명시적 스코프 플래그(`--scope project` 또는 `--scope local`)를 붙인다** (C-3).
- **스코프 경고 2종 모두 기재**: (1) orchestrator는 Project/Local 전용, (2) **core도 User 스코프 설치 시 훅이 모든 프로젝트에서 전역 발동** — Project/Local 권장 (MAJOR 5).
- File Structure 섹션을 새 저장소 구조로 교체.
- 슬래시 명령어 표를 네임스페이스 이름으로 갱신 + 구→신 대응표(마이그레이션 노트). 스킬 rename이 breaking change임을 명시.
- 기존 사용자 마이그레이션 섹션 신규 추가: R6 래퍼의 `--dry-run`/`--migrate` 사용법, 백업 위치, 로컬 `.claude/` 정의가 동명 플러그인 에이전트를 override하므로 원본 제거가 필요하다는 이유, `specs/archive/` 자동 생성 소멸 안내.
- **개발(기여자) 섹션 (F12 반영)**: (1) 커밋된 `.claude/settings.json`은 마켓플레이스 **등록**까지만 해주며 **설치는 하지 않는다**는 사실, (2) 기여자 온보딩 절차 — `claude plugin install so-adk-core@so-adk --scope project` (+ orchestrator) **명시적 1회 실행**, (3) 플러그인 자체 개발 중에는 `claude --plugin-dir ./plugins/so-adk-core --plugin-dir ./plugins/so-adk-orchestrator`로 세션 한정 로드(R11), (4) "개인 설정은 `.claude/settings.local.json`에 둘 것" 한 줄(R4).
- **롤백/복구 절차 기재 (BLOCKER 2-d)**: `pre-plugin` 태그로의 복귀 방법과 백업 디렉터리 복원 방법(R11).
- `/plugin` 패널의 Context cost 확인 방법 한 줄 언급.
- 업데이트 방법을 플러그인 업데이트 방식으로 교체.

#### R9 — 저장소 셀프 호스팅(dogfooding) 전환

- 이관 완료 후 저장소에서 레거시 자산을 제거한다: `.claude/agents/`, `.claude/skills/`, `.claude/hooks/`, `.claude/so-orchestrator.md`가 더 이상 존재하지 않아야 한다. **이 제거는 R11의 순서 제약(최종 커밋 + 스모크 trailer 선행)을 따른다.**
- **저장소 자체 `CLAUDE.md`의 처분 확정 (C-7)**: 현재 저장소 `CLAUDE.md`는 `@.claude/so-orchestrator.md` import 한 줄뿐이므로 import 제거 시 빈 파일이 된다. 빈 파일로 두지 않고 **dogfooding 안내문으로 대체**한다 — 내용: 이 저장소는 자체 플러그인을 사용한다는 사실, 기여자 온보딩(명시적 project 스코프 설치 1회), 개발 중 `--plugin-dir` 로드 방법(상세는 README 개발 섹션으로 링크). (사용자 프로젝트의 CLAUDE.md에 대한 R6 "비어도 삭제 금지" 규칙과는 별개의, 저장소 자신에 대한 결정이다.)
- **dogfooding 메커니즘 (F12 재설계 반영)**: 저장소 자체의 개발은 다음 2단으로 전환한다(R11의 (iii) 조합과 동일):
  - **전환 작업 중**: `claude --plugin-dir`로 세션 한정 로드 — 설치 절차 없이 무중단.
  - **전환 완료 후에도 `plugins/`를 편집하는 기여자**: 계속 `--plugin-dir`를 쓴다. 커밋된 마켓플레이스 소스가 **github 형태**이므로 `plugin install`로 설치하면 **GitHub 기본 브랜치의 published 사본**이 로드되어, 기여자의 로컬 `plugins/` 편집이 반영되지 않은 채 동작한다 — **에러 없이** 그렇게 된다. 따라서 `--plugin-dir`는 '전환 중 한시적 수단'(시간축)이 아니라 **'플러그인 개발자용 로드 방식'**(역할축)이다. 사용자용은 `plugin install`, 개발자용은 `--plugin-dir`로 README에서 구분 기술한다.
  - **전환 완료 후**: 기여자 각자가 `claude plugin install <name>@so-adk --scope project`를 1회 실행. 커밋된 `.claude/settings.json`(R4)은 마켓플레이스 자동 등록 + 활성 상태의 저장소 기록 역할이며, **이것만으로 활성화되지 않는다**(F12).
- 방법을 README 개발 섹션에 문서화한다(R8).

#### R10 — 셀프 업데이트 경로 갱신

- 오케스트레이터 본문의 Step 2-B(self-update)를 "curl install.sh 재실행"에서 플러그인 업데이트 안내(`/plugin` 마켓플레이스 업데이트)로 교체한다. 이는 배포 메커니즘 서술의 치환이며 라우팅 로직 변경이 아니다.

#### R11 — 롤백 경로 및 무중단 전환 (BLOCKER 2 대응 — F12에 따라 v3에서 재설계)

**재설계 사유**: v2의 공백기 봉쇄 메커니즘("`git mv` 직후 `.claude/settings.json` 커밋으로 dogfooding 즉시 복구")은 **F12 실측으로 부정되었다** — 커밋된 project settings.json만으로는 플러그인이 활성화되지 않는다. v3는 **(iii) 조합 방식**을 채택한다: 전환 중에는 `--plugin-dir` 세션 로드로 무중단, 전환 완료 후 기여자 온보딩은 명시적 설치 1회.

- **(a) 복귀 지점 명문화**: 이관 착수 직전 커밋에 `pre-plugin` git 태그를 생성한다. 태그는 push한다.
- **(b) feature 브랜치 작업**: 모든 이관 작업은 feature 브랜치에서 수행하고, main은 병합 시점까지 레거시 구성을 유지한다. 기존 curl URL 사용자에게 중간 상태가 서빙되지 않는다. 대응 AC를 둔다(AC-R11c — C-10).
- **(c) 공백기 봉쇄 — `--plugin-dir` 세션 로드 (F12 대안 i)**: `git mv` 커밋 이후 브랜치 작업 기간 동안, 이 저장소에서의 SO-ADK 동작은 다음 명령으로 확보한다:

  ```bash
  claude --plugin-dir ./plugins/so-adk-core --plugin-dir ./plugins/so-adk-orchestrator
  ```

  세션 한정 로드이므로 설치 절차·settings 상태와 무관하게 동작하며, 커밋 그래프에 "동작 불능 구간"이 생겨도 개발이 중단되지 않는다. 이 명령을 README 개발 섹션에 기재한다(R8).
- **(d) 전환 완료 후 온보딩 — 명시적 설치 1회 (F12 대안 ii)**: 병합 후 기여자는 `claude plugin install so-adk-core@so-adk --scope project`(+ orchestrator)를 1회 실행한다. 이 절차를 README 개발 섹션과 본 커밋 계획에 명문화한다. 커밋된 `.claude/settings.json`은 등록·기록용이며 설치를 대신하지 않는다(R4·R9).
- **(e) 레거시 제거는 최종 커밋 + 스모크 trailer 선행 (기계 검증 가능화)**: R9의 레거시 제거는 브랜치의 **마지막 커밋**으로 수행한다. 선행 조건인 "플러그인 로컬 로드 스모크 통과"(AC-R2c·AC-R3e)는 v2의 "PR 본문 서술 순서"로는 선후를 증명할 수 없으므로, **최종 커밋의 직전 커밋 메시지에 trailer `Smoke-Verified: AC-R2c,AC-R3e`를 남기고 `git log --grep`으로 검증**하는 방식으로 변경한다(AC-R11b). 스모크 상세 결과는 PR 본문에도 기록한다(정보 제공용 — 증명 수단은 trailer).
- **(f) 복구 절차 문서화**: README에 `pre-plugin` 태그 기반 복구 절차를 기재한다(R8).

#### R12 — 릴리스·버전 관리 절차 (Reviewer MODERATE 10 대응)

- 릴리스는 `claude plugin tag` 기반으로 표준화한다(F8): 버전 범프 시 plugin.json과 marketplace 엔트리의 버전을 함께 올리고, `claude plugin tag`로 `{name}--v{version}` git 태그를 생성한다 — 이 명령이 두 버전의 **일치를 기계 검증**한다.
- 절차(버전 범프 → tag → push)를 README 개발 섹션에 문서화한다.
- **AC-R12a는 릴리스 시 1회 수행하는 AC다** — 실제 git 태그를 생성하므로 `tests/run-checks.sh`에 포함하지 않는다(C-9, R7).
- 초기 릴리스: 두 플러그인 모두 `1.0.0`.

## Out of Scope

- **동작 변경 일절 금지 (Tidy First — 구조 변경 전용)**: 에이전트 프롬프트 본문, 파이프라인 로직, 인텐트 라우팅 규칙, 훅 스크립트 내부 로직, 스킬 본문의 의미 변경은 하지 않는다. 허용되는 텍스트 수정은 R3(frontmatter 추가), R5(스킬 호출명 + dev SKILL.md의 CLAUDE.md 참조 문구), R9(저장소 자체 CLAUDE.md의 dogfooding 안내문 대체), R10(self-update 서술)로 한정된다.
- `initialPrompt` 기반 session resume 전환 (현행 SessionStart 훅 유지)
- Workflow 스크립트화, 에이전트 `memory:` 필드 도입, so-analyze 추적성 게이트, AskUserQuestion 체크포인트 개선
- 신규 에이전트/스킬 추가, 기존 에이전트의 model/effort/maxTurns 조정
- `.mcp.json`, `bin/`, `monitors/` 등 이번에 사용하지 않는 플러그인 구성요소
- 플러그인 스토어/외부 마켓플레이스 등록
- `install.ps1` 자동 테스트 — **best-effort로 갱신하고 수동 검증**한다(MODERATE 11). bash 래퍼와 동일 동작을 목표로 하되 AC는 두지 않는다. 단, `--migrate` 출력의 베타 경고문은 R6 요구사항이다(C-8).
- core 훅의 User 스코프 전역 발동을 기술적으로 차단하는 것(문서 경고로만 대응 — MAJOR 5 선택지 b)

### 인지된 허용 동작 변경 (breaking changes — 정직 표기)

1. **스킬 호출명 rename**: `/dev` → `/so-adk-core:dev` 등 4종. 사용자 관점 breaking change다. README 대응표로 완화(R5, R8).
2. **core를 User 스코프로 설치하면 훅이 전역 발동**: 문서 경고로 안내하며 기술적으로 막지 않는다(R2, R8).
3. **`specs/`·`specs/archive/` 자동 생성 소멸**: install.sh가 만들어주던 디렉터리를 래퍼는 만들지 않는다(R6).
4. **레거시 curl 설치 경로 폐지**: 기존 URL은 마이그레이션 래퍼를 서빙한다(R6).
5. **이 저장소 자체의 훅 활성화**: 현재 이 저장소에는 `.claude/settings.json`이 없어 **훅이 비활성**이다. 전환 후 기여자가 project 스코프 설치를 실행하면(R9·R11-d) 저장소 개발 중에도 PostToolUse 훅(매 Edit lint/typecheck + 실패 시 차단)과 SessionStart 훅이 새로 발동한다.

## Technical Approach

- **브랜치·커밋 전략 (Tidy First + R11)**: feature 브랜치에서 수행, 착수 전 `pre-plugin` 태그. 브랜치 작업 기간의 SO-ADK 동작은 `claude --plugin-dir` 세션 로드로 확보한다(R11-c — v2의 "settings.json 커밋 즉시 복구"는 F12로 폐기).
  1. 디렉터리 단위 `git mv` **순수 이동 커밋** — 오케스트레이터 포함 전 파일 100% rename, 그 외 변경 없음 (C-5)
  2. 신규 파일 추가 커밋: plugin.json ×2, hooks.json, marketplace.json, orchestrator settings.json, `.claude/settings.json`(github 형태 마켓플레이스 등록 + enabledPlugins — 등록·기록용, F12) + `.gitignore` 해제
  3. 텍스트 치환 커밋: orchestrator frontmatter 추가, 스킬 네임스페이스(슬래시형 + 무슬래시 `pr` skill 4곳), dev SKILL.md 문구, self-update 서술
  4. install.sh/ps1 래퍼 교체 + tests/run-checks.sh 전수 매핑표 반영 커밋
  5. README/README.ko 커밋
  6. 스모크 수행(AC-R2c, AC-R3e — `--plugin-dir` 로드) 후, 그 결과를 담은 커밋에 **trailer `Smoke-Verified: AC-R2c,AC-R3e`**(이 trailer가 기계 검증하는 것은 스모크 *선언*의 **선후 관계**이며, 통과 사실 자체는 **자기 신고**다) 기재 (필요 시 `--allow-empty`) + 상세를 PR 본문에 기록
  7. **최종 커밋**: 레거시 `.claude/` 자산 제거 + 저장소 CLAUDE.md를 dogfooding 안내문으로 대체(R9)
  - 각 단계에서 `tests/run-checks.sh` 실행.
- **리뷰 산출물 보존 관행 (C-6)**: 이번 개정에서 v1 리뷰 원문이 저장되지 않아 v1 지적 #9의 처분을 대조할 수 없었다. 재발 방지로, 이후 so-reviewer의 리뷰 결과는 `specs/SPEC-{NNN}-{slug}.review.md`(재검토는 `.review-v{N}.md`)로 SPEC 옆에 저장한다. 본 SPEC의 v3 리뷰부터 적용한다.
- **생성 파일**: `.claude-plugin/marketplace.json`, `.claude/settings.json`(gitignore 해제 후 커밋 — 키 2개 한정), `plugins/so-adk-core/.claude-plugin/plugin.json`, `plugins/so-adk-core/hooks/hooks.json`, `plugins/so-adk-orchestrator/.claude-plugin/plugin.json`, `plugins/so-adk-orchestrator/settings.json`
- **이동 파일 (디렉터리 단위 git mv)**: `.claude/agents/` → `plugins/so-adk-core/agents/`, `.claude/skills/` → `plugins/so-adk-core/skills/`, `.claude/hooks/` → `plugins/so-adk-core/hooks/`, `.claude/so-orchestrator.md` → `plugins/so-adk-orchestrator/agents/so-orchestrator.md`
- **수정 파일**: `install.sh`, `install.ps1`, `tests/run-checks.sh`, `README.md`, `README.ko.md`, `CLAUDE.md`(저장소 자체 — dogfooding 안내문으로 대체), `.gitignore`(3행 `.claude/settings.json` 등재 해제 — 2행 `settings.local.json`은 유지)
- **검증 도구**: `claude plugin validate`(+`--strict` 검토), `claude plugin tag`(릴리스 시 1회 — run-checks 제외), `claude --plugin-dir`(로컬 스모크 + 전환 중 dogfooding), `jq`, 기존 bash 스모크 테스트 프레임 재사용, `claude plugin eval` 활용 가능성 검토(R7)
- **확정 사실**: Background의 V0 스파이크 실측표(F1~F14) 참조. C-1(교차 플러그인 디스패치)은 F11로 유리하게 확정, C-2(project settings 활성화)는 F12로 불리하게 확정되어 R11을 재설계했다.
- **잔여 리스크**:
  - 플러그인 간 의존성 필드 부재 — orchestrator 단독 설치 시 core 에이전트 부재로 라우팅 실패. 방어: 문서 경고(R3, R8) + **R7 파일-참조 일치성 검사가 두 플러그인을 잇는 유일한 기계적 계약**.
  - CLI 업데이트에 따른 `"agent"` 키/CLAUDE.md 공존/교차 플러그인 디스패치(F11) 동작의 회귀 가능성 — AC-R3e 수동 스모크를 릴리스 전 반복 수행으로 방어.
  - F13류 "조용한 실패"의 다른 변종(스키마 오류가 에러 없이 무시되는 CLI 동작) — AC-R4d 스키마 검사 + AC-R3e 실동작 스모크의 이중 방어.

## Acceptance Criteria

- [ ] **AC-R1a**: Given 이관 브랜치, When `git diff --find-renames`로 **이동 커밋**(커밋 1)을 확인하면, Then 에이전트 15개·스킬 8개·훅 2개·오케스트레이터 1개가 모두 rename으로 나타나고, **오케스트레이터를 포함한 전 파일이 유사도 100%**(본문 무수정)이며, 이동 커밋에는 rename 외의 추가/삭제/수정이 없다. (frontmatter 추가는 커밋 3의 diff에서만 나타난다 — C-5)
- [ ] **AC-R1b**: Given 이관 완료 저장소, When `ls plugins/so-adk-core/agents/*.md | wc -l`을 실행하면, Then 정확히 15가 출력되고 `plugins/so-adk-core/skills/*/SKILL.md`는 정확히 8개다.
- [ ] **AC-R2a**: Given `plugins/so-adk-core`, When `claude plugin validate ./plugins/so-adk-core`를 실행하면, Then exit 0이다.
- [ ] **AC-R2b**: Given `hooks.json`, When `jq`로 파싱하면, Then 유효 JSON이며 SessionStart·PostToolUse(matcher `Edit|Write|MultiEdit`) 두 이벤트가 존재하고 모든 command 경로가 `${CLAUDE_PLUGIN_ROOT}`로 시작하며, 참조된 스크립트 2개가 존재하고 실행 가능하다.
- [ ] **AC-R2c** (수동 스모크): Given `claude --plugin-dir ./plugins/so-adk-core`로 연 세션, When so-planner 에이전트를 호출하면, Then so-foundation·so-spec-format 스킬이 플레인 이름으로 정상 프리로드된다(1회 수행 + Smoke-Verified trailer·PR 본문 기록 — R11-e).
- [ ] **AC-R2d**: Given `plugins/so-adk-core/agents/*.md`, When frontmatter의 `skills:` 값을 grep하면, Then 네임스페이스 접두(`so-adk-core:`) 없이 플레인 이름만 존재한다.
- [ ] **AC-R3a**: Given `plugins/so-adk-orchestrator`, When `claude plugin validate`를 실행하면, Then exit 0이다.
- [ ] **AC-R3b**: Given orchestrator의 `settings.json`, When `jq -r '.agent'`를 실행하면, Then `so-orchestrator`가 출력된다.
- [ ] **AC-R3c**: Given `agents/so-orchestrator.md`, When frontmatter를 제외한 본문을 기존 `.claude/so-orchestrator.md`와 diff하면, Then 차이는 R5·R10 치환분뿐이다.
- [ ] **AC-R3d**: Given `agents/so-orchestrator.md`의 frontmatter, When 키 목록을 검사하면, Then `name`·`description`은 존재하고 `model`·`tools` 키는 존재하지 않는다.
- [ ] **AC-R3e** (수동 스모크, 릴리스 전 필수): Given 두 플러그인을 활성화한 스크래치 프로젝트(전역 CLAUDE.md 지침이 있는 환경), When 새 세션을 열면, Then 다음 3종을 모두 확인한다: (1) "도움말" 입력 시 메인 스레드가 so-orchestrator로 교체되어 Help Guide가 출력됨(라우팅 스모크), (2) 전역 CLAUDE.md의 지침을 인지하고 있음을 질의로 확인(CLAUDE.md 공존 — F2 재검증), (3) **라우팅 발화(예: "로그인 기능 계획 세워줘")로 orchestrator가 core 플러그인의 `so-planner`를 실제 Agent 툴 호출하여 교차 플러그인 디스패치가 동작함을 확인(F11 재검증 — C-1 회귀 방지)**. 결과를 Smoke-Verified trailer(R11-e)와 PR 본문에 기록한다.
- [ ] **AC-R4a**: Given repo 루트, When `jq`로 `.claude-plugin/marketplace.json`을 파싱하면, Then 유효 JSON이며 plugins 배열에 `so-adk-core`·`so-adk-orchestrator` 두 엔트리가 각각 `./plugins/` 하위 source와 함께 존재한다.
- [ ] **AC-R4b**: Given 이관 완료 저장소, When `git ls-files`와 `jq`로 `.claude/settings.json`을 검사하면, Then 파일이 저장소에 커밋되어 있고, `extraKnownMarketplaces`의 so-adk 엔트리 source가 **github 정규 형태**(`.source.source == "github"`, `.source.repo == "sotthang/so-adk"` — F14, 절대경로 directory 형태 금지)이며, `enabledPlugins`에 두 플러그인 키(`<plugin>@<marketplace>` 형식, 값 `true`)가 존재한다.
- [ ] **AC-R4c** (`tests/run-checks.sh` 포함): Given 커밋된 `.claude/settings.json`, When `jq -r 'keys[]'`를 실행하면, Then 출력이 **정확히 `enabledPlugins`·`extraKnownMarketplaces` 두 키뿐**이다(`permissions`·`env`·`model`·`apiKeyHelper` 등 다른 키의 유입을 게이트에서 차단 — 내용 경계).
- [ ] **AC-R4d** (`tests/run-checks.sh` 포함): Given 커밋된 `.claude/settings.json`, When `extraKnownMarketplaces`의 source 스키마를 jq로 검증하면, Then F14 정규 형태(`source.source`가 `github`이고 `source.repo` 존재)에 부합한다 — F13의 "에러 없이 조용히 disabled" 함정을 정적으로 차단.
- [ ] **AC-R5a**: Given `plugins/` 디렉터리, When 다음 2종 패턴으로 스킬 호출명을 검색하면 — (1) 슬래시형 `grep -rE '(^|[^:a-z/])/(dev|plan|pr|refactor)([^a-z:/]|$)'` (**M-1** — 제외 문자군에 `/`를 포함해 `/dev/null`·`2>/dev/null`·`&>/dev/null` 오탐을 배제한다. 이 보정이 없으면 훅 스크립트 7건·에이전트 2건이 영구 오탐되어 본 AC와 AC-R7a가 충족 불가가 된다), (2) **무슬래시 스킬 언급형** `` grep -rE '(^|[^:[:alnum:]_-])`?(dev|plan|pr|refactor)`? skill' `` (C-4 — 백틱형 `` `pr` skill ``과 무백틱형 `pr skill` 모두 포착, 네임스페이스형 `` `so-adk-core:pr` skill ``은 콜론 선행으로 제외됨) — Then 구 호출명 참조가 0건이고 네임스페이스 형태만 존재한다. 검사 자가 검증: 이관 **전** 실물에 패턴 (1)을 적용하면 `.claude/agents/so-quality.md:3` **1건만** 검출되어야 하고(오탐 0건), 패턴 (2)를 적용하면 오케스트레이터 88·228·234·277행 **4건**이 검출되어야 한다. 본 AC는 `tests/run-checks.sh`에 포함되는 **자동 검사**다. (`specs/`와 README의 마이그레이션 대응표는 검색 대상이 아니다 — R5 범위 한정)
- [ ] **AC-R5b**: Given `plugins/so-adk-core/skills/dev/SKILL.md`, When 내용을 검사하면, Then "pipeline defined in CLAUDE.md" 류의 CLAUDE.md 파이프라인 참조가 없고 오케스트레이터 플러그인 기준 서술이 존재한다.
- [ ] **AC-R6a**: Given 레거시 설치를 재현한 임시 디렉터리(`CLAUDE.md`에 import 라인 + 사용자 고유 내용, `.claude/agents/`에 SO-ADK 에이전트 15개 + 사용자 작성 `my-agent.md`, SO-ADK 스킬·훅, 훅이 병합된 `settings.json`), When `install.sh --migrate`를 실행하면, Then SO-ADK 소유 파일이 `.claude/.so-adk-backup-<timestamp>/`로 **이동**(삭제 아님)되고, `my-agent.md`·사용자 CLAUDE.md 내용·settings.json의 타 키는 보존되며, CLAUDE.md는 import 라인만 사라지고 파일 자체는 (비더라도) 삭제되지 않는다.
- [ ] **AC-R6b**: Given 새 `install.sh`, When 내용을 검사하면, Then `curl`로 에이전트/스킬 파일을 다운로드하는 코드와 `CLAUDE.md`에 append하는 코드가 존재하지 않고, 백업 대상이 글롭이 아닌 고정 목록으로 정의되어 있으며, **스킬 디렉터리와 에이전트 파일 양쪽 모두에 마커 grep 가드가 존재한다**(대칭 — R6).
- [ ] **AC-R6c**: Given 레거시 설치가 없는 빈 임시 디렉터리, When `install.sh --migrate`를 실행하면, Then 어떤 파일도 생성·수정하지 않고 플러그인 설치 안내만 출력하며 exit 0이다.
- [ ] **AC-R6d**: Given 레거시 설치를 재현한 임시 디렉터리, When 플래그 없이 `install.sh`를 실행하면, Then 어떤 파일도 변경되지 않고 레거시 감지 결과와 `--migrate` 안내만 출력된다(옵트인 검증).
- [ ] **AC-R6e**: Given 레거시 설치를 재현한 임시 디렉터리, When `install.sh --dry-run`을 실행하면, Then 백업·제거 예정 경로 목록이 출력되고 어떤 파일도 변경되지 않는다.
- [ ] **AC-R6f**: Given 사용자가 본문을 수정한 SO-ADK 에이전트(`so-planner.md` 변경본)가 있는 레거시 디렉터리, When `install.sh --migrate`를 실행하면, Then 수정본이 백업 디렉터리에 그대로 보존된다.
- [ ] **AC-R6g**: Given jq를 사용할 수 없는 환경(PATH 조작)의 레거시 디렉터리, When `install.sh --migrate`를 실행하면, Then 훅 스크립트가 이동되지 않고(고아 훅 방지), 수동 제거 절차가 출력되며 exit 비0이다.
- [ ] **AC-R6h**: Given 사용자 `.claude/settings.json`이 **유효 JSON이 아닌**(파싱 실패) 레거시 디렉터리, When `install.sh --migrate`를 실행하면, Then 훅 엔트리 제거 실패가 감지되어 훅 스크립트가 이동되지 않고, 수동 제거 절차가 출력되며 exit 비0이다(고아 훅 방지의 실제 최빈 실패 경로 — R6 순서 강제 검증).
- [ ] **AC-R7a**: Given 이관 완료 저장소, When `tests/run-checks.sh`를 실행하면, Then 전체 PASS(FAIL 0)이다. 기준선: **이관 전 통과하던 검사 전부**(현재도 실패 중인 `check_settings_json_valid` 제외)의 갱신/대체본 + R7 신규 검사(AC-R4c·AC-R4d 포함)가 모두 포함된다. `claude` CLI 존재 시 plugin validate 검사가 포함된다. AC-R12a(태그 생성)는 포함되지 않는다(C-9).
- [ ] **AC-R7b**: Given 저장소의 **임시 사본**(작업 트리 오염 방지), When 오케스트레이터 본문이 **실제 참조하는 에이전트**(예: `so-planner.md`)를 `plugins/so-adk-core/agents/`에서 제거하고 테스트를 실행하면, Then 파일-참조 일치성 검사가 FAIL한다.
- [ ] **AC-R7c**: Given 저장소의 임시 사본, When 오케스트레이터 본문에서 참조되지 않는 임의 에이전트 파일(`so-orphan.md`)을 `plugins/so-adk-core/agents/`에 추가하고 테스트를 실행하면, Then 역방향(고아 에이전트) 검사가 FAIL한다.
- [ ] **AC-R7d**: Given `tests/run-checks.sh`, When 검사 함수 목록을 grep하면, Then R7 매핑표의 "갱신/대체" 결과 검사가 모두 존재하고, "삭제/대체" 처분된 구 검사명(`check_new_agents_in_install`, `check_install_calls_merge_in_normal_path` 등)은 존재하지 않는다.
- [ ] **AC-R8**: Given `README.md`와 `README.ko.md`, When 내용을 검사하면, Then (1) 마켓플레이스 추가 + 플러그인 설치 절차, (2) **모든 설치 예시 명령에 명시적 스코프 플래그(`--scope`)가 붙어 있음** (C-3), (3) orchestrator의 Project/Local 스코프 전용 경고, (4) core의 User 스코프 훅 전역 발동 경고, (5) 구→신 스킬 이름 대응표 + breaking change 명시, (6) 기존 사용자 마이그레이션 섹션(`--dry-run`/`--migrate`, 백업 위치, specs/archive 소멸 안내), (7) `pre-plugin` 태그 기반 복구 절차, (8) 개발 섹션 — 커밋된 settings.json은 "등록만, 설치 아님"(F12) + 기여자 명시적 설치 1회 + `--plugin-dir` 로드 방법 + "개인 설정은 `.claude/settings.local.json`에" 안내가 모두 존재한다.
- [ ] **AC-R9**: Given 이관 브랜치의 최종 커밋, When `.claude/agents`·`.claude/skills`·`.claude/hooks`·`.claude/so-orchestrator.md` 경로를 확인하면, Then 존재하지 않고, 저장소 `CLAUDE.md`에 `@.claude/so-orchestrator.md` 라인이 없으며, **`CLAUDE.md`는 빈 파일이 아니라 dogfooding 안내문(자체 플러그인 사용 사실 + 온보딩/`--plugin-dir` 안내)을 담고 있다** (C-7).
- [ ] **AC-R10**: Given `plugins/so-adk-orchestrator/agents/so-orchestrator.md`, When Step 2-B 섹션을 검사하면, Then `curl ... install.sh` 명령이 없고 플러그인 업데이트 안내가 존재한다.
- [ ] **AC-R11a**: Given 이관 브랜치, When `git tag --list pre-plugin`과 `git merge-base`를 확인하면, Then `pre-plugin` 태그가 존재하고 이관 착수 직전(레거시 완전) 커밋을 가리킨다.
- [ ] **AC-R11b**: Given 이관 브랜치의 커밋 히스토리, When 커밋 순서를 검사하면, Then (1) 레거시 제거(R9) 커밋이 브랜치의 최종 커밋이고, (2) **최종 커밋의 직전 커밋 메시지에 trailer `Smoke-Verified: AC-R2c,AC-R3e`가 존재한다** — `git log -1 <최종 커밋>^ --format=%B | grep -F 'Smoke-Verified:'`로 기계 검증(R11-e — v2의 "PR 본문 서술 순서" 검증은 선후 증명 불가로 폐기).
- [ ] **AC-R11c** (C-10): Given 이관 PR, When `gh pr view --json headRefName,baseRefName`을 확인하면, Then head는 `main`이 아닌 feature 브랜치이고 base는 `main`이다(R11-b 검증).
- [ ] **AC-R12a** (릴리스 시 1회 수행 — `tests/run-checks.sh` 미포함, C-9): Given 이관 완료 저장소, When 릴리스 시점에 `claude plugin tag ./plugins/so-adk-core`를 실행하면, Then plugin.json과 marketplace 엔트리의 버전 일치가 검증되고 `so-adk-core--v1.0.0` 태그가 생성된다(orchestrator 동일). 실제 태그를 만드는 부작용이 있으므로 자동 테스트에 넣지 않는다.
- [ ] **AC-R12b**: Given `README.md`, When 개발 섹션을 검사하면, Then 릴리스 절차(버전 범프 → `claude plugin tag` → push)가 문서화되어 있다.

## 개정 이력

| 버전 | 날짜 | 변경 내용 |
| ---- | ---- | -------- |
| v1 | 2026-08-21 | 최초 Draft 작성 (R1~R10) |
| v2 | 2026-08-21 | **Reviewer 검토(블로커 4건 등) + V0 스파이크 실측 반영.** (1) Background에 실측 확정 사실 F1~F10 신설 — BLOCKER 1(CLAUDE.md 공존)은 실측 해소, `"agent"` 키·스코프 키·`${CLAUDE_PLUGIN_ROOT}`·validate 통과는 리스크에서 확정 사실로 승격. (2) R2의 skills 네임스페이스 폴백 조항 삭제(F4) — AC-R1a 100% rename과의 충돌(MODERATE 8) 소멸. (3) R3에 `model`·`tools` 생략 확정(F10, Architect preview) + CLAUDE.md 공존·라우팅 수동 스모크 AC-R3e 신설(MODERATE 14). (4) "core는 User 스코프도 안전" 서술 정정, 선택지 (b) 채택 — core에도 스코프 경고 확장(MAJOR 5). (5) R6을 비파괴 구조로 재설계 — 백업 이동, `--migrate` 옵트인, `--dry-run`, CLAUDE.md 삭제 금지, 고정 목록, 마커 grep 가드, 고아 훅 방지, 사용자 수정 에이전트 백업 AC(BLOCKER 3). (6) R7에 기존 15개 검사 전수 매핑표 + AC-R7a 기준선 재정의(MAJOR 7), 명분을 "두 플러그인 간 유일한 기계적 계약"으로 재작성, 역방향 고아 검사 추가, `check_settings_json_valid`의 운명 결정. (7) AC-R5 범위를 `plugins/` 하위로 한정(MAJOR 6). (8) R11 신설 — `pre-plugin` 태그, feature 브랜치, 레거시 제거 최종 커밋 + 스모크 선행, dogfooding 즉시 복구(BLOCKER 2). (9) R12 신설 — `claude plugin tag` 릴리스 절차(MODERATE 10, F8). (10) R4에 `extraKnownMarketplaces` 커밋 요구(F7) + `.gitignore` 해제. (11) R5에 dev SKILL.md의 CLAUDE.md 참조 문구 수정 추가, 디렉터리 단위 git mv 명시(Architect preview). (12) Out of Scope에 "인지된 허용 동작 변경" 목록 신설(MODERATE 11, 12). (13) AC-R7b를 임시 사본 + 실제 참조 에이전트 기준으로 수정(MODERATE 13). |
| v3 | 2026-08-21 | **Reviewer 재검토(C-1~C-10) + V0 추가 실측 F11~F14 반영. R11 재설계.** (1) **F11 (C-1 해소, 유리)**: 교차 플러그인 에이전트 디스패치가 플레인 이름으로 동작함을 실측 확정 — 최상위 불변식(에이전트 15개·오케스트레이터 본문 무수정) 유지, 네임스페이스 폴백 불필요. AC-R3e에 실제 교차 플러그인 디스패치 1회(라우팅 발화 → so-planner 실호출) 추가(회귀 방지). (2) **F12 (C-2 확정, 불리)**: 커밋된 project settings.json만으로는 플러그인 미활성화(상대·절대경로 모두 음성, 명시적 install 대조군 양성) — **v2 R11의 "settings.json 커밋 즉시 복구" 메커니즘 폐기, R11을 (iii) 조합으로 재설계**: 전환 중 `--plugin-dir` 세션 로드(대안 i) + 전환 후 기여자 명시적 `claude plugin install --scope project` 1회(대안 ii, README 개발 섹션·커밋 계획 명문화). R4 문언에서 "등록(유효) vs 설치(안 됨)" 역할 경계를 구분 기술 — v2의 혼동 정정. R9 dogfooding 메커니즘도 동일하게 갱신. (3) **F13 (신규 함정)**: 잘못된 extraKnownMarketplaces source는 에러 없이 조용히 disabled — AC-R4d(source 스키마 검증, run-checks.sh 포함) 신설. (4) **F14**: 정규 source 형태 확정 — 커밋 값은 github 형태(`sotthang/so-adk`), directory 형태는 CLI가 절대경로를 기록해 커밋 부적합. (5) **C-3**: R4 대표 설치 명령에 명시적 `--scope project` 부여(스코프 생략 시 user 기본값이 경고 대상 위험의 happy path가 되는 모순 제거), AC-R8에 "설치 명령에 스코프 플래그 존재" 검사 추가. (6) **C-4**: AC-R5a에 무슬래시 패턴 추가 — 실물 4곳(오케스트레이터 88·228행 백틱형, 234·277행 무백틱형)이 검출되도록 자가 검증 조건 명시. (7) **C-5**: AC-R1a 자체 모순 해소 — frontmatter는 커밋 3 소관이므로 이동 커밋에서는 오케스트레이터 포함 전 파일 100% rename으로 문언 정리(R1에도 커밋 경계 명시). (8) **C-6**: v1 지적 #9의 처분은 v1 리뷰 원문이 보존되지 않아 **흡수/누락 여부 확인 불가**(정직 표기). 재발 방지로 Technical Approach에 리뷰 산출물 보존 관행(`specs/SPEC-{NNN}-{slug}.review.md`) 신설, v3 리뷰부터 적용. (9) **C-7**: 저장소 자체 CLAUDE.md 처분 확정 — 빈 파일로 두지 않고 dogfooding 안내문으로 대체(R9), AC-R9 확장. (10) **C-8**: install.ps1 `--migrate` 출력에 베타/수동 검증 경고 1줄 추가(R6). (11) **C-9**: AC-R12a를 "릴리스 시 1회 수행" AC로 분리 — 실제 태그 생성 부작용 때문에 run-checks.sh 미포함 명시(R7·R12·AC-R7a). README 문서화 검사는 AC-R12b로 분리. (12) **C-10**: R11(b) feature 브랜치 대응 AC-R11c 신설(`gh pr view` 기반). (13) **R11(e) 기계 검증 가능화**: "PR 본문 서술 순서"는 선후 증명 불가 — 최종 커밋 직전 커밋의 trailer `Smoke-Verified: AC-R2c,AC-R3e` + `git log --grep` 검증으로 교체(AC-R11b 재작성). (14) **R6 구현 주의 2건**: 훅 엔트리 제거 성공을 훅 스크립트 이동의 선행 조건으로 순서 강제 + settings.json 파싱 실패(비유효 JSON) 케이스 AC-R6h 신설, 에이전트 고정 목록에도 스킬과 대칭인 마커 grep 가드 적용(AC-R6b 확장). (15) **R4 gitignore 해제 신규 위험**: 커밋되는 settings.json의 최상위 키를 정확히 2개로 강제하는 AC-R4c(run-checks.sh 포함) + README "개인 설정은 settings.local.json에" 안내. (16) **인지된 허용 동작 변경 5번 추가**: 이 저장소 자체의 훅이 project 스코프 활성화 후 저장소 개발 중에도 발동. (17) F7 문언에 F12 범위 정정 주석 추가(등록 ≠ 설치). |

---

| v3.1 | 2026-08-21 | **Reviewer 승인 조건 반영(재검토 불요).** (1) **M-1**: AC-R5a 패턴 (1)의 제외 문자군에 `/`를 추가해 `/dev/null` 계열 오탐 9건(훅 7·에이전트 2)을 배제 — 보정 전 패턴은 본 AC와 AC-R7a를 영구 충족 불가로 만들었다. 실측 재현으로 확인 후 수정. (2) **M-2**: R1의 '에이전트 15개 본문 완전 무수정'이 과잉 일반화임을 정정 — `so-quality.md:3`의 `/refactor` 문자열은 R5 치환 대상(커밋 3)임을 예외로 명시. AC-R1a는 영향 없음(이동 커밋에서는 100% rename). (3) **I-1**: `--plugin-dir`의 위상을 시간축(전환 중 한시적)에서 **역할축(플러그인 개발자용 로드 방식)**으로 재프레이밍 — github 소스 특성상 기여자가 `plugin install`하면 published 사본이 무성으로 로드되는 문제 대응. (4) AC-R11b trailer의 증명 범위를 '선후 기계 검증 + 통과 여부는 자기 신고'로 정직화. (5) v3 리뷰 전문을 `.review-v3.md`로 분리(C-6 관행 적용) — so-reviewer에 Write 툴이 없어 인라인 보존됐던 것을 오케스트레이터가 분리. |

## v3 리뷰 결과

3차 검토(2026-08-21) 전문은 [SPEC-001-plugin-migration.review-v3.md](SPEC-001-plugin-migration.review-v3.md)에 보존되어 있다.

**판정**: Approved — 착수 전 M-1(AC-R5a 패턴 오탐), M-2(R1↔R5 모순) 문언 수정 필수.
