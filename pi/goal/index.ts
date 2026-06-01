/**
 * Session-scoped goal command for pi.
 *
 * Loaded globally by Home Manager at ~/.pi/agent/extensions/goal/index.ts.
 */

// @ts-nocheck
import {
  GOAL_CUSTOM_ENTRY_TYPE,
  buildGoalPromptSection,
  parseGoalCommand,
  reconstructGoalFromEntries,
  truncateGoalForStatus,
} from "./core.ts";

const STATUS_KEY = "goal";

export default function (pi) {
  let currentGoal;

  function setStatus(ctx) {
    if (!ctx.hasUI) return;

    if (currentGoal) {
      ctx.ui.setStatus(STATUS_KEY, `goal: ${truncateGoalForStatus(currentGoal)}`);
    } else {
      ctx.ui.setStatus(STATUS_KEY, undefined);
    }
  }

  function refreshGoal(ctx) {
    currentGoal = reconstructGoalFromEntries(ctx.sessionManager.getBranch());
    setStatus(ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    refreshGoal(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    refreshGoal(ctx);
  });

  pi.on("before_agent_start", async (event) => {
    const section = buildGoalPromptSection(currentGoal);
    if (!section) return;

    return { systemPrompt: event.systemPrompt + section };
  });

  pi.registerCommand("goal", {
    description: "Set, show, or clear the current session goal",
    getArgumentCompletions: (prefix) => {
      const commands = ["clear", "reset"];
      const filtered = commands.filter((command) => command.startsWith(prefix));
      return filtered.length > 0 ? filtered.map((command) => ({ value: command, label: command })) : null;
    },
    handler: async (args, ctx) => {
      const command = parseGoalCommand(args);

      if (command.action === "show") {
        ctx.ui.notify(currentGoal ? `Current goal: ${currentGoal}` : "No session goal set", "info");
        return;
      }

      if (command.action === "clear") {
        currentGoal = undefined;
        pi.appendEntry(GOAL_CUSTOM_ENTRY_TYPE, { action: "clear", timestamp: Date.now() });
        setStatus(ctx);
        ctx.ui.notify("Session goal cleared", "info");
        return;
      }

      currentGoal = command.goal;
      pi.appendEntry(GOAL_CUSTOM_ENTRY_TYPE, {
        action: "set",
        goal: currentGoal,
        timestamp: Date.now(),
      });
      setStatus(ctx);
      ctx.ui.notify(`Session goal set: ${currentGoal}`, "info");
    },
  });
}
