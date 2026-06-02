/**
 * Claude Code-like assistant Insight card for pi.
 *
 * Loaded globally by Home Manager at ~/.pi/agent/extensions/assistant-insight/index.ts.
 * This intentionally patches pi's interactive AssistantMessageComponent so the
 * assistant's first text paragraph is shown as a TUI-only Insight card without
 * changing the saved assistant message or model context.
 */

// @ts-nocheck
// Home Manager replaces @PI_NODE_MODULES@ with pkgs.pi-coding-agent's bundled
// node_modules path, so this extension does not need globally installed node
// packages or a project-local npm install.
import { AssistantMessageComponent } from "@PI_NODE_MODULES@/@earendil-works/pi-coding-agent/dist/modes/interactive/components/assistant-message.js";
import { getMarkdownTheme, theme } from "@PI_NODE_MODULES@/@earendil-works/pi-coding-agent/dist/modes/interactive/theme/theme.js";
import { Box, Markdown, Spacer, Text } from "@PI_NODE_MODULES@/@earendil-works/pi-tui/dist/index.js";

import { patchAssistantMessageComponent } from "@PI_ASSISTANT_INSIGHT_CORE@";

function createInsightCard(insight: string) {
  const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
  const label = theme.fg("customMessageLabel", theme.bold("✻ Insight"));

  box.addChild(new Text(label, 0, 0));
  box.addChild(new Spacer(1));
  box.addChild(
    new Markdown(insight, 0, 0, getMarkdownTheme(), {
      color: (text) => theme.fg("customMessageText", text),
    }),
  );

  return box;
}

export default function assistantInsight() {
  patchAssistantMessageComponent(AssistantMessageComponent, {
    createInsightCard,
    Spacer,
  });
}
