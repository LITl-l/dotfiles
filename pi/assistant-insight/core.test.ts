import test from "node:test";
import assert from "node:assert/strict";

import { patchAssistantMessageComponent, splitAssistantInsightMessage } from "./core.ts";

test("extracts the first assistant paragraph into insight and removes it from TUI display text", () => {
  const message = {
    role: "assistant",
    content: [
      {
        type: "text",
        text: "I found the root cause in the Pi renderer.\n\nThe fix is to patch AssistantMessageComponent.\n\nThis leaves the saved message unchanged.",
      },
    ],
  };

  const result = splitAssistantInsightMessage(message);

  assert.equal(result.insight, "I found the root cause in the Pi renderer.");
  assert.deepEqual(result.displayMessage.content, [
    {
      type: "text",
      text: "The fix is to patch AssistantMessageComponent.\n\nThis leaves the saved message unchanged.",
    },
  ]);
  assert.equal(message.content[0].text, "I found the root cause in the Pi renderer.\n\nThe fix is to patch AssistantMessageComponent.\n\nThis leaves the saved message unchanged.");
});

test("removes the first text block when the assistant response is a single paragraph", () => {
  const message = {
    role: "assistant",
    content: [
      { type: "thinking", thinking: "internal trace" },
      { type: "text", text: "All set — the TUI card is installed." },
      { type: "toolCall", name: "read", id: "call-1", input: {} },
    ],
  };

  const result = splitAssistantInsightMessage(message);

  assert.equal(result.insight, "All set — the TUI card is installed.");
  assert.deepEqual(result.displayMessage.content, [
    { type: "thinking", thinking: "internal trace" },
    { type: "toolCall", name: "read", id: "call-1", input: {} },
  ]);
});

test("skips empty text blocks and leaves messages without text unchanged", () => {
  const textMessage = {
    role: "assistant",
    content: [
      { type: "text", text: "  \n\n" },
      { type: "text", text: "First useful paragraph.\n\nMore detail." },
    ],
  };

  assert.deepEqual(splitAssistantInsightMessage(textMessage), {
    insight: "First useful paragraph.",
    displayMessage: {
      role: "assistant",
      content: [
        { type: "text", text: "  \n\n" },
        { type: "text", text: "More detail." },
      ],
    },
  });

  const toolOnlyMessage = { role: "assistant", content: [{ type: "toolCall", name: "bash" }] };
  const toolOnlyResult = splitAssistantInsightMessage(toolOnlyMessage);

  assert.equal(toolOnlyResult.insight, undefined);
  assert.equal(toolOnlyResult.displayMessage, toolOnlyMessage);
});

test("patches AssistantMessageComponent to insert one insight card before remaining response text", () => {
  class FakeSpacer {
    lines: number;

    constructor(lines: number) {
      this.lines = lines;
    }
  }

  class FakeAssistantMessageComponent {
    contentContainer = { children: [] as unknown[] };
    lastMessage?: unknown;

    updateContent(message: any) {
      this.lastMessage = message;
      this.contentContainer.children = message.content.length > 0 ? [new FakeSpacer(1), { kind: "markdown", content: message.content }] : [];
    }
  }

  assert.equal(
    patchAssistantMessageComponent(FakeAssistantMessageComponent, {
      createInsightCard: (insight) => ({ kind: "insight-card", insight }),
      Spacer: FakeSpacer,
    }),
    true,
  );
  assert.equal(
    patchAssistantMessageComponent(FakeAssistantMessageComponent, {
      createInsightCard: (insight) => ({ kind: "duplicate-card", insight }),
      Spacer: FakeSpacer,
    }),
    false,
  );

  const originalMessage = {
    role: "assistant",
    content: [{ type: "text", text: "Useful insight.\n\nRemaining response." }],
  };
  const component = new FakeAssistantMessageComponent();

  component.updateContent(originalMessage);

  assert.equal(component.lastMessage, originalMessage);
  assert.deepEqual(component.contentContainer.children, [
    new FakeSpacer(1),
    { kind: "insight-card", insight: "Useful insight." },
    new FakeSpacer(1),
    { kind: "markdown", content: [{ type: "text", text: "Remaining response." }] },
  ]);
});
