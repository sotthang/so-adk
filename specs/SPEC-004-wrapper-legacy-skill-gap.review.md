# SPEC-004 검토 (v1)

**대상**: [SPEC-004-wrapper-legacy-skill-gap.md](SPEC-004-wrapper-legacy-skill-gap.md)
**검토일**: 2026-08-22
**판정**: **Approved — 착수 전 M-1 문언 수정 필수 (요구사항은 유지, 심각도 서술을 정정)**

> 검토 주체 명기: `so-reviewer` 에이전트가 아니라 세션 메인 스레드가 수행했다. 작성자와 동일하여 독립성이 없다. 아래 M-1은 판단이 아니라 **실측 3건**에 근거한다.

## 실측 (S-1 스파이크 — R5 요구)

SPEC이 미검증 가정으로 남긴 S-1을 스크래치 프로젝트에서 측정했다. `so-adk-core@so-adk`를 `--scope local` 설치하고 센티널을 심은 레거시 스킬을 배치한 뒤 관측했다.

| # | 측정 | 결과 |
| - | ---- | ---- |
| **M-a** | 평탄 `.claude/skills/dev.md`(마커 보유)가 스킬 목록에 나타나는가 | **음성** — 목록에 없음. `so-adk-core:dev`만 존재. 평탄 파일은 **인식 자체가 되지 않는다** |
| **M-b** | 디렉터리 `.claude/skills/refactor/SKILL.md`가 나타나는가, 플러그인 것을 가리는가 | **인식됨, 그러나 override 아님** — 플레인 `refactor`로 나타나고 `so-adk-core:refactor`와 **공존**한다(서로 다른 이름) |
| **M-c** | 플러그인 에이전트의 `skills:` 플레인 이름 프리로드가 로컬 디렉터리 스킬로 새는가 | **양성 — 샌다.** 로컬 `.claude/skills/so-foundation/SKILL.md`(센티널)를 둔 상태에서 `so-adk-core:so-planner`를 호출하니 `SENTINEL=LOCAL-SO-FOUNDATION`을 반환. tool_uses 0이므로 파일을 읽은 것이 아니라 **실제로 프리로드된 것** |

M-c는 SPEC-001 **F25**(에이전트 override)의 스킬 판이며, **본 저장소 문서가 주장해 온 "마이그레이션 필수" 근거를 스킬 영역까지 확장 확정**한다.

## M-1 (Major) — Background의 피해 서술이 과장이다. 실제 잔여 범위는 훨씬 좁다

SPEC 초안은 피해를 이렇게 적었다:

> - `/dev`·`/plan`·`/pr`가 로컬 정의로 계속 존재해 새 `/so-adk-core:dev` 계열과 **공존**한다. … 구 명령은 이미 사라진 `.claude/agents/so-*.md`를 참조하므로 호출 시 실패한다.
> - `skills/internal/so-foundation.md` 등은 플러그인 스킬과 동명이다. … 프리로드되는 내용이 낡은 사본일 수 있다

**둘 다 사실이 아니다.**

1. **M-a**에 따라 평탄 파일은 목록에 나타나지 않는다. 공존도, 호출 실패도 일어나지 않는다 — **그냥 디스크에 남은 죽은 파일이다.** 구 `install.ps1`이 남긴 주석 `# flat .md files under .claude/skills/ are NOT recognized by Claude Code`가 정확했다.
2. **M-c**의 위험(에이전트 프리로드 오염)은 **디렉터리 형식**에서만 성립하는데, 그 케이스는 **현행 래퍼가 이미 커버한다** — `install.sh:75-77`의 `[ -d ".claude/skills/${s}" ]`가 `so-foundation`·`so-spec-format`·`so-tdd-workflow`·`so-context`를 디렉터리 형식으로 잡는다. 본 SPEC이 추가하려는 평탄 경로는 이 위험과 무관하다.

**정정된 잔여 범위** — 본 SPEC이 실제로 해결하는 것:

| 항목 | 실제 피해 | 심각도 |
| ---- | --------- | ------ |
| 평탄 스킬 8종이 백업되지 않고 남음 | 디스크에 죽은 파일. 동작 영향 없음 | **낮음 (위생)** |
| `--dry-run`이 스킬을 0건으로 보고 | 사용자가 "치울 게 없다"고 오인. **관측된 증상이자 신뢰 문제** | **중간** |
| `simplify`가 고정 목록에 없음 | 평탄이면 무해(M-a), 디렉터리면 죽은 명령이 목록에 남음 | 낮음 |

**조치**: Background의 피해 서술을 위 실측으로 교체하고, **심각도를 "높음"이 아니라 "위생 + dry-run 정확성"으로 정직 표기**한다. 요구사항 R1~R7은 그대로 유지한다 — 남은 이유가 약해졌을 뿐 사라지지 않았고, 특히 `--dry-run`이 실재하는 SO-ADK 자산을 0건으로 보고하는 것은 래퍼의 계약 위반이다.

## m-1 (Minor) — 디렉터리 형식 `simplify`는 이 저장소에서 출하된 적이 없다

`git log --all -- '*skills/simplify*'` 확인 결과 **평탄 `skills/simplify.md`만 존재**했고 디렉터리 형식 이력은 없다. 구 `install.sh`가 `skills/simplify/SKILL.md`를 `so-quality` 마커로 가드해 지우던 것은 방어적 코드였다.

또한 실물 평탄 `simplify.md`의 description에 **공통 마커**(`Claude normally triggers this automatically`)가 들어 있음을 이력에서 확인했다 — 따라서 R3의 단일 마커 가드로 충분하며, `so-quality` 마커를 별도로 받아들일 필요가 없다. 디렉터리 형식은 방어적으로만 검사한다.

## m-2 (Minor) — 같은 스킬이 두 레이아웃으로 동시 존재하는 경우가 AC에 없다

AC-R1c는 *서로 다른* 스킬이 다른 레이아웃인 경우만 다룬다. `.claude/skills/dev.md`와 `.claude/skills/dev/SKILL.md`가 **동시에** 있으면 둘 다 이동해야 하고 백업 경로가 충돌하지 않아야 한다. AC를 1건 추가한다.

## 확인된 사항 (지적 아님)

- 에이전트·훅·오케스트레이터 처리는 실사용 프로젝트 3곳(`Dcty-Hub`·`Dcty-Agent`·`so-agentbar`)에서 정상 동작을 확인했다.
- `Dcty-Hub`·`Dcty-Agent`는 내부 스킬이 **디렉터리 형식**이었고 현행 래퍼가 정상 처리했다 — M-c의 위험 케이스가 실제로 존재했고 이미 막혔다는 뜻이다.
- 회귀 근거(`git show pre-plugin:install.sh` 85–102)는 실물 확인했다.

## 판정

**Approved.** M-1은 착수 전 문언 수정 필수 — 다만 **요구사항 변경이 아니라 심각도·근거 서술의 정정**이므로 재검토는 불요하다. m-1·m-2는 함께 반영한다.

이 검토의 핵심 교훈: SPEC 초안이 피해를 **측정 없이 추정**했고, 그 추정이 두 군데 모두 틀렸다. R5가 스파이크를 요구한 것이 정확한 판단이었다.
