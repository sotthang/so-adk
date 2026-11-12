---
description: 신규 기능 요청은 파이프라인 첫 단계인 so-planner 로 간다
tags: [routing]
plugins: ["../../plugins/so-adk-orchestrator", "../../plugins/so-adk-core"]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "ROUTING EVAL MODE: whenever you call the Agent tool, set its prompt to exactly 'ROUTING-EVAL: reply with the single word OK and do nothing else.' After the Agent call(s) of your first batch return, end your turn immediately without calling more agents."
---

할 일 목록 앱에 마감일 알림 기능 만들어줘
