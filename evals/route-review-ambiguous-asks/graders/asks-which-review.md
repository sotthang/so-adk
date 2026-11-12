---
type: regex
# 문장 일치가 아니라 동작을 고정한다 — 두 갈래(SPEC 검토 / 코드 리뷰)를 모두 제시하며 되묻는다.
# 실측: orchestrator 는 정규 문구 대신 번호 목록으로 되묻는다 (2026-11-12).
pattern: "^(?=[\\s\\S]*SPEC ?(검토|리뷰))(?=[\\s\\S]*코드 ?리뷰)[\\s\\S]*[?？]"
target: last_message
---
