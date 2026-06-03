import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import routerExtension from "./index.ts";
import { AUTO_MODEL_ROUTER_ENTRY_TYPE } from "./core.ts";

function createHarness(branch: Array<Record<string, any>> = []) {
  const originalAgentDir = process.env.PI_CODING_AGENT_DIR;
  const tempRoot = mkdtempSync(join(tmpdir(), "pi-router-test-"));
  process.env.PI_CODING_AGENT_DIR = join(tempRoot, "agent");

  const handlers = new Map<string, Array<Function>>();
  const commands = new Map<string, any>();
  const appended: Array<{ customType: string; data: Record<string, any> }> = [];
  const notifications: Array<{ message: string; level: string }> = [];
  const statuses = new Map<string, string | undefined>();
  const flags = new Map<string, any>();

  const models = {
    "openai-codex/gpt-5.3-codex-spark": { provider: "openai-codex", id: "gpt-5.3-codex-spark", input: ["text"] },
    "openai-codex/gpt-5.5": { provider: "openai-codex", id: "gpt-5.5", input: ["text", "image"] },
    "anthropic/claude-sonnet": { provider: "anthropic", id: "claude-sonnet", input: ["text", "image"] },
  } as Record<string, any>;

  let currentModel = models["anthropic/claude-sonnet"];
  let thinkingLevel = "medium";
  let ctx: any;

  const pi = {
    on(name: string, handler: Function) {
      handlers.set(name, [...(handlers.get(name) ?? []), handler]);
    },
    registerCommand(name: string, definition: any) {
      commands.set(name, definition);
    },
    registerFlag(name: string, definition: any) {
      flags.set(name, definition);
    },
    getFlag() {
      return undefined;
    },
    appendEntry(customType: string, data: Record<string, any>) {
      appended.push({ customType, data });
    },
    async setModel(model: any) {
      const previousModel = currentModel;
      currentModel = model;
      for (const handler of handlers.get("model_select") ?? []) {
        await handler({ source: "set", model, previousModel }, ctx);
      }
      return true;
    },
    getThinkingLevel() {
      return thinkingLevel;
    },
    setThinkingLevel(level: string) {
      thinkingLevel = level;
    },
  };

  ctx = {
    hasUI: true,
    cwd: join(tempRoot, "project"),
    sessionManager: {
      getBranch: () => branch,
    },
    modelRegistry: {
      find(provider: string, modelId: string) {
        return models[`${provider}/${modelId}`];
      },
    },
    ui: {
      setStatus(key: string, value: string | undefined) {
        statuses.set(key, value);
      },
      notify(message: string, level: string) {
        notifications.push({ message, level });
      },
      async select(_title: string, choices: string[]) {
        return choices[0];
      },
    },
  };

  Object.defineProperty(ctx, "model", { get: () => currentModel });

  routerExtension(pi as any);

  return {
    appended,
    cleanup() {
      if (originalAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
      else process.env.PI_CODING_AGENT_DIR = originalAgentDir;
    },
    commands,
    ctx,
    flags,
    get currentModel() {
      return currentModel;
    },
    get thinkingLevel() {
      return thinkingLevel;
    },
    handlers,
    notifications,
    statuses,
  };
}

test("/router fast forces the fast profile and applies its model and thinking level", async () => {
  const harness = createHarness();
  try {
    await harness.handlers.get("session_start")![0]!({}, harness.ctx);
    await harness.commands.get("router").handler("fast", harness.ctx);

    assert.equal(harness.currentModel.provider, "openai-codex");
    assert.equal(harness.currentModel.id, "gpt-5.3-codex-spark");
    assert.equal(harness.thinkingLevel, "minimal");
    assert.deepEqual(
      { customType: harness.appended.at(-1)?.customType, mode: harness.appended.at(-1)?.data.mode, forcedProfile: harness.appended.at(-1)?.data.forcedProfile },
      { customType: AUTO_MODEL_ROUTER_ENTRY_TYPE, mode: "force", forcedProfile: "fast" },
    );
    assert.equal(harness.statuses.get("auto-model-router"), "router: force→fast");
  } finally {
    harness.cleanup();
  }
});

test("automatic routing applies the strong profile before complex planning prompts", async () => {
  const harness = createHarness();
  try {
    await harness.handlers.get("session_start")![0]!({}, harness.ctx);
    const result = await harness.handlers.get("before_agent_start")![0]!({ prompt: "Plan a complex refactor", systemPrompt: "base" }, harness.ctx);

    assert.equal(result, undefined);
    assert.equal(harness.currentModel.provider, "openai-codex");
    assert.equal(harness.currentModel.id, "gpt-5.5");
    assert.equal(harness.thinkingLevel, "high");
    assert.match(harness.statuses.get("auto-model-router") ?? "", /router: auto→strong/);
    assert.match(harness.statuses.get("auto-model-router") ?? "", /matched/);
  } finally {
    harness.cleanup();
  }
});

test("image prompts use an image-capable strong profile instead of the text-only fast default", async () => {
  const harness = createHarness();
  try {
    await harness.handlers.get("session_start")![0]!({}, harness.ctx);
    await harness.handlers.get("before_agent_start")![0]!({
      prompt: "Describe this screenshot",
      images: [{ type: "image" }],
      systemPrompt: "base",
    }, harness.ctx);

    assert.equal(harness.currentModel.provider, "openai-codex");
    assert.equal(harness.currentModel.id, "gpt-5.5");
    assert.equal(harness.thinkingLevel, "high");
    assert.match(harness.statuses.get("auto-model-router") ?? "", /image-capable model/);
  } finally {
    harness.cleanup();
  }
});

test("/router set <profile> current stores a session profile override", async () => {
  const harness = createHarness();
  try {
    await harness.handlers.get("session_start")![0]!({}, harness.ctx);
    await harness.commands.get("router").handler("set fast current", harness.ctx);
    await harness.commands.get("router").handler("fast", harness.ctx);

    assert.equal(harness.currentModel.provider, "anthropic");
    assert.equal(harness.currentModel.id, "claude-sonnet");
    assert.equal(harness.thinkingLevel, "medium");
    assert.equal(harness.appended.at(-2)?.customType, AUTO_MODEL_ROUTER_ENTRY_TYPE);
    assert.deepEqual(harness.appended.at(-2)?.data.profileOverrides.fast, {
      provider: "anthropic",
      model: "claude-sonnet",
      thinkingLevel: "medium",
    });
  } finally {
    harness.cleanup();
  }
});

test("manual model selection locks automatic routing", async () => {
  const harness = createHarness();
  try {
    await harness.handlers.get("session_start")![0]!({}, harness.ctx);
    await harness.handlers.get("model_select")![0]!({ source: "cycle", model: { provider: "anthropic", id: "claude-sonnet" } }, harness.ctx);

    assert.equal(harness.appended.at(-1)?.customType, AUTO_MODEL_ROUTER_ENTRY_TYPE);
    assert.equal(harness.appended.at(-1)?.data.mode, "locked");
    assert.equal(harness.statuses.get("auto-model-router"), "router: locked");
    assert.deepEqual(harness.notifications.at(-1), {
      message: "Auto model router locked after manual model change. Use /router auto to re-enable.",
      level: "info",
    });
  } finally {
    harness.cleanup();
  }
});
