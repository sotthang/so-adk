---
description: 보안 취약점 점검은 so-security 로 간다
tags: [routing]
plugins: ["../../plugins/so-adk-orchestrator", "../../plugins/so-adk-core"]
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: "ROUTING EVAL MODE: whenever you call the Agent tool, set its prompt to exactly 'ROUTING-EVAL: reply with the single word OK and do nothing else.' After the Agent call(s) of your first batch return, end your turn immediately without calling more agents."
---

이 프로젝트에 OWASP 기준 보안 취약점이 있는지 봐줘
