---
description: 코드 리뷰는 내장 code-review 스킬로 위임하고 so-reviewer 로 보내지 않는다 (SPEC-006)
tags: [routing]
plugins: ["../../plugins/so-adk-orchestrator", "../../plugins/so-adk-core"]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "ROUTING EVAL MODE: whenever you call the Agent tool, set its prompt to exactly 'ROUTING-EVAL: reply with the single word OK and do nothing else.' After the Agent call(s) of your first batch return, end your turn immediately without calling more agents."
---

지금 변경사항 코드 리뷰해줘
