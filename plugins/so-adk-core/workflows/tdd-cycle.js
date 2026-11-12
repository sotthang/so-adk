export const meta = {
  name: 'tdd-cycle',
  description: 'SO-ADK TDD cycle: so-tester RED, so-developer/so-tester GREEN loop (max 5), so-quality REFACTOR + verify',
  whenToUse: 'After the SPEC is Architected. args: { spec: "specs/SPEC-NNN-slug.md", arch?: "specs/SPEC-NNN-slug.arch.md" }. Called by so-orchestrator Step 5.',
  phases: [
    { title: 'RED', detail: 'so-tester writes failing tests' },
    { title: 'GREEN', detail: 'so-developer ↔ so-tester, max 5 loops' },
    { title: 'REFACTOR', detail: 'so-quality, then so-tester re-verifies' },
  ],
}

// 사람 확인 지점은 여기에 없다 — 결과 status 를 받아 orchestrator 가 사용자에게 묻는다.
// status: green | exhausted | not-red | refactor-broke | error(stage)
const MAX_LOOPS = 5

const RED = {
  type: 'object',
  properties: {
    testFiles: { type: 'array', items: { type: 'string' } },
    failingCount: { type: 'number' },
    summary: { type: 'string' },
  },
  required: ['testFiles', 'failingCount'],
}
const VERIFY = {
  type: 'object',
  properties: {
    allPassing: { type: 'boolean' },
    failing: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
  },
  required: ['allPassing', 'failing'],
}

const spec = args && args.spec
if (!spec) return { status: 'error', stage: 'args', message: 'args.spec (SPEC file path) is required' }
const ctx = `SPEC: ${spec}` + (args.arch ? `\nArchitecture: ${args.arch}` : '')
const T = 'so-adk-core:so-tester'
const verify = (label) => agent(
  `${ctx}\n\nMode 2: GREEN verification. Run the full test suite. Do not modify any file. ` +
  'Report whether every test passes and list each failing test as "<file>::<name> — <reason>".',
  { label, agentType: T, schema: VERIFY })

phase('RED')
const red = await agent(`${ctx}\n\nMode 1: RED phase. Write the failing tests for this SPEC, run them, and report the test files and how many fail.`,
  { label: 'red', agentType: T, schema: RED })
if (!red) return { status: 'error', stage: 'red' }
if (!red.failingCount) return { status: 'not-red', red }

phase('GREEN')
let loops = 0
let failing = []
let passed = false
while (loops < MAX_LOOPS) {
  loops++
  const report = failing.length ? `\n\nPrevious verification still failing:\n- ${failing.join('\n- ')}` : ''
  const dev = await agent(`${ctx}\n\nTDD GREEN, loop ${loops}/${MAX_LOOPS}. Write the minimum code to make the failing tests pass.${report}`,
    { label: `developer-${loops}`, agentType: 'so-adk-core:so-developer' })
  if (dev === null) return { status: 'error', stage: 'green', loops, failing }
  const v = await verify(`green-verify-${loops}`)
  if (!v) return { status: 'error', stage: 'green-verify', loops, failing }
  failing = v.failing
  if (v.allPassing) { passed = true; break }
  log(`loop ${loops}/${MAX_LOOPS}: ${failing.length} failing`)
}
if (!passed) return { status: 'exhausted', loops, failing }

phase('REFACTOR')
const q = await agent(`${ctx}\n\nTDD REFACTOR. All tests pass. Improve structure without changing behavior; run the tests after each change.`,
  { label: 'quality', agentType: 'so-adk-core:so-quality' })
if (q === null) return { status: 'error', stage: 'refactor', loops }
const after = await verify('refactor-verify')
if (!after) return { status: 'error', stage: 'refactor-verify', loops }
if (!after.allPassing) return { status: 'refactor-broke', loops, failing: after.failing }

return { status: 'green', loops, testFiles: red.testFiles }
