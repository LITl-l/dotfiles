// @ts-nocheck
/**
 * In-session parallel subagents for pi.
 *
 * This extension intentionally avoids tmux/pane orchestration. The parent pi
 * session gets one LLM-callable `subagent_many` tool that creates hidden,
 * in-memory child AgentSessions and returns only their final summaries.
 */

import {
  DefaultResourceLoader,
  SessionManager,
  createAgentSession,
  getAgentDir,
} from "@PI_NODE_MODULES@/@earendil-works/pi-coding-agent/index.js";
import { Type } from "@PI_NODE_MODULES@/typebox/build/index.mjs";

import {
  applyNativeWebSearch,
  buildSubagentPrompt,
  extractFinalAssistantText,
  formatCombinedReport,
  normalizeSubagentInput,
} from "@PI_SUBAGENTS_CORE@";

const READ_ONLY_TOOLS = ["read", "grep", "find", "ls"];

const taskSchema = Type.Object({
  id: Type.Optional(Type.String({ description: "Stable label for this subagent result, for example security-review." })),
  domain: Type.Optional(Type.String({ description: "Specialty domain: code, test, docs, security, perf, research, nix, shell, editor, hyprland, or custom." })),
  role: Type.Optional(Type.String({ description: "Optional role override added to the subagent prompt." })),
  task: Type.String({ description: "Focused task for this subagent. Keep it independent and bounded." }),
  context_mode: Type.Optional(Type.Union([
    Type.Literal("none"),
    Type.Literal("brief"),
    Type.Literal("recent"),
    Type.Literal("files"),
  ], { description: "How much context the parent believes this subagent needs. Defaults to brief." })),
  files: Type.Optional(Type.Array(Type.String(), { description: "Files the subagent should inspect first." })),
  web_search: Type.Optional(Type.Boolean({ description: "Request provider-native web search when supported by the current model/provider." })),
});

const inputSchema = Type.Object({
  tasks: Type.Array(taskSchema, {
    minItems: 1,
    description: "Independent subagent tasks to run. Use one task per domain or question.",
  }),
  shared_context: Type.Optional(Type.String({ description: "Short parent-context brief shared with every subagent." })),
  max_parallel: Type.Optional(Type.Number({ description: "Maximum child sessions to run concurrently. Clamped to 1..6; defaults to 4." })),
});

export default function (pi) {
  pi.registerTool({
    name: "subagent_many",
    label: "Subagents",
    description: "Run multiple hidden, same-provider, read-only subagents in parallel and return a consolidated report.",
    promptSnippet: "Delegate independent investigations to hidden same-provider subagents and summarize their results.",
    promptGuidelines: [
      "Use subagent_many when independent investigations would clutter the main conversation with search results, logs, or file reads.",
      "Use subagent_many explicitly; do not delegate recursively or use it for tasks that require coordinated file edits.",
      "Prefer one narrow subagent task per domain, such as code, security, test, docs, perf, research, or nix.",
    ],
    parameters: inputSchema,
    executionMode: "sequential",

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const normalized = normalizeSubagentInput(params);
      const parentModel = ctx.model;

      if (!parentModel) {
        return {
          isError: true,
          content: [{ type: "text", text: "subagent_many cannot run because no parent model is selected." }],
          details: { toolCallId, results: [] },
        };
      }

      emitUpdate(onUpdate, `Starting ${normalized.tasks.length} subagent(s), max_parallel=${normalized.maxParallel}...`);

      const startedAt = Date.now();
      const results = await runWithConcurrency(normalized.tasks, normalized.maxParallel, async (task) => {
        emitUpdate(onUpdate, `Running ${task.id} (${task.domain})...`);
        const result = await runSubagent({ task, normalized, parentModel, parentPi: pi, parentCtx: ctx, signal });
        emitUpdate(onUpdate, `Finished ${task.id}: ${result.status}.`);
        return result;
      });

      const report = formatCombinedReport(results);
      const details = {
        toolCallId,
        cwd: ctx.cwd,
        model: `${parentModel.provider}/${parentModel.id}`,
        durationMs: Date.now() - startedAt,
        tasks: normalized.tasks,
        results,
      };

      pi.appendEntry("subagent_many_report", details);

      return {
        content: [{ type: "text", text: report }],
        details,
      };
    },
  });
}

async function runSubagent({ task, normalized, parentModel, parentPi, parentCtx, signal }) {
  const startedAt = Date.now();
  let session;

  try {
    throwIfAborted(signal);

    const loader = new DefaultResourceLoader({
      cwd: parentCtx.cwd,
      agentDir: getAgentDir(),
      noExtensions: true,
      noPromptTemplates: true,
      noThemes: true,
      extensionFactories: [
        (childPi) => {
          childPi.on("before_provider_request", (event, childCtx) => {
            return applyNativeWebSearch(event.payload, childCtx.model ?? parentModel, task.webSearch);
          });
        },
      ],
    });
    await loader.reload();

    const created = await createAgentSession({
      cwd: parentCtx.cwd,
      agentDir: getAgentDir(),
      model: parentModel,
      thinkingLevel: parentPi.getThinkingLevel(),
      modelRegistry: parentCtx.modelRegistry,
      resourceLoader: loader,
      sessionManager: SessionManager.inMemory(parentCtx.cwd),
      tools: READ_ONLY_TOOLS,
    });
    session = created.session;

    const abortChild = () => {
      session?.abort().catch(() => undefined);
    };
    signal?.addEventListener("abort", abortChild, { once: true });

    try {
      const prompt = buildSubagentPrompt(task, {
        sharedContext: normalized.sharedContext,
        recentContext: collectRecentParentContext(parentCtx.sessionManager, task.contextMode),
        model: parentModel,
      });

      await session.prompt(prompt, { source: "extension" });
      throwIfAborted(signal);

      const output = extractFinalAssistantText(session.messages) || "Subagent completed without a final text response.";
      return {
        id: task.id,
        domain: task.domain,
        task: task.task,
        status: "ok",
        durationMs: Date.now() - startedAt,
        output,
      };
    } finally {
      signal?.removeEventListener("abort", abortChild);
    }
  } catch (error) {
    return {
      id: task.id,
      domain: task.domain,
      task: task.task,
      status: "error",
      durationMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
    };
  } finally {
    session?.dispose?.();
  }
}

async function runWithConcurrency(items, maxParallel, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;

  const workerCount = Math.min(Math.max(1, maxParallel), items.length);
  await Promise.all(Array.from({ length: workerCount }, async () => {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await worker(items[index], index);
    }
  }));

  return results;
}

function collectRecentParentContext(sessionManager, contextMode) {
  if (contextMode !== "recent") return "";

  const branch = sessionManager?.getBranch?.() ?? [];
  const recentMessages = branch
    .filter((entry) => entry?.type === "message" && ["user", "assistant"].includes(entry.message?.role))
    .slice(-8)
    .map((entry) => formatParentMessage(entry.message))
    .filter(Boolean);

  return truncateText(recentMessages.join("\n\n"), 6000);
}

function formatParentMessage(message) {
  const label = message.role === "assistant" ? "Assistant" : "User";
  const text = extractMessageText(message.content);
  return text ? `${label}: ${truncateText(text, 1200)}` : "";
}

function extractMessageText(content) {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";

  return content
    .filter((block) => block?.type === "text" && typeof block.text === "string")
    .map((block) => block.text.trim())
    .filter(Boolean)
    .join("\n")
    .trim();
}

function truncateText(text, maxLength) {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 14)).trimEnd()}\n[...truncated]`;
}

function emitUpdate(onUpdate, message) {
  onUpdate?.({ content: [{ type: "text", text: message }] });
}

function throwIfAborted(signal) {
  if (signal?.aborted) throw new Error("Subagent run was aborted");
}
