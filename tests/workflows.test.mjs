// tests/workflows.test.mjs — plugins/so-adk-core/workflows/*.js 제어 흐름 단위 테스트 (SPEC-010)
// 실행: node --test tests/workflows.test.mjs   (run-checks.sh 의 check_workflow_unit_tests 가 호출)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { loadWorkflow, role } from './workflow-harness.mjs';

const wf = (name) => loadWorkflow(fileURLToPath(new URL(`../plugins/so-adk-core/workflows/${name}.js`, import.meta.url)));

// ---------------------------------------------------------------- pr-gate
const gate = async (pre, sec) => (await wf('pr-gate'))({
  args: {},
  agent: (c) => (role(c) === 'so-preflight' ? pre : sec),
});

test('pr-gate: GO + PASS → proceed', async () => {
  const { result } = await gate({ verdict: 'GO', findings: [] }, { verdict: 'PASS', findings: [] });
  assert.equal(result.decision, 'proceed');
});

test('pr-gate: NO-GO → stop', async () => {
  const { result } = await gate({ verdict: 'NO-GO', findings: ['2 failing'] }, { verdict: 'PASS', findings: [] });
  assert.equal(result.decision, 'stop');
});

test('pr-gate: BLOCK → stop even when preflight is GO', async () => {
  const { result } = await gate({ verdict: 'GO', findings: [] }, { verdict: 'BLOCK', findings: ['sqli'] });
  assert.equal(result.decision, 'stop');
});

test('pr-gate: GO + CONDITIONAL → ask', async () => {
  const { result } = await gate({ verdict: 'GO', findings: [] }, { verdict: 'CONDITIONAL', findings: ['low'] });
  assert.equal(result.decision, 'ask');
});

test('pr-gate: HOLD (빈 diff 판정 유보) → stop, never proceed (SPEC-005 R2)', async () => {
  for (const [p, s] of [['HOLD', 'PASS'], ['GO', 'HOLD']]) {
    const { result } = await gate({ verdict: p, findings: [] }, { verdict: s, findings: [] });
    assert.equal(result.decision, 'stop', `${p}+${s}`);
  }
});

test('pr-gate: agent died (null) → stop (fail closed)', async () => {
  const { result } = await gate({ verdict: 'GO', findings: [] }, null);
  assert.equal(result.decision, 'stop');
});

test('pr-gate: preflight and security are dispatched concurrently with plugin agentTypes', async () => {
  let release;
  let started = 0;
  const gateP = new Promise((r) => { release = r; });
  const run = (await wf('pr-gate'))({
    args: {},
    agent: async (c) => { started++; await gateP; return role(c) === 'so-preflight' ? { verdict: 'GO', findings: [] } : { verdict: 'PASS', findings: [] }; },
  });
  await new Promise((r) => setImmediate(r));
  // 아무것도 끝나지 않은 시점에 두 호출이 이미 나가 있어야 병렬이다 (순차면 1)
  assert.equal(started, 2, 'both agents must be in flight before either resolves');
  release();
  const { calls } = await run;
  assert.deepEqual(calls.map((c) => c.opts.agentType).sort(), ['so-adk-core:so-preflight', 'so-adk-core:so-security']);
  for (const c of calls) assert.ok(c.opts.schema, 'verdict must be schema-enforced');
});

// ---------------------------------------------------------------- tdd-cycle
/** verifyResults[i] = i 번째 GREEN 검증 결과(true=통과). refactorOk = REFACTOR 후 검증 결과 */
const cycle = async ({ red = { failingCount: 3, testFiles: ['t.test.ts'] }, verifyResults = [true], refactorOk = true, args = { spec: 'specs/SPEC-001-x.md' } } = {}) => {
  let v = 0;
  return (await wf('tdd-cycle'))({
    args,
    agent: (c) => {
      const label = c.opts.label || '';
      if (label === 'red') return red;
      if (label.startsWith('green-verify')) {
        const ok = verifyResults[Math.min(v++, verifyResults.length - 1)];
        return { allPassing: ok, failing: ok ? [] : [`fail-${v}`] };
      }
      if (label === 'refactor-verify') return { allPassing: refactorOk, failing: refactorOk ? [] : ['broke'] };
      return 'done';
    },
  });
};
const count = (calls, r) => calls.filter((c) => role(c) === r).length;

test('tdd-cycle: passes on first GREEN → green, quality runs once', async () => {
  const { result, calls } = await cycle();
  assert.equal(result.status, 'green');
  assert.equal(result.loops, 1);
  assert.equal(count(calls, 'so-developer'), 1);
  assert.equal(count(calls, 'so-quality'), 1);
});

test('tdd-cycle: never passes → exhausted after exactly 5 developer loops, no quality', async () => {
  const { result, calls } = await cycle({ verifyResults: [false] });
  assert.equal(result.status, 'exhausted');
  assert.equal(result.loops, 5);
  assert.equal(count(calls, 'so-developer'), 5);
  assert.equal(count(calls, 'so-quality'), 0);
  assert.deepEqual(result.failing, ['fail-5']);
});

test('tdd-cycle: passes on 3rd loop and feeds the failure report back to developer', async () => {
  const { result, calls } = await cycle({ verifyResults: [false, false, true] });
  assert.equal(result.status, 'green');
  assert.equal(result.loops, 3);
  const devs = calls.filter((c) => role(c) === 'so-developer');
  assert.match(devs[1].prompt, /fail-1/);
  assert.match(devs[2].prompt, /fail-2/);
});

test('tdd-cycle: RED step died → error at red, developer never called', async () => {
  const { result, calls } = await cycle({ red: null });
  assert.equal(result.status, 'error');
  assert.equal(result.stage, 'red');
  assert.equal(count(calls, 'so-developer'), 0);
});

test('tdd-cycle: RED wrote no failing tests → not-red (TDD 위반), developer never called', async () => {
  const { result, calls } = await cycle({ red: { failingCount: 0, testFiles: [] } });
  assert.equal(result.status, 'not-red');
  assert.equal(count(calls, 'so-developer'), 0);
});

test('tdd-cycle: refactor broke tests → refactor-broke', async () => {
  const { result } = await cycle({ refactorOk: false });
  assert.equal(result.status, 'refactor-broke');
  assert.deepEqual(result.failing, ['broke']);
});

test('tdd-cycle: missing args.spec → error at args, no agents', async () => {
  const { result, calls } = await cycle({ args: {} });
  assert.equal(result.status, 'error');
  assert.equal(result.stage, 'args');
  assert.equal(calls.length, 0);
});

test('tdd-cycle: every agent call uses a so-adk-core agentType (keeps per-agent model)', async () => {
  const { calls } = await cycle({ verifyResults: [false, true] });
  for (const c of calls) assert.match(c.opts.agentType || '', /^so-adk-core:so-(tester|developer|quality)$/);
});
