import test from "node:test";
import assert from "node:assert/strict";

import goalExtension from "./index.ts";
import { GOAL_CUSTOM_ENTRY_TYPE } from "./core.ts";

function createHarness(branch: Array<Record<string, any>> = []) {
  const handlers = new Map<string, Array<Function>>();
  const commands = new Map<string, any>();
  const appended: Array<{ customType: string; data: Record<string, any> }> = [];
  const notifications: Array<{ message: string; level: string }> = [];
  const statuses = new Map<string, string | undefined>();

  const pi = {
    on(name: string, handler: Function) {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
    },
    registerCommand(name: string, definition: any) {
      commands.set(name, definition);
    },
    appendEntry(customType: string, data: Record<string, any>) {
      appended.push({ customType, data });
    },
  };

  const ctx = {
    hasUI: true,
    sessionManager: {
      getBranch: () => branch,
    },
    ui: {
      setStatus(key: string, value: string | undefined) {
        statuses.set(key, value);
      },
      notify(message: string, level: string) {
        notifications.push({ message, level });
      },
    },
  };

  goalExtension(pi as any);

  return { appended, commands, ctx, handlers, notifications, statuses };
}

test("restores session goal, updates status, and injects prompt context", async () => {
  const { ctx, handlers, statuses } = createHarness([
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "ship goal command" } },
  ]);

  await handlers.get("session_start")![0]!({}, ctx);
  assert.equal(statuses.get("goal"), "goal: ship goal command");

  const result = await handlers.get("before_agent_start")![0]!({ systemPrompt: "base" }, ctx);
  assert.equal(
    result.systemPrompt,
    "base\n\nCurrent session goal:\nship goal command\n\nUse this goal to stay oriented. If the user's latest request conflicts with it, follow the latest user request and mention the mismatch.",
  );
});

test("refreshes goal status after tree navigation", async () => {
  const branch = [
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "old branch goal" } },
  ];
  const { ctx, handlers, statuses } = createHarness(branch);

  await handlers.get("session_start")![0]!({}, ctx);
  assert.equal(statuses.get("goal"), "goal: old branch goal");

  branch.push({ type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "new branch goal" } });
  await handlers.get("session_tree")![0]!({}, ctx);
  assert.equal(statuses.get("goal"), "goal: new branch goal");
});

test("goal command shows, sets, and clears current session goal", async () => {
  const { appended, commands, ctx, handlers, notifications, statuses } = createHarness();
  const goal = commands.get("goal");

  await handlers.get("session_start")![0]!({}, ctx);
  await goal.handler("", ctx);
  assert.deepEqual(notifications.at(-1), { message: "No session goal set", level: "info" });

  await goal.handler("finish the tests", ctx);
  assert.equal(statuses.get("goal"), "goal: finish the tests");
  assert.equal(appended.at(-1)?.customType, GOAL_CUSTOM_ENTRY_TYPE);
  assert.deepEqual(
    { action: appended.at(-1)?.data.action, goal: appended.at(-1)?.data.goal },
    { action: "set", goal: "finish the tests" },
  );
  assert.deepEqual(notifications.at(-1), { message: "Session goal set: finish the tests", level: "info" });

  await goal.handler("", ctx);
  assert.deepEqual(notifications.at(-1), { message: "Current goal: finish the tests", level: "info" });

  await goal.handler("clear", ctx);
  assert.equal(statuses.get("goal"), undefined);
  assert.equal(appended.at(-1)?.customType, GOAL_CUSTOM_ENTRY_TYPE);
  assert.deepEqual({ action: appended.at(-1)?.data.action }, { action: "clear" });
  assert.deepEqual(notifications.at(-1), { message: "Session goal cleared", level: "info" });
});

test("does not inject prompt context when no goal is set", async () => {
  const { ctx, handlers } = createHarness();

  await handlers.get("session_start")![0]!({}, ctx);
  const result = await handlers.get("before_agent_start")![0]!({ systemPrompt: "base" }, ctx);

  assert.equal(result, undefined);
});
