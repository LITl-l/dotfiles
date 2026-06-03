import test from "node:test";
import assert from "node:assert/strict";

import {
  AUTO_MODEL_ROUTER_ENTRY_TYPE,
  DEFAULT_ROUTER_CONFIG,
  buildRouterStatus,
  decideRoute,
  mergeRouterConfig,
  parseRouterCommand,
  reconstructRouterState,
  resolveEffectiveConfig,
  truncateSingleLine,
} from "./core.ts";

test("routes planning, architecture, debugging, and large refactor prompts to the strong profile", () => {
  for (const prompt of [
    "Create a complex planning document for this migration",
    "Debug the root cause of this flaky integration test",
    "Do a large refactor across the auth module",
    "Audit this for security and performance issues",
  ]) {
    const decision = decideRoute(prompt, DEFAULT_ROUTER_CONFIG, { mode: "auto" });

    assert.equal(decision?.profile, "strong", prompt);
    assert.equal(decision?.mode, "auto");
    assert.match(decision?.reason ?? "", /matched/i);
  }
});

test("uses the fast default profile for simple implementation prompts", () => {
  const decision = decideRoute("Implement this small change following the existing docs", DEFAULT_ROUTER_CONFIG, {
    mode: "auto",
  });

  assert.equal(decision?.profile, "fast");
  assert.equal(decision?.reason, "default profile");
});

test("does not route when off or locked, and routes forced profiles explicitly", () => {
  assert.equal(decideRoute("plan a rewrite", DEFAULT_ROUTER_CONFIG, { mode: "off" }), undefined);
  assert.equal(decideRoute("plan a rewrite", DEFAULT_ROUTER_CONFIG, { mode: "locked" }), undefined);

  const forced = decideRoute("plan a rewrite", DEFAULT_ROUTER_CONFIG, { mode: "force", forcedProfile: "fast" });
  assert.deepEqual(forced, {
    profile: "fast",
    reason: "forced profile",
    mode: "force",
  });
});

test("merges project config over global config without dropping unspecified profiles", () => {
  const merged = mergeRouterConfig(DEFAULT_ROUTER_CONFIG, {
    defaultProfile: "cheap",
    notifyOnRoute: false,
    profiles: {
      cheap: { provider: "openai", model: "gpt-cheap", thinkingLevel: "low" },
      strong: { thinkingLevel: "xhigh" },
    },
    rules: [{ profile: "cheap", patterns: ["cheap"], reason: "cheap keyword" }],
  });

  assert.equal(merged.defaultProfile, "cheap");
  assert.equal(merged.notifyOnRoute, false);
  assert.equal(merged.profiles.fast.model, "gpt-5.3-codex-spark");
  assert.deepEqual(merged.profiles.cheap, { provider: "openai", model: "gpt-cheap", thinkingLevel: "low" });
  assert.equal(merged.profiles.strong.provider, "openai-codex");
  assert.equal(merged.profiles.strong.model, "gpt-5.5");
  assert.equal(merged.profiles.strong.thinkingLevel, "xhigh");
  assert.deepEqual(merged.rules, [{ profile: "cheap", patterns: ["cheap"], reason: "cheap keyword" }]);
});

test("resolves session profile overrides into the effective config", () => {
  const effective = resolveEffectiveConfig(DEFAULT_ROUTER_CONFIG, {
    mode: "auto",
    profileOverrides: {
      fast: { provider: "anthropic", model: "claude-fast", thinkingLevel: "medium" },
    },
  });

  assert.equal(effective.profiles.fast.provider, "anthropic");
  assert.equal(effective.profiles.fast.model, "claude-fast");
  assert.equal(effective.profiles.fast.thinkingLevel, "medium");
  assert.equal(effective.profiles.strong.model, "gpt-5.5");
});

test("parses router slash-command arguments", () => {
  assert.deepEqual(parseRouterCommand(""), { action: "show" });
  assert.deepEqual(parseRouterCommand("status"), { action: "status" });
  assert.deepEqual(parseRouterCommand("auto"), { action: "mode", mode: "auto" });
  assert.deepEqual(parseRouterCommand("unlock"), { action: "mode", mode: "auto" });
  assert.deepEqual(parseRouterCommand("off"), { action: "mode", mode: "off" });
  assert.deepEqual(parseRouterCommand("lock"), { action: "mode", mode: "locked" });
  assert.deepEqual(parseRouterCommand("strong"), { action: "force", profile: "strong" });
  assert.deepEqual(parseRouterCommand("profile fast"), { action: "force", profile: "fast" });
  assert.deepEqual(parseRouterCommand("set fast current"), { action: "set-current", profile: "fast" });
  assert.deepEqual(parseRouterCommand("reload"), { action: "reload" });
  assert.deepEqual(parseRouterCommand("config"), { action: "config" });
  assert.deepEqual(parseRouterCommand("help"), { action: "help" });
});

test("reconstructs latest router state from session entries", () => {
  const entries = [
    { type: "custom", customType: AUTO_MODEL_ROUTER_ENTRY_TYPE, data: { mode: "force", forcedProfile: "strong" } },
    { type: "message", message: { role: "user" } },
    {
      type: "custom",
      customType: AUTO_MODEL_ROUTER_ENTRY_TYPE,
      data: {
        mode: "auto",
        profileOverrides: {
          fast: { provider: "openai", model: "gpt-fast", thinkingLevel: "low" },
        },
      },
    },
  ];

  assert.deepEqual(reconstructRouterState(entries, DEFAULT_ROUTER_CONFIG), {
    mode: "auto",
    profileOverrides: {
      fast: { provider: "openai", model: "gpt-fast", thinkingLevel: "low" },
    },
  });
});

test("builds compact status text with route rationale", () => {
  const status = buildRouterStatus(
    { mode: "auto", lastDecision: { mode: "auto", profile: "strong", reason: "matched complex", matchedPattern: "complex" } },
    DEFAULT_ROUTER_CONFIG,
    80,
  );

  assert.equal(status, "router: auto→strong — matched complex");
  assert.equal(buildRouterStatus({ mode: "off" }, DEFAULT_ROUTER_CONFIG), "router: off");
  assert.equal(buildRouterStatus({ mode: "locked" }, DEFAULT_ROUTER_CONFIG), "router: locked");
  assert.equal(buildRouterStatus({ mode: "force", forcedProfile: "fast" }, DEFAULT_ROUTER_CONFIG), "router: force→fast");
});

test("truncates status text on one line", () => {
  assert.equal(truncateSingleLine("one\n two\tthree", 20), "one two three");
  assert.equal(truncateSingleLine("1234567890", 6), "12345…");
});
