import test from "node:test";
import assert from "node:assert/strict";

import {
  GOAL_CUSTOM_ENTRY_TYPE,
  buildGoalPromptSection,
  parseGoalCommand,
  reconstructGoalFromEntries,
  truncateGoalForStatus,
} from "./core.ts";

test("parses show, set, and clear goal commands", () => {
  assert.deepEqual(parseGoalCommand(""), { action: "show" });
  assert.deepEqual(parseGoalCommand("   "), { action: "show" });
  assert.deepEqual(parseGoalCommand("ship the pi goal command"), {
    action: "set",
    goal: "ship the pi goal command",
  });
  assert.deepEqual(parseGoalCommand(" clear "), { action: "clear" });
  assert.deepEqual(parseGoalCommand("reset"), { action: "clear" });
  assert.deepEqual(parseGoalCommand("clear the blockers"), {
    action: "set",
    goal: "clear the blockers",
  });
});

test("rejects blank goals after normalization", () => {
  assert.deepEqual(parseGoalCommand("\n\t"), { action: "show" });
});

test("reconstructs the latest goal from session branch entries", () => {
  const entries = [
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "first" } },
    { type: "message", message: { role: "user" } },
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "second" } },
  ];

  assert.equal(reconstructGoalFromEntries(entries), "second");
});

test("reconstructs cleared goal from session branch entries", () => {
  const entries = [
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "first" } },
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "clear" } },
  ];

  assert.equal(reconstructGoalFromEntries(entries), undefined);
});

test("ignores malformed goal entries", () => {
  const entries = [
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "valid" } },
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "set", goal: "" } },
    { type: "custom", customType: GOAL_CUSTOM_ENTRY_TYPE, data: { action: "unknown", goal: "bad" } },
  ];

  assert.equal(reconstructGoalFromEntries(entries), "valid");
});

test("truncates goal text for compact status display", () => {
  assert.equal(truncateGoalForStatus("short goal", 20), "short goal");
  assert.equal(truncateGoalForStatus("12345678901234567890", 20), "12345678901234567890");
  assert.equal(truncateGoalForStatus("123456789012345678901", 20), "12345678901234567...");
});

test("builds a concise current-goal prompt section", () => {
  assert.equal(buildGoalPromptSection(undefined), undefined);
  assert.equal(
    buildGoalPromptSection("ship the pi goal command"),
    "\n\nCurrent session goal:\nship the pi goal command\n\nUse this goal to stay oriented. If the user's latest request conflicts with it, follow the latest user request and mention the mismatch.",
  );
});

test("limits goal text injected into the prompt", () => {
  assert.equal(
    buildGoalPromptSection("123456789012345678901", 20),
    "\n\nCurrent session goal:\n12345678901234567...\n\nUse this goal to stay oriented. If the user's latest request conflicts with it, follow the latest user request and mention the mismatch.",
  );
});
