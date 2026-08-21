# SPEC-004: 마이그레이션 래퍼의 구 레이아웃 스킬 미처리

**Status**: Draft
**Created**: 2026-08-22

## Goal

curl 설치 시절의 구 레이아웃 스킬 파일이 마이그레이션 후에도 사용자 프로젝트에 남아 새 플러그인 스킬과 공존하는 문제를 없앤다.

## Background

### 결함 — 회귀다

`install.sh`의 마이그레이션 래퍼(SPEC-001 R6)는 스킬을 **디렉터리 형식만** 인식한다:

```bash
LEGACY_INTERNAL_SKILLS=(so-foundation so-spec-format so-tdd-workflow so-context)
  [ -d ".claude/skills/${s}" ]                    # 디렉터리만
LEGACY_GUARDED_SKILLS=(dev plan pr refactor)
  [ -f ".claude/skills/${s}/SKILL.md" ] && grep -qF "Claude normally triggers this automatically" ...
```

그러나 SO-ADK는 과거에 **평탄(flat) 레이아웃**으로 스킬을 배포했다 — `.claude/skills/<name>.md`, 내부 스킬은 `.claude/skills/internal/<name>.md`. 그 시절 설치본을 그대로 둔 프로젝트에서는 위 조건이 하나도 참이 되지 않아 **스킬이 0건 감지된다.**

**이것은 단순 공백이 아니라 회귀다.** 전환 이전 `install.sh`(`pre-plugin:85-102`)는 이 레이아웃을 명시적으로 알고 정리하고 있었다:

```bash
# Older versions shipped flat skill files and a /simplify command. ...
LEGACY_FLAT_SKILLS=(dev plan simplify pr so-foundation so-spec-format so-tdd-workflow so-context)
for s in "${LEGACY_FLAT_SKILLS[@]}"; do
  rm -f "./.claude/skills/${s}.md"
  rm -f "./.claude/skills/internal/${s}.md"
done
rmdir "./.claude/skills/internal" 2>/dev/null || true
# Old /simplify skill dir (renamed to refactor) — remove the SO-ADK one only.
if [ -f "./.claude/skills/simplify/SKILL.md" ] && \
   grep -q "so-quality" "./.claude/skills/simplify/SKILL.md" 2>/dev/null; then
  rm -rf "./.claude/skills/simplify"
fi
```

SPEC-001 C4에서 래퍼를 재작성하며 이 지식이 통째로 유실됐다. 특히 **`simplify`**(`refactor`로 rename되기 전 이름)는 현행 고정 목록에 아예 없다.

### 실사용 프로젝트에서 확인 (2026-08-22 실측)

`~/Develop/so-agentbar`를 실제로 마이그레이션하며 확인했다:

| 항목 | 결과 |
| ---- | ---- |
| `install.sh --dry-run`의 스킬 감지 | **0건** |
| 실제 존재한 SO-ADK 스킬 | **8개** — `skills/{dev,plan,pr,simplify}.md`, `skills/internal/so-{context,foundation,spec-format,tdd-workflow}.md` |
| 8개 전부 SO-ADK 마커 보유 | 예 (아래) |
| 처리 | 수동으로 백업에 이동해야 했다 |

에이전트·훅·오케스트레이터는 정상 감지·이동됐다. 스킬만 통째로 누락된다.

### 피해

방치된 구 스킬은 삭제되지 않고 **활성 상태로 남는다**:

- `/dev`·`/plan`·`/pr`가 로컬 정의로 계속 존재해 새 `/so-adk-core:dev` 계열과 **공존**한다. 사용자는 두 벌의 명령을 보게 되고, 구 명령은 이미 사라진 `.claude/agents/so-*.md`를 참조하므로 호출 시 실패한다.
- `/simplify`는 rename 이전 이름이라 더 혼란스럽다.
- `skills/internal/so-foundation.md` 등은 플러그인 스킬과 동명이다. SPEC-001 **F25**가 에이전트에서 실측한 "로컬이 플레인 이름 호출에서 이긴다"는 성질이 스킬에도 적용된다면, 프리로드되는 내용이 낡은 사본일 수 있다 — **미검증 가정이므로 R5에서 측정한다.**

### 마커 확정 (실측)

구 flat 파일의 frontmatter description에 **현행 래퍼가 디렉터리 형식 가드에 쓰는 것과 동일한 문구**가 들어 있다:

| 파일 | description 발췌 |
| ---- | ---------------- |
| `dev.md` | "... Claude normally triggers this automatically from natural language ..." |
| `plan.md` | "... Claude normally triggers this automatically ..." |
| `pr.md` | "... Claude normally triggers this automatically ..." |
| `simplify.md` | "... Claude normally triggers this automatically ..." |

즉 **가드 로직은 그대로 두고 검사 경로만 넓히면 된다.** 내부 스킬 4종은 `so-` 접두의 SO-ADK 전유 이름이므로 현행과 동일하게 무가드로 처리한다.

## Requirements

### R1 — 평탄 레이아웃 스킬 감지

- 다음 두 경로를 추가로 검사한다:
  - `.claude/skills/<name>.md` (평탄)
  - `.claude/skills/internal/<name>.md` (구 내부 스킬 위치)
- 디렉터리 형식(`.claude/skills/<name>/SKILL.md`) 검사는 현행대로 유지한다. 한 프로젝트에 두 레이아웃이 섞여 있을 수 있으므로 **양쪽 모두** 검사한다.

### R2 — `simplify`를 고정 목록에 편입

- 사용자 호출 스킬 목록에 `simplify`를 추가한다 — `refactor`로 rename되기 전 이름이며, 현행 목록에 없어 평탄·디렉터리 양쪽 모두 미처리다.
- 목록은 `(dev plan pr refactor simplify)`가 된다. 이 집합은 동결된 레거시이며 더 자라지 않는다(주석 유지).

### R3 — 마커 가드 대칭 유지

- 사용자 호출 스킬(`dev`/`plan`/`pr`/`refactor`/`simplify`)은 레이아웃과 무관하게 `Claude normally triggers this automatically` 마커를 확인한 파일만 이동한다. 동명의 사용자 작성 스킬을 절대 건드리지 않는다.
- 내부 스킬 4종(`so-*`)은 SO-ADK 전유 이름이므로 현행과 동일하게 무가드로 이동한다.

### R4 — 삭제가 아닌 백업 이동 (계약 유지)

- 구 `install.sh`는 이들을 `rm -f`로 **삭제**했으나, 래퍼의 계약은 **백업 이동**이다(SPEC-001 R6). 평탄 파일도 `.claude/.so-adk-backup-<ts>/`로 **이동**한다.
- 백업 내 경로는 원래 레이아웃을 알아볼 수 있게 보존한다(예: `skills/internal/so-foundation.md`).

### R5 — 스킬 override 성질 측정

- SPEC-001 F25는 **에이전트**에 대해 "로컬 `.claude/` 정의가 동명 플러그인 정의를 플레인 이름 호출에서 override한다"를 실측했다. **스킬에도 같은 성질이 성립하는지는 미측정이다.**
- 성립한다면 방치된 구 스킬이 플러그인 스킬을 가리는 것이므로 본 SPEC의 심각도가 올라간다. 성립하지 않는다면 피해는 "죽은 명령이 목록에 보인다"로 한정된다.
- 착수 전 스파이크로 측정하고 결과를 확정 사실로 기록한다. **측정 결과에 따라 R1~R4의 우선순위를 조정하되, 요구사항 자체는 변하지 않는다**(어느 쪽이든 구 자산은 치워야 한다).

### R6 — 빈 디렉터리 정리

- 이동 후 `.claude/skills/internal/`과 `.claude/skills/`가 비면 `rmdir`한다(비어 있을 때만 — 현행 `.claude/agents` 처리와 동일 방식).

### R7 — dry-run 반영 및 회귀 방지 테스트

- `--dry-run`이 평탄 파일도 계획에 출력한다. **관측된 증상이 "dry-run에 스킬이 0건"이었으므로 이 출력이 곧 사용자에게 보이는 수정 결과다.**
- `tests/run-checks.sh`에 평탄 레이아웃 픽스처를 추가해 회귀를 고정한다. 기존 `mk_legacy_fixture`는 디렉터리 형식만 만들므로 **혼합 레이아웃 픽스처**가 필요하다.

## Out of Scope

- 구 스킬을 새 이름으로 자동 변환하거나 사용자 프로젝트에 재설치하는 것 — 래퍼는 치우기만 한다.
- `install.ps1`의 동일 수정 — SPEC-001과 같은 이유로 best-effort이며 AC를 두지 않는다. (단 bash 쪽과 동작을 맞춘다.)
- 에이전트·훅·오케스트레이터 처리 로직 — 정상 동작이 실측 확인됐다.
- 이미 마이그레이션을 마친 사용자에 대한 소급 조치 — 재실행하면 잔존 파일이 감지된다(래퍼는 멱등).
- SPEC-001 F25가 확인한 에이전트 override 동작 자체 — 본 SPEC은 스킬에 대해서만 측정한다(R5).

## Technical Approach

- **수정 파일**: `install.sh`, `install.ps1`(best-effort), `tests/run-checks.sh`
- **`detect_legacy` 확장**: 스킬 검사를 레이아웃 3종으로 넓힌다.

  ```bash
  LEGACY_GUARDED_SKILLS=(dev plan pr refactor simplify)   # simplify 추가 — R2
  SKILL_MARKER="Claude normally triggers this automatically"

  # 사용자 호출 스킬: 디렉터리 / 평탄 / (구) internal 평탄 — 마커 가드 공통
  for s in "${LEGACY_GUARDED_SKILLS[@]}"; do
    for p in ".claude/skills/${s}/SKILL.md" ".claude/skills/${s}.md" ".claude/skills/internal/${s}.md"; do
      [ -f "$p" ] && grep -qF "$SKILL_MARKER" "$p" 2>/dev/null && FOUND_GUARDED_SKILLS+=("$p")
    done
  done
  ```

  - 현행은 스킬 **이름**을 배열에 담지만, 레이아웃이 여러 개가 되면 이름만으로 원래 경로를 복원할 수 없다. **경로를 담도록 바꾼다** — 이동 로직과 dry-run 출력이 단순해진다.
  - 내부 스킬도 동일하게 `.claude/skills/<s>/`(디렉터리), `.claude/skills/<s>.md`, `.claude/skills/internal/<s>.md` 3종을 검사한다.
- **이동 로직**: 백업 내 상대 경로를 원본 그대로 재현한다(`$BACKUP/skills/internal/so-foundation.md` 형태). 디렉터리 원본은 디렉터리째 이동한다.
- **테스트**: `mk_legacy_fixture`는 그대로 두고 `mk_legacy_fixture_flat`(평탄 전용)과 혼합 케이스를 추가한다. 기존 검사 6종의 기대값이 바뀌지 않도록 **기존 픽스처는 수정하지 않는다**.
- **Tidy First 분류**: 전부 **행위 변경**이다. RED는 커밋하지 않고 작업 트리에서 통과시킨 뒤 테스트와 수정을 한 커밋으로 묶는다(전역 COMMIT DISCIPLINE — SPEC-003과 동일).
- **배포**: `so-adk-core` 자산이 아니라 저장소 루트의 `install.sh`이므로 플러그인 버전 범프는 불필요하다. main 병합 즉시 `raw.../main/install.sh`가 서빙한다.

## 미검증 가정 (Unverified Assumptions)

| ID | 가정 | 거짓일 경우 | 측정 방법 |
| -- | ---- | ----------- | --------- |
| S-1 | 로컬 `.claude/skills/<name>.md`가 동명 플러그인 스킬을 override한다(F25의 스킬 판) | 심각도가 "플러그인 스킬이 가려짐"에서 "죽은 명령이 목록에 보임"으로 낮아진다. R1~R4는 그대로 필요 | 스크래치 프로젝트에 센티널을 심은 평탄 스킬을 두고 `so-adk-core` 설치 → 해당 스킬 호출 → 어느 쪽 내용이 나오는지 확인 (F25와 동일 기법) |
| S-2 | 평탄 레이아웃 설치본이 `so-agentbar` 외에도 존재한다 | 영향 범위가 1개 프로젝트로 한정되어 우선순위가 낮아진다 | 배포 범위를 알 수 없으므로 측정 불가 — **정직 표기**: `so-agentbar` 1건만 확인됐고, 이 레이아웃은 구 `install.sh`가 정리 대상으로 명시했을 만큼 실재했다 |

## Acceptance Criteria

- [ ] **AC-R1a**: Given `.claude/skills/dev.md`(마커 보유)와 `.claude/skills/internal/so-foundation.md`가 있는 평탄 레이아웃 픽스처, When `install.sh --dry-run`을 실행하면, Then 두 파일이 모두 계획에 출력되고 파일은 변경되지 않는다.
- [ ] **AC-R1b**: Given 같은 픽스처, When `install.sh --migrate`를 실행하면, Then 두 파일이 `.claude/.so-adk-backup-<ts>/skills/dev.md`와 `.../skills/internal/so-foundation.md`로 **이동**(삭제 아님)된다.
- [ ] **AC-R1c** (혼합 레이아웃): Given `.claude/skills/dev.md`(평탄)와 `.claude/skills/plan/SKILL.md`(디렉터리)가 **동시에** 있는 픽스처, When `--migrate`를 실행하면, Then 둘 다 백업으로 이동한다.
- [ ] **AC-R2**: Given `.claude/skills/simplify.md`(마커 보유)와 `.claude/skills/simplify/SKILL.md`(마커 보유)를 각각 가진 두 픽스처, When `--migrate`를 실행하면, Then 양쪽 모두 백업으로 이동한다.
- [ ] **AC-R3a**: Given `.claude/skills/dev.md`가 존재하지만 **SO-ADK 마커가 없는**(사용자 작성) 픽스처, When `--migrate`를 실행하면, Then 그 파일은 **이동되지 않고 원위치에 남는다**.
- [ ] **AC-R3b**: Given `.claude/skills/internal/so-foundation.md`, When `--migrate`를 실행하면, Then 마커 유무와 무관하게 이동한다(SO-ADK 전유 이름).
- [ ] **AC-R4**: Given 사용자가 내용을 수정한 `.claude/skills/dev.md`, When `--migrate`를 실행하면, Then 수정본이 백업에 **그대로 보존**된다(바이트 동일).
- [ ] **AC-R5** (스파이크 결과 등재): Given S-1 측정 완료, When SPEC을 확인하면, Then 스킬 override 성립 여부가 확정 사실로 기재되어 있다.
- [ ] **AC-R6**: Given 평탄 스킬만 있던 픽스처의 마이그레이션 후, When `.claude/skills`와 `.claude/skills/internal` 경로를 확인하면, Then 비었으므로 제거되어 있다. 단 사용자 스킬이 남아 있으면 디렉터리는 **유지**된다.
- [ ] **AC-R7a**: Given `tests/run-checks.sh`, When 실행하면, Then 평탄·혼합 레이아웃 검사가 포함되어 있고 전체 FAIL 0이다.
- [ ] **AC-R7b** (회귀 고정): Given 기존 디렉터리 전용 픽스처(`mk_legacy_fixture`), When 기존 마이그레이션 검사 6종을 실행하면, Then 기대값이 변하지 않고 그대로 통과한다.
- [ ] **AC-R8** (실물 회귀 재현): Given `so-agentbar`에서 관측된 것과 동일한 구성(에이전트 14 + 평탄 스킬 8 + 훅 1)의 픽스처, When `--dry-run`을 실행하면, Then 스킬 감지가 **0건이 아니라 8건**이다.

## 관련 문서

- 회귀의 출처: `git show pre-plugin:install.sh` 85–102행 (구 `install.sh`의 레거시 평탄 스킬 정리 로직)
- 에이전트 override 실측: [SPEC-001-plugin-migration.md](SPEC-001-plugin-migration.md) 확정 사실 **F25**
- 래퍼 요구사항 원본: [SPEC-001-plugin-migration.md](SPEC-001-plugin-migration.md) **R6**
