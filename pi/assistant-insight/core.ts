type MessageWithContent = {
  content?: Array<Record<string, any>>;
};

type ParagraphSplit = {
  paragraph: string;
  remainder: string;
};

type AssistantMessageComponentClass = {
  prototype?: {
    updateContent?: (message: any) => void;
    [key: symbol]: unknown;
  };
};

type PatchDeps = {
  createInsightCard: (insight: string) => unknown;
  Spacer: new (lines: number) => unknown;
};

const PATCH_MARK = Symbol.for("dotfiles.pi.assistant-insight.patched");

function splitFirstParagraph(text: string): ParagraphSplit | undefined {
  const body = text.trimStart();
  if (!body.trim()) return undefined;

  const separator = /\n[ \t]*\n/.exec(body);
  if (!separator) {
    return { paragraph: body.trim(), remainder: "" };
  }

  const paragraph = body.slice(0, separator.index).trim();
  if (!paragraph) return undefined;

  return {
    paragraph,
    remainder: body.slice(separator.index + separator[0].length).trimStart(),
  };
}

export function patchAssistantMessageComponent(AssistantMessageComponent: AssistantMessageComponentClass, deps: PatchDeps): boolean {
  const proto = AssistantMessageComponent?.prototype;
  if (!proto || typeof proto.updateContent !== "function" || proto[PATCH_MARK]) return false;

  const originalUpdateContent = proto.updateContent;
  proto[PATCH_MARK] = true;

  proto.updateContent = function patchedUpdateContent(this: any, message: any): void {
    const { insight, displayMessage } = splitAssistantInsightMessage(message);

    originalUpdateContent.call(this, displayMessage);
    this.lastMessage = message;

    if (!insight) return;

    const container = this.contentContainer;
    if (!container || !Array.isArray(container.children)) return;

    if (!(container.children[0] instanceof deps.Spacer)) {
      container.children.unshift(new deps.Spacer(1));
    }

    const insertAt = 1;
    container.children.splice(insertAt, 0, deps.createInsightCard(insight));

    if (container.children.length > insertAt + 1) {
      container.children.splice(insertAt + 1, 0, new deps.Spacer(1));
    }
  };

  return true;
}

export function splitAssistantInsightMessage<T extends MessageWithContent>(message: T): {
  insight?: string;
  displayMessage: T;
} {
  if (!Array.isArray(message.content)) return { displayMessage: message };

  for (let index = 0; index < message.content.length; index++) {
    const part = message.content[index];
    if (part?.type !== "text" || typeof part.text !== "string") continue;

    const split = splitFirstParagraph(part.text);
    if (!split) continue;

    const content = [...message.content];
    if (split.remainder.trim()) {
      content[index] = { ...part, text: split.remainder };
    } else {
      content.splice(index, 1);
    }

    return {
      insight: split.paragraph,
      displayMessage: { ...message, content } as T,
    };
  }

  return { displayMessage: message };
}
