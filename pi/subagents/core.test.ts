import test from "node:test";
import assert from "node:assert/strict";

import {
  applyNativeWebSearch,
  buildSubagentPrompt,
  extractFinalAssistantText,
  formatCombinedReport,
  formatSubagentProgressStatus,
  formatSubagentProgressUpdate,
  normalizeSubagentInput,
  supportsNativeWebSearch,
  type SubagentProgressEntry,
} from "./core.ts";

const anthropicModel = {
  provider: "anthropic",
  api: "anthropic-messages",
  id: "claude-sonnet-4-5",
};

const openaiResponsesModel = {
  provider: "openai",
  api: "openai-responses",
  id: "gpt-5.1-codex",
};

const openaiChatModel = {
  provider: "openai",
  api: "openai-chat-completions",
  id: "gpt-4o",
};

test("normalizes task defaults and clamps parallelism", () => {
  const normalized = normalizeSubagentInput({
    max_parallel: 99,
    shared_context: "Investigate auth regressions.",
    tasks: [
      { domain: "security", task: "Review token storage." },
      { task: "Check current framework docs.", web_search: true },
      { id: "Bad ID!!", domain: "nix", task: "Inspect Home Manager config.", context_mode: "files" },
    ],
  });

  assert.equal(normalized.maxParallel, 6);
  assert.equal(normalized.sharedContext, "Investigate auth regressions.");
  assert.deepEqual(
    normalized.tasks.map((task) => ({ id: task.id, domain: task.domain, contextMode: task.contextMode, webSearch: task.webSearch })),
    [
      { id: "security-1", domain: "security", contextMode: "brief", webSearch: false },
      { id: "custom-2", domain: "custom", contextMode: "brief", webSearch: true },
      { id: "bad-id", domain: "nix", contextMode: "files", webSearch: false },
    ],
  );
});

test("detects provider-native web search support conservatively", () => {
  assert.equal(supportsNativeWebSearch(anthropicModel), true);
  assert.equal(supportsNativeWebSearch(openaiResponsesModel), true);
  assert.equal(supportsNativeWebSearch(openaiChatModel), false);
  assert.equal(supportsNativeWebSearch({ provider: "google", api: "google-generative-ai", id: "gemini" }), false);
});

test("injects native search tools without mutating original payloads", () => {
  const anthropicPayload = { tools: [{ name: "read", input_schema: { type: "object" } }] };
  const patchedAnthropic = applyNativeWebSearch(anthropicPayload, anthropicModel, true);

  assert.notEqual(patchedAnthropic, anthropicPayload);
  assert.deepEqual(anthropicPayload.tools, [{ name: "read", input_schema: { type: "object" } }]);
  assert.deepEqual(patchedAnthropic.tools.at(-1), {
    type: "web_search_20250305",
    name: "web_search",
    max_uses: 5,
  });

  const openaiPayload = { tools: [{ type: "function", name: "read" }] };
  const patchedOpenAI = applyNativeWebSearch(openaiPayload, openaiResponsesModel, true);
  assert.deepEqual(patchedOpenAI.tools.at(-1), { type: "web_search_preview" });

  const unsupportedPayload = { tools: [] };
  assert.equal(applyNativeWebSearch(unsupportedPayload, openaiChatModel, true), unsupportedPayload);
  assert.equal(applyNativeWebSearch(openaiPayload, openaiResponsesModel, false), openaiPayload);
});

test("builds focused domain prompts with context handoff and search status", () => {
  const prompt = buildSubagentPrompt(
    {
      id: "research-1",
      domain: "research",
      task: "Find current OAuth device flow guidance.",
      role: "API researcher",
      contextMode: "files",
      files: ["modules/pi.nix", "pi/agent-compat.ts"],
      webSearch: true,
    },
    {
      sharedContext: "We are improving pi agent workflows.",
      model: openaiChatModel,
    },
  );

  assert.match(prompt, /You are the research subagent/);
  assert.match(prompt, /API researcher/);
  assert.match(prompt, /We are improving pi agent workflows\./);
  assert.match(prompt, /modules\/pi\.nix/);
  assert.match(prompt, /Native web search: unavailable for this provider\/model/);
  assert.match(prompt, /Return only your final report/);
});

test("includes recent parent context when provided to subagent prompts", () => {
  const prompt = buildSubagentPrompt(
    {
      id: "code-1",
      domain: "code",
      task: "Review the current decision.",
      contextMode: "recent",
      files: [],
      webSearch: false,
    },
    {
      sharedContext: "Brief shared summary.",
      recentContext: "User: continue\nAssistant: I will check CI.",
      model: anthropicModel,
    },
  );

  assert.match(prompt, /Recent parent context:/);
  assert.match(prompt, /User: continue/);
  assert.match(prompt, /Assistant: I will check CI\./);
});

test("extracts the final assistant text block from a child session", () => {
  const text = extractFinalAssistantText([
    { role: "user", content: [{ type: "text", text: "question" }] },
    { role: "assistant", content: [{ type: "text", text: "draft" }] },
    { role: "toolResult", content: [{ type: "text", text: "tool output" }] },
    {
      role: "assistant",
      content: [
        { type: "thinking", thinking: "hidden" },
        { type: "text", text: "final" },
        { type: "text", text: "answer" },
      ],
    },
  ]);

  assert.equal(text, "final\nanswer");
});

test("formats subagent progress status with running purpose labels", () => {
  const entries: SubagentProgressEntry[] = [
    { id: "code-1", domain: "code", task: "Map the auth flow.", state: "ok" },
    { id: "test-2", domain: "test", task: "Find relevant test commands.", state: "running" },
    { id: "docs-3", domain: "docs", task: "Check user-facing docs.", state: "queued" },
    { id: "security-4", domain: "security", task: "Review token handling.", state: "error" },
  ];

  assert.equal(
    formatSubagentProgressStatus(entries, 200),
    "subagents: 2/4 done, 1 running, 1 queued, 1 failed — test-2: Find relevant test commands.",
  );
});

test("formats subagent progress updates with every task status", () => {
  const entries: SubagentProgressEntry[] = [
    { id: "code-1", domain: "code", task: "Map the auth flow.", state: "ok" },
    { id: "test-2", domain: "test", task: "Find relevant test commands.", state: "running" },
    { id: "docs-3", domain: "docs", task: "Check user-facing docs.", state: "queued" },
    { id: "security-4", domain: "security", task: "Review token handling.", state: "error" },
  ];

  const update = formatSubagentProgressUpdate(entries);

  assert.match(update, /Subagents: 2\/4 done, 1 running, 1 queued, 1 failed/);
  assert.match(update, /✓ code-1 \(code\) — Map the auth flow\./);
  assert.match(update, /⏳ test-2 \(test\) — Find relevant test commands\./);
  assert.match(update, /○ docs-3 \(docs\) — Check user-facing docs\./);
  assert.match(update, /✗ security-4 \(security\) — Review token handling\./);
});

test("formats consolidated reports with successes and per-agent failures", () => {
  const report = formatCombinedReport([
    {
      id: "security-1",
      domain: "security",
      task: "Review auth.",
      status: "ok",
      durationMs: 1200,
      output: "No critical findings.",
    },
    {
      id: "research-2",
      domain: "research",
      task: "Search docs.",
      status: "error",
      durationMs: 100,
      error: "native search unavailable",
    },
  ]);

  assert.match(report, /## Subagent Results/);
  assert.match(report, /security-1/);
  assert.match(report, /No critical findings\./);
  assert.match(report, /research-2/);
  assert.match(report, /native search unavailable/);
});
