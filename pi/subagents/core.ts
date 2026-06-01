export type SubagentContextMode = "none" | "brief" | "recent" | "files";

export interface RawSubagentTask {
  id?: unknown;
  domain?: unknown;
  role?: unknown;
  task?: unknown;
  context_mode?: unknown;
  files?: unknown;
  web_search?: unknown;
}

export interface RawSubagentInput {
  tasks?: unknown;
  shared_context?: unknown;
  max_parallel?: unknown;
}

export interface NormalizedSubagentTask {
  id: string;
  domain: string;
  role?: string;
  task: string;
  contextMode: SubagentContextMode;
  files: string[];
  webSearch: boolean;
}

export interface NormalizedSubagentInput {
  tasks: NormalizedSubagentTask[];
  sharedContext: string;
  maxParallel: number;
}

export interface SubagentPromptOptions {
  sharedContext?: string;
  recentContext?: string;
  model?: Partial<ModelLike>;
}

export interface ModelLike {
  provider?: string;
  api?: string;
  id?: string;
}

export interface SubagentRunResult {
  id: string;
  domain: string;
  task: string;
  status: "ok" | "error";
  durationMs: number;
  output?: string;
  error?: string;
}

export type SubagentProgressState = "queued" | "running" | "ok" | "error";

export interface SubagentProgressEntry {
  id: string;
  domain: string;
  task: string;
  state: SubagentProgressState;
}

const CONTEXT_MODES = new Set<SubagentContextMode>(["none", "brief", "recent", "files"]);

const DOMAIN_INSTRUCTIONS: Record<string, string> = {
  code: "Map the real implementation path. Cite files, symbols, and call flow. Avoid broad scans when targeted reads are enough.",
  test: "Focus on test strategy, failing-test hypotheses, coverage gaps, and commands a parent agent can run later. Do not modify files.",
  docs: "Explain documentation, public APIs, configuration, and usage constraints. Prefer exact references over general advice.",
  security: "Review for concrete security risks, unsafe defaults, secret exposure, injection, auth, permissions, and supply-chain concerns. Avoid style-only findings.",
  perf: "Look for bottlenecks, unnecessary work, caching opportunities, hot paths, and measurement plans. Separate evidence from speculation.",
  research: "Research current external facts when native web search is available. Return concise citations or exact source references.",
  nix: "Review Nix, Home Manager, flakes, module boundaries, activation scripts, and reproducibility. Prefer minimal, idiomatic Nix changes.",
  shell: "Review shell behavior, quoting, portability, process control, and failure handling. Prefer safe, explicit commands.",
  editor: "Review editor configuration, keybindings, plugin interactions, and user workflow impact.",
  hyprland: "Review Hyprland, Waybar, launcher, display, and WSL-related desktop configuration.",
  custom: "Follow the caller-provided role and task exactly. Keep work bounded and report only useful findings.",
};

export function normalizeSubagentInput(input: RawSubagentInput): NormalizedSubagentInput {
  const rawTasks = Array.isArray(input.tasks) ? input.tasks : [];
  const sharedContext = stringOrEmpty(input.shared_context).trim();
  const maxParallel = clampInteger(input.max_parallel, 1, 6, 4);

  return {
    sharedContext,
    maxParallel,
    tasks: rawTasks.map((raw, index) => normalizeTask(raw as RawSubagentTask, index)),
  };
}

export function supportsNativeWebSearch(model: Partial<ModelLike> | undefined): boolean {
  if (!model) return false;
  if (model.api === "anthropic-messages" || model.provider === "anthropic") return true;
  if (model.api === "openai-responses") return true;
  return false;
}

export function applyNativeWebSearch<TPayload extends Record<string, any>>(
  payload: TPayload,
  model: Partial<ModelLike> | undefined,
  enabled: boolean,
): TPayload {
  if (!enabled || !supportsNativeWebSearch(model)) return payload;

  const tools = Array.isArray(payload.tools) ? payload.tools : [];

  if (model?.api === "anthropic-messages" || model?.provider === "anthropic") {
    if (tools.some((tool) => tool?.type === "web_search_20250305" || tool?.name === "web_search")) return payload;
    return {
      ...payload,
      tools: [
        ...tools,
        {
          type: "web_search_20250305",
          name: "web_search",
          max_uses: 5,
        },
      ],
    };
  }

  if (model?.api === "openai-responses") {
    if (tools.some((tool) => tool?.type === "web_search_preview")) return payload;
    return {
      ...payload,
      tools: [...tools, { type: "web_search_preview" }],
    };
  }

  return payload;
}

export function buildSubagentPrompt(task: NormalizedSubagentTask, options: SubagentPromptOptions = {}): string {
  const domainInstruction = DOMAIN_INSTRUCTIONS[task.domain] ?? DOMAIN_INSTRUCTIONS.custom;
  const sharedContext = options.sharedContext?.trim();
  const recentContext = options.recentContext?.trim();
  const searchStatus = task.webSearch
    ? supportsNativeWebSearch(options.model)
      ? "available and requested; use provider-native search only when current external facts are needed"
      : "unavailable for this provider/model; explicitly say when your answer is limited by this"
    : "not requested";

  const fileSection = task.files.length > 0
    ? task.files.map((file) => `- ${file}`).join("\n")
    : "- No specific files were provided. Use targeted repository search if needed.";

  return [
    `You are the ${task.domain} subagent (${task.id}).`,
    task.role ? `Caller role override: ${task.role}` : undefined,
    "",
    "Your job is to complete one bounded investigation for the parent pi session.",
    "Keep your detailed exploration in your own context. Return only your final report.",
    "Do not modify files. Do not claim you verified something unless you actually inspected evidence.",
    "",
    "Domain guidance:",
    domainInstruction,
    "",
    "Task:",
    task.task,
    "",
    "Shared context from parent:",
    sharedContext || "No shared parent context was provided.",
    "",
    recentContext ? "Recent parent context:" : undefined,
    recentContext || undefined,
    recentContext ? "" : undefined,
    "Context handoff:",
    `- Mode: ${task.contextMode}`,
    "- Files to inspect first:",
    fileSection,
    "",
    `Native web search: ${searchStatus}.`,
    "",
    "Output format:",
    "1. Findings — concise bullets, most important first.",
    "2. Evidence — file paths, symbols, commands, or external sources you actually used.",
    "3. Confidence — high/medium/low with a one-sentence reason.",
    "4. Suggested next steps for the parent agent.",
    "",
    "Return only your final report. Do not include raw tool logs or hidden reasoning.",
  ].filter((line): line is string => line !== undefined).join("\n");
}

export function extractFinalAssistantText(messages: Array<{ role?: string; content?: Array<Record<string, any>> }>): string {
  for (let index = messages.length - 1; index >= 0; index--) {
    const message = messages[index];
    if (message?.role !== "assistant" || !Array.isArray(message.content)) continue;

    const text = message.content
      .filter((block) => block?.type === "text" && typeof block.text === "string")
      .map((block) => block.text.trim())
      .filter(Boolean)
      .join("\n");

    if (text) return text;
  }

  return "";
}

export function formatCombinedReport(results: SubagentRunResult[]): string {
  const lines = ["## Subagent Results", ""];

  for (const result of results) {
    const seconds = (result.durationMs / 1000).toFixed(1);
    lines.push(`### ${result.id} (${result.domain}) — ${result.status.toUpperCase()} in ${seconds}s`);
    lines.push("");
    lines.push(`Task: ${result.task}`);
    lines.push("");

    if (result.status === "ok") {
      lines.push(result.output?.trim() || "Subagent completed without a text report.");
    } else {
      lines.push(`Error: ${result.error || "Unknown subagent failure"}`);
    }

    lines.push("");
  }

  return lines.join("\n").trimEnd() + "\n";
}

export function formatSubagentProgressStatus(entries: SubagentProgressEntry[], maxLength = 120): string {
  const summary = formatSubagentProgressSummary(entries);
  const running = entries.filter((entry) => entry.state === "running");
  const queued = entries.filter((entry) => entry.state === "queued");
  const labelEntries = running.length > 0 ? running : queued;
  const labels = labelEntries.map(formatSubagentStatusLabel);
  const labelSuffix = labels.length > 0 ? ` — ${labels.join("; ")}` : "";

  return truncateSingleLine(`subagents: ${summary}${labelSuffix}`, maxLength);
}

export function formatSubagentProgressUpdate(entries: SubagentProgressEntry[]): string {
  const lines = [`Subagents: ${formatSubagentProgressSummary(entries)}`, ""];

  for (const entry of entries) {
    lines.push(`${progressIcon(entry.state)} ${entry.id} (${entry.domain}) — ${compactSingleLine(entry.task)}`);
  }

  return lines.join("\n").trimEnd();
}

function formatSubagentProgressSummary(entries: SubagentProgressEntry[]): string {
  const total = entries.length;
  const running = entries.filter((entry) => entry.state === "running").length;
  const queued = entries.filter((entry) => entry.state === "queued").length;
  const failed = entries.filter((entry) => entry.state === "error").length;
  const completed = entries.filter((entry) => entry.state === "ok" || entry.state === "error").length;
  const parts = [`${completed}/${total} done`];

  if (running > 0) parts.push(countStatus(running, "running"));
  if (queued > 0) parts.push(countStatus(queued, "queued"));
  if (failed > 0) parts.push(countStatus(failed, "failed"));

  return parts.join(", ");
}

function formatSubagentStatusLabel(entry: SubagentProgressEntry): string {
  const task = truncateSingleLine(compactSingleLine(entry.task), 44);
  return `${entry.id}: ${task}`;
}

function progressIcon(state: SubagentProgressState): string {
  switch (state) {
    case "ok":
      return "✓";
    case "error":
      return "✗";
    case "running":
      return "⏳";
    case "queued":
      return "○";
  }
}

function compactSingleLine(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function truncateSingleLine(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  if (maxLength <= 1) return text.slice(0, Math.max(0, maxLength));
  return `${text.slice(0, maxLength - 1).trimEnd()}…`;
}

function countStatus(count: number, label: string): string {
  return `${count} ${label}`;
}

function normalizeTask(raw: RawSubagentTask, index: number): NormalizedSubagentTask {
  const domain = sanitizeDomain(raw.domain);
  const explicitId = stringOrEmpty(raw.id).trim();
  const id = explicitId ? sanitizeId(explicitId, `${domain}-${index + 1}`) : `${domain}-${index + 1}`;
  const contextMode = normalizeContextMode(raw.context_mode);
  const files = Array.isArray(raw.files)
    ? raw.files.map(stringOrEmpty).map((file) => file.trim()).filter(Boolean)
    : [];

  return {
    id,
    domain,
    role: optionalTrimmed(raw.role),
    task: stringOrEmpty(raw.task).trim(),
    contextMode,
    files,
    webSearch: typeof raw.web_search === "boolean" ? raw.web_search : domain === "research",
  };
}

function sanitizeDomain(domain: unknown): string {
  const raw = stringOrEmpty(domain).trim().toLowerCase();
  if (!raw) return "custom";
  return sanitizeId(raw, "custom");
}

function sanitizeId(value: string, fallback: string): string {
  const sanitized = value
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
  return sanitized || fallback;
}

function normalizeContextMode(mode: unknown): SubagentContextMode {
  const value = stringOrEmpty(mode).trim().toLowerCase() as SubagentContextMode;
  return CONTEXT_MODES.has(value) ? value : "brief";
}

function optionalTrimmed(value: unknown): string | undefined {
  const text = stringOrEmpty(value).trim();
  return text || undefined;
}

function stringOrEmpty(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function clampInteger(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  return Math.max(min, Math.min(max, Math.floor(value)));
}
