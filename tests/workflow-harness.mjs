// tests/workflow-harness.mjs — Workflow 스크립트를 스텁 agent() 로 실행하는 단위 테스트 하네스 (SPEC-010)
//
// 실제 Workflow 런타임은 스크립트 본문을 async 컨텍스트에서 돌리며 agent/parallel/pipeline/phase/log/args
// 를 전역으로 준다. 여기서는 같은 이름을 AsyncFunction 매개변수로 주입해 제어 흐름(루프 상한,
// 판정표)만 결정적으로 검증한다. 모델 호출은 없다.
import { readFileSync } from 'node:fs';

const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

export function loadWorkflow(path) {
  const src = readFileSync(path, 'utf8');
  if (!/^export const meta = \{/m.test(src)) throw new Error(`${path}: missing 'export const meta = {'`);
  const body = src.replace(/^export const meta = /m, 'const meta = ');
  const fn = new AsyncFunction('agent', 'parallel', 'pipeline', 'phase', 'log', 'args', 'budget', body);
  return async ({ args, agent }) => {
    const calls = [];
    const rec = (prompt, opts = {}) => {
      const call = { prompt, opts };
      calls.push(call);
      return Promise.resolve(agent(call, calls)).catch(() => null);
    };
    const parallel = (thunks) => Promise.all(thunks.map((t) => Promise.resolve().then(t).catch(() => null)));
    const pipeline = (items, ...stages) =>
      Promise.all(items.map(async (it, i) => {
        let v = it;
        for (const s of stages) {
          try { v = await s(v, it, i); } catch { return null; }
        }
        return v;
      }));
    const budget = { total: null, spent: () => 0, remaining: () => Infinity };
    const result = await fn(rec, parallel, pipeline, () => {}, () => {}, args, budget);
    return { result, calls };
  };
}

/** agentType 이름 끝(so-tester 등)으로 호출을 분류한다 */
export const role = (call) => (call.opts.agentType || '').split(':').pop();
