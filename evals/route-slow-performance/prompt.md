---
description: 성능 문제는 so-performance 로 간다
tags: [routing]
plugins: ["../../plugins/so-adk-orchestrator", "../../plugins/so-adk-core"]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "ROUTING EVAL MODE: whenever you call the Agent tool, set its prompt to exactly 'ROUTING-EVAL: reply with the single word OK and do nothing else.' After the Agent call(s) of your first batch return, end your turn immediately without calling more agents."
---

API 응답이 너무 느려서 타임아웃이 나. 원인 찾아줘
