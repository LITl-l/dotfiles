export const GOAL_CUSTOM_ENTRY_TYPE = "goal";
export const GOAL_PROMPT_MAX_LENGTH = 1000;

export type GoalCommand =
  | { action: "show" }
  | { action: "clear" }
  | { action: "set"; goal: string };

export type GoalEntryData =
  | { action: "set"; goal: string; timestamp?: number }
  | { action: "clear"; timestamp?: number };

export function parseGoalCommand(args: string): GoalCommand {
  const normalized = args.trim().replace(/\s+/g, " ");

  if (!normalized) return { action: "show" };
  if (normalized === "clear" || normalized === "reset") return { action: "clear" };

  return { action: "set", goal: normalized };
}

export function reconstructGoalFromEntries(entries: Array<Record<string, any>>): string | undefined {
  let goal: string | undefined;

  for (const entry of entries) {
    if (entry?.type !== "custom" || entry.customType !== GOAL_CUSTOM_ENTRY_TYPE) continue;

    const data = entry.data as GoalEntryData | undefined;
    if (data?.action === "clear") {
      goal = undefined;
      continue;
    }

    if (data?.action === "set" && typeof data.goal === "string" && data.goal.trim()) {
      goal = data.goal.trim();
    }
  }

  return goal;
}

export function truncateGoalForStatus(goal: string, maxLength = 48): string {
  if (goal.length <= maxLength) return goal;
  if (maxLength <= 3) return ".".repeat(Math.max(0, maxLength));
  return `${goal.slice(0, maxLength - 3)}...`;
}

export function buildGoalPromptSection(goal: string | undefined, maxLength = GOAL_PROMPT_MAX_LENGTH): string | undefined {
  if (!goal?.trim()) return undefined;

  return [
    "",
    "",
    "Current session goal:",
    truncateGoalForStatus(goal.trim(), maxLength),
    "",
    "Use this goal to stay oriented. If the user's latest request conflicts with it, follow the latest user request and mention the mismatch.",
  ].join("\n");
}
