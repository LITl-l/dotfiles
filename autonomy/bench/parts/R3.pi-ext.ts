// R3.pi-ext.ts — bench part R3: the done gate for pi (P1's Stop hook, on agent_before_settle).
//
// `llm pi-run` copies this file and lib/done-gate.sh into the sandbox's /run/llm-tools and
// loads it with `-e`, which still works under --no-extensions. It imports nothing from pi:
// the devShell's pi and the user's pi live at different store paths. The gate runs agent
// code, but pi itself already runs inside bwrap.
//
// It gates on the DONE file at settle, not on tool_call, so whichever tool wrote DONE it is
// seen, with no Bash-string parsing to game. done-gate.sh hides DONE as DONE.pending while
// it runs, so a run killed mid-gate is left with no DONE. A refusal deletes DONE and asks pi for one
// continuation carrying the reason; the 6th refusal deletes DONE and lets pi settle
// (gate_exhausted). Every verdict appends one line to /run/llm-gate.jsonl, which pi-run
// binds to <ws>.gate.jsonl beside the workspace.
import { appendFileSync, existsSync, rmSync } from "node:fs";
import { join } from "node:path";

const GATE = "/run/llm-tools/done-gate.sh";
const LEDGER = "/run/llm-gate.jsonl";
const CAP = 5;
const GATE_BUDGET_MS = 380_000;

export default function (pi: any) {
  let refusals = 0;
  const log = (verdict: string, reason?: string) => {
    const row = { ts: new Date().toISOString().replace(/\.\d+Z$/, "Z"), agent: "pi", verdict,
      ...(reason ? { reason } : {}) };
    try {
      appendFileSync(LEDGER, JSON.stringify(row) + "\n");
    } catch {
      // A missing ledger loses the figure, never the gate.
    }
  };

  pi.on("agent_before_settle", async (event: any, ctx: any) => {
    const done = join(ctx.cwd, "DONE");
    if (!existsSync(done)) return;
    const r = await pi.exec("bash", [GATE, ctx.cwd], { cwd: ctx.cwd, timeout: GATE_BUDGET_MS });
    if (r.code === 0 && !r.killed) {
      log("pass");
      return;
    }
    let reason = String(r.stdout ?? "").trim();
    if (r.killed) reason = `The checker ran longer than ${GATE_BUDGET_MS / 1000} s; ./test must finish faster.`;
    else if (!reason) reason = `The checker could not run (exit ${r.code}): ${String(r.stderr ?? "").slice(-300)}`;
    // The gate renames DONE to DONE.pending while it runs and deletes it on a refusal;
    // only a killed gate leaves it, which is not a DONE either.
    rmSync(done, { force: true });
    rmSync(`${done}.pending`, { force: true });
    if (refusals >= CAP) {
      log("exhausted", reason);
      return;
    }
    refusals++;
    log("refused", reason);
    return {
      entries: [...(event.entries ?? []), {
        type: "custom_message",
        customType: "bench-done-gate",
        content: `${reason} DONE was removed; fix and recreate it.`,
        display: false,
      }],
      continue: true,
    };
  });
}
