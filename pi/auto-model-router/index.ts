// @ts-nocheck
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import {
  AUTO_MODEL_ROUTER_ENTRY_TYPE,
  DEFAULT_ROUTER_CONFIG,
  buildRouterConfigHelp,
  buildRouterDetails,
  buildRouterStatus,
  createDefaultRouterState,
  decideRoute,
  mergeRouterConfig,
  parseRouterCommand,
  reconstructRouterState,
  resolveEffectiveConfig,
  serializeRouterState,
} from "./core.ts";

const STATUS_KEY = "auto-model-router";
const CONFIG_FILE = "auto-model-router.json";

export default function autoModelRouterExtension(pi) {
  let config = DEFAULT_ROUTER_CONFIG;
  let configPaths = [];
  let state = createDefaultRouterState(config);
  let routerModelChange;

  function getEffectiveConfig() {
    return resolveEffectiveConfig(config, state);
  }

  function persistState() {
    pi.appendEntry(AUTO_MODEL_ROUTER_ENTRY_TYPE, serializeRouterState(state));
  }

  function updateStatus(ctx) {
    if (!ctx.hasUI) return;
    ctx.ui.setStatus(STATUS_KEY, buildRouterStatus(state, getEffectiveConfig()));
  }

  function notify(ctx, message, level = "info") {
    if (ctx.hasUI) ctx.ui.notify(message, level);
  }

  function reloadConfig(ctx) {
    const loaded = loadRouterConfig(ctx.cwd, (message) => notify(ctx, message, "warning"));
    config = loaded.config;
    configPaths = loaded.paths;

    if (state.mode === undefined) {
      state = createDefaultRouterState(config);
    }
  }

  async function applyProfile(profileName, reason, ctx) {
    const effective = getEffectiveConfig();
    const profile = effective.profiles[profileName];

    if (!profile) {
      notify(ctx, `Auto model router profile not found: ${profileName}`, "warning");
      updateStatus(ctx);
      return false;
    }

    let changed = false;
    let modelApplied = false;
    const hasConfiguredModel = Boolean(profile.provider && profile.model);

    if (hasConfiguredModel) {
      const model = ctx.modelRegistry.find(profile.provider, profile.model);
      if (!model) {
        notify(ctx, `Auto model router model not found: ${profile.provider}/${profile.model}`, "warning");
        updateStatus(ctx);
        return false;
      }

      if (modelKey(ctx.model) !== modelKey(model)) {
        routerModelChange = { key: modelKey(model), timestamp: Date.now() };
        const success = await pi.setModel(model);
        if (!success) {
          notify(ctx, `Auto model router cannot use ${profile.provider}/${profile.model}: no configured auth`, "warning");
          updateStatus(ctx);
          return false;
        }
        changed = true;
      }
      modelApplied = true;
    }

    if ((!hasConfiguredModel || modelApplied) && profile.thinkingLevel && pi.getThinkingLevel() !== profile.thinkingLevel) {
      pi.setThinkingLevel(profile.thinkingLevel);
      changed = true;
    }

    if (changed && config.notifyOnRoute) {
      notify(ctx, `Auto model router: ${profileName} (${reason})`, "info");
    }

    updateStatus(ctx);
    return true;
  }

  async function applyDecision(decision, ctx) {
    state = { ...state, lastDecision: decision };
    updateStatus(ctx);
    return applyProfile(decision.profile, decision.reason, ctx);
  }

  async function setMode(mode, ctx) {
    state = {
      ...state,
      mode,
      forcedProfile: undefined,
      lastDecision: undefined,
    };
    persistState();
    updateStatus(ctx);
    notify(ctx, `Auto model router mode: ${mode}`, "info");
  }

  async function forceProfile(profileName, ctx) {
    const effective = getEffectiveConfig();
    if (!effective.profiles[profileName]) {
      notify(ctx, `Unknown auto model router profile: ${profileName}`, "warning");
      return;
    }

    state = {
      ...state,
      mode: "force",
      forcedProfile: profileName,
      lastDecision: { profile: profileName, reason: "forced profile", mode: "force" },
    };
    persistState();
    await applyProfile(profileName, "forced profile", ctx);
  }

  function setProfileToCurrent(profileName, ctx) {
    if (!ctx.model) {
      notify(ctx, "Cannot set router profile: no current model selected", "warning");
      return;
    }

    state = {
      ...state,
      profileOverrides: {
        ...(state.profileOverrides ?? {}),
        [profileName]: {
          provider: ctx.model.provider,
          model: ctx.model.id,
          thinkingLevel: pi.getThinkingLevel(),
        },
      },
    };

    persistState();
    updateStatus(ctx);
    notify(ctx, `Auto model router profile "${profileName}" set to ${ctx.model.provider}/${ctx.model.id} with thinking:${pi.getThinkingLevel()} for this session`, "info");
  }

  async function showSelector(ctx) {
    const effective = getEffectiveConfig();
    const profileNames = Object.keys(effective.profiles).sort();
    const choices = [
      "status",
      "auto",
      "off",
      "lock",
      ...profileNames.map((profile) => `profile ${profile}`),
      ...profileNames.map((profile) => `set ${profile} current`),
      "reload",
      "config",
    ];

    const selected = await ctx.ui.select("Auto model router", choices);
    if (!selected) return;
    await handleRouterCommand(selected, ctx);
  }

  async function handleRouterCommand(args, ctx) {
    const command = parseRouterCommand(args);

    if (command.action === "show") {
      if (ctx.hasUI) await showSelector(ctx);
      else notify(ctx, buildRouterDetails(state, getEffectiveConfig(), configPaths), "info");
      return;
    }

    if (command.action === "status") {
      notify(ctx, buildRouterDetails(state, getEffectiveConfig(), configPaths), "info");
      return;
    }

    if (command.action === "mode") {
      await setMode(command.mode, ctx);
      return;
    }

    if (command.action === "force") {
      await forceProfile(command.profile, ctx);
      return;
    }

    if (command.action === "set-current") {
      setProfileToCurrent(command.profile, ctx);
      return;
    }

    if (command.action === "reload") {
      reloadConfig(ctx);
      updateStatus(ctx);
      notify(ctx, "Auto model router config reloaded", "info");
      return;
    }

    if (command.action === "config") {
      notify(ctx, buildRouterConfigHelp(configPaths.length > 0 ? configPaths : getConfigPaths(ctx.cwd)), "info");
      return;
    }

    notify(ctx, buildRouterHelp(), "info");
  }

  pi.registerFlag("router", {
    description: "Auto model router mode/profile (auto, off, lock, fast, strong)",
    type: "string",
  });

  pi.registerCommand("router", {
    description: "Configure automatic task-scale model routing",
    getArgumentCompletions: (prefix) => {
      const effective = getEffectiveConfig();
      const builtins = ["status", "auto", "off", "lock", "unlock", "reload", "config", "help"];
      const profileCommands = Object.keys(effective.profiles).flatMap((profile) => [profile, `profile ${profile}`, `set ${profile} current`]);
      const items = [...builtins, ...profileCommands]
        .filter((value) => value.startsWith(prefix))
        .map((value) => ({ value, label: value }));
      return items.length > 0 ? items : null;
    },
    handler: async (args, ctx) => {
      await handleRouterCommand(args, ctx);
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    reloadConfig(ctx);
    state = reconstructRouterState(ctx.sessionManager.getBranch(), config);

    const routerFlag = pi.getFlag("router");
    if (typeof routerFlag === "string" && routerFlag.trim()) {
      await handleRouterCommand(routerFlag, ctx);
    }

    updateStatus(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    state = reconstructRouterState(ctx.sessionManager.getBranch(), config);
    updateStatus(ctx);
  });

  pi.on("before_agent_start", async (event, ctx) => {
    const effective = getEffectiveConfig();
    let decision = decideRoute(event.prompt ?? "", effective, state);
    if (!decision) {
      updateStatus(ctx);
      return;
    }

    if (hasImages(event) && !isProfileImageCapable(decision.profile, effective, ctx)) {
      const imageProfile = findImageCapableProfile(effective, ctx);
      if (!imageProfile) {
        notify(ctx, "Auto model router skipped image prompt: no configured image-capable profile found", "warning");
        updateStatus(ctx);
        return;
      }

      decision = {
        ...decision,
        profile: imageProfile,
        reason: "image input requires image-capable model",
        matchedPattern: undefined,
      };
    }

    await applyDecision(decision, ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    if (!config.lockOnManualModelChange) return;
    if (event.source === "restore") return;
    if (state.mode === "off" || state.mode === "locked") return;

    const selectedKey = modelKey(event.model);
    if (routerModelChange && routerModelChange.key === selectedKey && Date.now() - routerModelChange.timestamp < 2000) {
      return;
    }

    state = {
      ...state,
      mode: "locked",
      forcedProfile: undefined,
      lastDecision: undefined,
    };
    persistState();
    updateStatus(ctx);
    notify(ctx, "Auto model router locked after manual model change. Use /router auto to re-enable.", "info");
  });
}

function hasImages(event) {
  return Array.isArray(event.images) && event.images.length > 0;
}

function findImageCapableProfile(config, ctx) {
  const orderedProfiles = unique(["strong", config.defaultProfile, ...Object.keys(config.profiles)]);
  return orderedProfiles.find((profileName) => isProfileImageCapable(profileName, config, ctx));
}

function isProfileImageCapable(profileName, config, ctx) {
  const profile = config.profiles[profileName];
  if (!profile) return false;

  if (!profile.provider || !profile.model) {
    return modelSupportsImage(ctx.model);
  }

  const model = ctx.modelRegistry.find(profile.provider, profile.model);
  return modelSupportsImage(model);
}

function modelSupportsImage(model) {
  return Array.isArray(model?.input) && model.input.includes("image");
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function loadRouterConfig(cwd, onWarning) {
  const paths = getConfigPaths(cwd);
  let config = DEFAULT_ROUTER_CONFIG;

  for (const path of paths) {
    if (!existsSync(path)) continue;

    try {
      const parsed = JSON.parse(readFileSync(path, "utf8"));
      config = mergeRouterConfig(config, parsed);
    } catch (error) {
      onWarning?.(`Failed to load auto model router config ${path}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  return { config, paths };
}

function getConfigPaths(cwd) {
  return [join(getAgentDir(), CONFIG_FILE), join(cwd, ".pi", CONFIG_FILE)];
}

function getAgentDir() {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
}

function modelKey(model) {
  if (!model) return undefined;
  return `${model.provider}/${model.id}`;
}

function buildRouterHelp() {
  return [
    "Auto model router commands:",
    "- /router: interactive selector",
    "- /router status: show current mode and profiles",
    "- /router auto|off|lock|unlock: change mode",
    "- /router fast or /router strong: force a profile",
    "- /router set <profile> current: set a profile to the current model/thinking for this session",
    "- /router reload: reload config files",
    "- /router config: show config paths and example",
  ].join("\n");
}
