export const AUTO_MODEL_ROUTER_ENTRY_TYPE = "auto_model_router";

export type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";
export type RouterMode = "auto" | "off" | "locked" | "force";

export interface RouterProfile {
  provider?: string;
  model?: string;
  thinkingLevel?: ThinkingLevel;
  description?: string;
}

export interface RouterRule {
  profile: string;
  patterns: string[];
  reason?: string;
}

export interface RouterConfig {
  enabled: boolean;
  defaultProfile: string;
  lockOnManualModelChange: boolean;
  notifyOnRoute: boolean;
  profiles: Record<string, RouterProfile>;
  rules: RouterRule[];
}

export interface RouteDecision {
  profile: string;
  reason: string;
  mode: RouterMode;
  matchedPattern?: string;
}

export interface RouterState {
  mode: RouterMode;
  forcedProfile?: string;
  profileOverrides?: Record<string, RouterProfile>;
  lastDecision?: RouteDecision;
}

export type RouterCommand =
  | { action: "show" }
  | { action: "status" }
  | { action: "mode"; mode: Exclude<RouterMode, "force"> }
  | { action: "force"; profile: string }
  | { action: "set-current"; profile: string }
  | { action: "reload" }
  | { action: "config" }
  | { action: "help" };

export const DEFAULT_ROUTER_CONFIG: RouterConfig = {
  enabled: true,
  defaultProfile: "fast",
  lockOnManualModelChange: true,
  notifyOnRoute: true,
  profiles: {
    fast: {
      provider: "openai-codex",
      model: "gpt-5.3-codex-spark",
      thinkingLevel: "minimal",
      description: "Fast model for simple edits and implementation from existing instructions.",
    },
    strong: {
      provider: "openai-codex",
      model: "gpt-5.5",
      thinkingLevel: "high",
      description: "Frontier model for planning, architecture, debugging, audits, and large refactors.",
    },
  },
  rules: [
    {
      profile: "strong",
      reason: "planning, architecture, or design keyword",
      patterns: ["\\b(plan|planning|architect|architecture|design|strategy|spec|proposal)\\b"],
    },
    {
      profile: "strong",
      reason: "complex refactor, debugging, audit, migration, or performance keyword",
      patterns: [
        "\\b(refactor|refactoring|rewrite|redesign|migration|migrate|large|complex|hard|deep|debug|investigate|diagnose|audit|security|performance|perf)\\b",
        "\\broot\\s+cause\\b",
        "\\bmulti[- ]?file\\b",
        "\\bcross[- ]?cutting\\b",
        "\\bsystem[- ]?wide\\b",
      ],
    },
  ],
};

export function createDefaultRouterState(config: RouterConfig): RouterState {
  return { mode: config.enabled ? "auto" : "off" };
}

export function decideRoute(prompt: string, config: RouterConfig, state: RouterState): RouteDecision | undefined {
  if (state.mode === "off" || state.mode === "locked") return undefined;

  if (state.mode === "force") {
    const profile = state.forcedProfile;
    if (!profile || !config.profiles[profile]) return undefined;
    return { profile, reason: "forced profile", mode: "force" };
  }

  const normalizedPrompt = prompt.trim();
  for (const rule of config.rules) {
    if (!config.profiles[rule.profile]) continue;

    for (const pattern of rule.patterns) {
      if (matchesPattern(normalizedPrompt, pattern)) {
        return {
          profile: rule.profile,
          reason: `matched ${rule.reason ?? pattern}`,
          matchedPattern: pattern,
          mode: "auto",
        };
      }
    }
  }

  if (!config.profiles[config.defaultProfile]) return undefined;
  return { profile: config.defaultProfile, reason: "default profile", mode: "auto" };
}

export function parseRouterCommand(args: string): RouterCommand {
  const normalized = args.trim().replace(/\s+/g, " ").toLowerCase();
  if (!normalized) return { action: "show" };

  const tokens = normalized.split(" ");
  const [first, second, third] = tokens;

  if (first === "status") return { action: "status" };
  if (first === "help" || first === "?") return { action: "help" };
  if (first === "reload") return { action: "reload" };
  if (first === "config" || first === "paths") return { action: "config" };
  if (first === "auto" || first === "on" || first === "enable" || first === "unlock") return { action: "mode", mode: "auto" };
  if (first === "off" || first === "disable") return { action: "mode", mode: "off" };
  if (first === "lock" || first === "locked" || first === "manual") return { action: "mode", mode: "locked" };

  if ((first === "profile" || first === "force" || first === "use") && second) {
    return { action: "force", profile: second };
  }

  if (first === "set" && second && third === "current") {
    return { action: "set-current", profile: second };
  }

  if (tokens.length === 1) return { action: "force", profile: first };
  return { action: "help" };
}

export function mergeRouterConfig(base: RouterConfig, override: Partial<RouterConfig> | undefined): RouterConfig {
  if (!override || typeof override !== "object") return cloneConfig(base);

  const merged = cloneConfig(base);

  if (typeof override.enabled === "boolean") merged.enabled = override.enabled;
  if (typeof override.defaultProfile === "string" && override.defaultProfile.trim()) {
    merged.defaultProfile = override.defaultProfile.trim();
  }
  if (typeof override.lockOnManualModelChange === "boolean") {
    merged.lockOnManualModelChange = override.lockOnManualModelChange;
  }
  if (typeof override.notifyOnRoute === "boolean") merged.notifyOnRoute = override.notifyOnRoute;

  if (override.profiles && typeof override.profiles === "object" && !Array.isArray(override.profiles)) {
    for (const [name, rawProfile] of Object.entries(override.profiles)) {
      if (!name.trim() || !isObject(rawProfile)) continue;
      merged.profiles[name] = {
        ...(merged.profiles[name] ?? {}),
        ...normalizeProfile(rawProfile),
      };
    }
  }

  if (Array.isArray(override.rules)) {
    const rules = override.rules.map(normalizeRule).filter((rule): rule is RouterRule => rule !== undefined);
    merged.rules = rules;
  }

  return merged;
}

export function resolveEffectiveConfig(config: RouterConfig, state: RouterState): RouterConfig {
  const effective = cloneConfig(config);

  if (state.profileOverrides) {
    for (const [name, profile] of Object.entries(state.profileOverrides)) {
      effective.profiles[name] = {
        ...(effective.profiles[name] ?? {}),
        ...normalizeProfile(profile),
      };
    }
  }

  return effective;
}

export function reconstructRouterState(entries: Array<Record<string, any>>, config: RouterConfig): RouterState {
  let state = createDefaultRouterState(config);

  for (const entry of entries) {
    if (entry?.type !== "custom" || entry.customType !== AUTO_MODEL_ROUTER_ENTRY_TYPE) continue;
    const data = entry.data;
    if (!isObject(data)) continue;

    const nextMode = normalizeMode(data.mode);
    if (!nextMode) continue;

    state = { mode: nextMode };

    if (nextMode === "force" && typeof data.forcedProfile === "string" && data.forcedProfile.trim()) {
      state.forcedProfile = data.forcedProfile.trim();
    }

    if (isObject(data.profileOverrides)) {
      state.profileOverrides = normalizeProfileOverrides(data.profileOverrides);
    }
  }

  return state;
}

export function serializeRouterState(state: RouterState): Record<string, any> {
  return {
    mode: state.mode,
    forcedProfile: state.forcedProfile,
    profileOverrides: state.profileOverrides,
  };
}

export function buildRouterStatus(state: RouterState, config: RouterConfig, maxLength = 120): string {
  let text: string;

  if (state.mode === "off") {
    text = "router: off";
  } else if (state.mode === "locked") {
    text = "router: locked";
  } else if (state.mode === "force") {
    text = `router: force→${state.forcedProfile ?? config.defaultProfile}`;
  } else {
    const profile = state.lastDecision?.profile ?? config.defaultProfile;
    const reason = state.lastDecision?.reason;
    text = `router: auto→${profile}${reason ? ` — ${reason}` : ""}`;
  }

  return truncateSingleLine(text, maxLength);
}

export function buildRouterDetails(
  state: RouterState,
  config: RouterConfig,
  configPaths: string[] = [],
): string {
  const lines = [buildRouterStatus(state, config, 200), "", "Profiles:"];

  for (const [name, profile] of Object.entries(config.profiles)) {
    const model = profile.provider && profile.model ? `${profile.provider}/${profile.model}` : "(current model)";
    const thinking = profile.thinkingLevel ? ` thinking:${profile.thinkingLevel}` : "";
    const marker = name === config.defaultProfile ? " default" : "";
    lines.push(`- ${name}:${marker} ${model}${thinking}`.replace(/:\s+default/, ": default"));
  }

  if (state.profileOverrides && Object.keys(state.profileOverrides).length > 0) {
    lines.push("", "Session profile overrides:");
    for (const [name, profile] of Object.entries(state.profileOverrides)) {
      const model = profile.provider && profile.model ? `${profile.provider}/${profile.model}` : "(current model)";
      const thinking = profile.thinkingLevel ? ` thinking:${profile.thinkingLevel}` : "";
      lines.push(`- ${name}: ${model}${thinking}`);
    }
  }

  if (state.lastDecision) {
    lines.push("", `Last route: ${state.lastDecision.profile} (${state.lastDecision.reason})`);
  }

  if (configPaths.length > 0) {
    lines.push("", "Config files:", ...configPaths.map((path) => `- ${path}`));
  }

  return lines.join("\n");
}

export function buildRouterConfigHelp(configPaths: string[]): string {
  return [
    "Auto model router config files, loaded in order:",
    ...configPaths.map((path) => `- ${path}`),
    "",
    "Example auto-model-router.json:",
    JSON.stringify(
      {
        enabled: true,
        defaultProfile: "fast",
        lockOnManualModelChange: true,
        notifyOnRoute: true,
        profiles: {
          fast: { provider: "openai-codex", model: "gpt-5.3-codex-spark", thinkingLevel: "minimal" },
          strong: { provider: "openai-codex", model: "gpt-5.5", thinkingLevel: "high" },
        },
        rules: [
          { profile: "strong", patterns: ["\\b(plan|architecture|debug|refactor|complex)\\b"], reason: "hard task" },
        ],
      },
      null,
      2,
    ),
  ].join("\n");
}

export function truncateSingleLine(text: string, maxLength: number): string {
  const compact = text.replace(/\s+/g, " ").trim();
  if (compact.length <= maxLength) return compact;
  if (maxLength <= 1) return compact.slice(0, Math.max(0, maxLength));
  return `${compact.slice(0, maxLength - 1).trimEnd()}…`;
}

function matchesPattern(prompt: string, pattern: string): boolean {
  try {
    return new RegExp(pattern, "i").test(prompt);
  } catch {
    return false;
  }
}

function cloneConfig(config: RouterConfig): RouterConfig {
  return {
    ...config,
    profiles: Object.fromEntries(Object.entries(config.profiles).map(([name, profile]) => [name, { ...profile }])),
    rules: config.rules.map((rule) => ({ ...rule, patterns: [...rule.patterns] })),
  };
}

function normalizeProfile(raw: Record<string, any>): RouterProfile {
  const profile: RouterProfile = {};

  if (typeof raw.provider === "string" && raw.provider.trim()) profile.provider = raw.provider.trim();
  if (typeof raw.model === "string" && raw.model.trim()) profile.model = raw.model.trim();
  if (isThinkingLevel(raw.thinkingLevel)) profile.thinkingLevel = raw.thinkingLevel;
  if (typeof raw.description === "string" && raw.description.trim()) profile.description = raw.description.trim();

  return profile;
}

function normalizeRule(raw: any): RouterRule | undefined {
  if (!isObject(raw)) return undefined;
  if (typeof raw.profile !== "string" || !raw.profile.trim()) return undefined;
  if (!Array.isArray(raw.patterns)) return undefined;

  const patterns = raw.patterns.filter((pattern): pattern is string => typeof pattern === "string" && pattern.trim());
  if (patterns.length === 0) return undefined;

  return {
    profile: raw.profile.trim(),
    patterns,
    reason: typeof raw.reason === "string" && raw.reason.trim() ? raw.reason.trim() : undefined,
  };
}

function normalizeProfileOverrides(raw: Record<string, any>): Record<string, RouterProfile> | undefined {
  const overrides: Record<string, RouterProfile> = {};

  for (const [name, profile] of Object.entries(raw)) {
    if (!name.trim() || !isObject(profile)) continue;
    const normalized = normalizeProfile(profile);
    if (Object.keys(normalized).length > 0) overrides[name] = normalized;
  }

  return Object.keys(overrides).length > 0 ? overrides : undefined;
}

function normalizeMode(value: unknown): RouterMode | undefined {
  if (value === "auto" || value === "off" || value === "locked" || value === "force") return value;
  return undefined;
}

function isThinkingLevel(value: unknown): value is ThinkingLevel {
  return value === "off" || value === "minimal" || value === "low" || value === "medium" || value === "high" || value === "xhigh";
}

function isObject(value: unknown): value is Record<string, any> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
