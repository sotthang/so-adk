export const meta = {
  name: 'pr-gate',
  description: 'SO-ADK pre-PR gate: so-preflight and so-security in parallel, fail-closed verdict',
  whenToUse: 'Before creating a PR or when asked whether the branch is ready to merge. Called by so-orchestrator Step 6.',
  phases: [{ title: 'Gate', detail: 'so-preflight + so-security in parallel' }],
}

// 판정은 모델이 아니라 이 표가 내린다 (SPEC-010 R2). 결과가 없거나(null) 판정 유보면 통과시키지 않는다.
//   NO-GO | BLOCK | HOLD | 응답 없음  → stop
//   GO + CONDITIONAL                → ask
//   GO + PASS                       → proceed

const VERDICT = (values) => ({
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: values },
    findings: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['verdict', 'findings'],
})

const BASE = 'Pre-PR gate check for the current branch. Determine the diff baseline with your own procedure (never assume main). ' +
  'If there is nothing to review, the verdict is HOLD (판정 유보) — never GO/PASS on an empty diff. ' +
  'Return your verdict and one line per finding.'

phase('Gate')
const [preflight, security] = await parallel([
  () => agent(BASE, { label: 'preflight', agentType: 'so-adk-core:so-preflight', schema: VERDICT(['GO', 'NO-GO', 'HOLD']) }),
  () => agent(BASE, { label: 'security', agentType: 'so-adk-core:so-security', schema: VERDICT(['PASS', 'CONDITIONAL', 'BLOCK', 'HOLD']) }),
])

let decision = 'stop'
if (preflight && security && preflight.verdict === 'GO') {
  if (security.verdict === 'PASS') decision = 'proceed'
  else if (security.verdict === 'CONDITIONAL') decision = 'ask'
}
if (!preflight || !security) log('pr-gate: an agent returned no result — failing closed')

return { decision, preflight, security }
