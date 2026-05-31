/**
 * Claude Code-like Vim modal input for pi.
 *
 * Loaded globally by Home Manager at ~/.pi/agent/extensions/claude-vim.ts.
 * Keep this dependency-free except for pi's public extension/TUI APIs.
 */

// @ts-nocheck
// Home Manager replaces @PI_NODE_MODULES@ with pkgs.pi-coding-agent's bundled
// node_modules path, so this extension does not need globally installed node
// packages or a project-local npm install.
import { CustomEditor } from "@PI_NODE_MODULES@/@earendil-works/pi-coding-agent/index.js";
import { matchesKey, truncateToWidth, visibleWidth } from "@PI_NODE_MODULES@/@earendil-works/pi-tui/index.js";

const key = {
  left: "\x1b[D",
  right: "\x1b[C",
  up: "\x1b[A",
  down: "\x1b[B",
  home: "\x01", // Ctrl-A
  end: "\x05", // Ctrl-E
  deleteForward: "\x1b[3~",
  deleteBackward: "\x7f",
  deleteWordForward: "\x1bd", // Alt-D
  wordLeft: "\x1bb", // Alt-B
  wordRight: "\x1bf", // Alt-F
  deleteToLineEnd: "\x0b", // Ctrl-K
  deleteToLineStart: "\x15", // Ctrl-U
  undo: "\x1f", // Ctrl-_ / Ctrl-- in many terminals
};

class ClaudeVimEditor extends CustomEditor {
  private mode: "insert" | "normal" = "insert";
  private pending: "d" | "c" | "g" | null = null;

  handleInput(data: string): void {
    if (matchesKey(data, "escape")) {
      if (this.mode === "insert") {
        this.mode = "normal";
        this.pending = null;
        this.invalidate();
        return;
      }

      if (this.pending) {
        this.pending = null;
        this.invalidate();
        return;
      }

      super.handleInput(data);
      return;
    }

    if (this.mode === "insert") {
      super.handleInput(data);
      return;
    }

    if (this.handlePending(data)) return;

    switch (data) {
      case "h":
        super.handleInput(key.left);
        return;
      case "j":
        super.handleInput(key.down);
        return;
      case "k":
        super.handleInput(key.up);
        return;
      case "l":
        super.handleInput(key.right);
        return;
      case "0":
      case "^":
        super.handleInput(key.home);
        return;
      case "$":
        super.handleInput(key.end);
        return;
      case "w":
      case "e":
        super.handleInput(key.wordRight);
        return;
      case "b":
        super.handleInput(key.wordLeft);
        return;
      case "x":
        super.handleInput(key.deleteForward);
        return;
      case "X":
        super.handleInput(key.deleteBackward);
        return;
      case "D":
        super.handleInput(key.deleteToLineEnd);
        return;
      case "C":
        super.handleInput(key.deleteToLineEnd);
        this.enterInsert();
        return;
      case "i":
        this.enterInsert();
        return;
      case "a":
        super.handleInput(key.right);
        this.enterInsert();
        return;
      case "I":
        super.handleInput(key.home);
        this.enterInsert();
        return;
      case "A":
        super.handleInput(key.end);
        this.enterInsert();
        return;
      case "o":
        super.handleInput(key.end);
        this.insertTextAtCursor("\n");
        this.enterInsert();
        return;
      case "O":
        super.handleInput(key.home);
        this.insertTextAtCursor("\n");
        super.handleInput(key.up);
        this.enterInsert();
        return;
      case "u":
        super.handleInput(key.undo);
        return;
      case "d":
      case "c":
      case "g":
        this.pending = data;
        this.invalidate();
        return;
      default:
        // Let app/editor shortcuts through, but do not insert printable chars in normal mode.
        if (data.length === 1 && data.charCodeAt(0) >= 32) return;
        super.handleInput(data);
    }
  }

  render(width: number): string[] {
    const lines = super.render(width);
    if (lines.length === 0) return lines;

    const label = this.mode === "normal"
      ? this.pending ? ` ${this.pending}… NORMAL ` : " NORMAL "
      : " INSERT ";
    const last = lines.length - 1;

    if (visibleWidth(lines[last]!) >= label.length) {
      lines[last] = truncateToWidth(lines[last]!, width - label.length, "") + label;
    }

    return lines;
  }

  private handlePending(data: string): boolean {
    if (!this.pending) return false;

    const pending = this.pending;
    this.pending = null;
    this.invalidate();

    if (pending === "g") {
      if (data === "g") {
        // Best available approximation: line start. pi's editor has no public buffer-top action.
        super.handleInput(key.home);
      }
      return true;
    }

    if (pending === "d") {
      switch (data) {
        case "d":
          this.deleteCurrentLine();
          return true;
        case "w":
        case "e":
          super.handleInput(key.deleteWordForward);
          return true;
        case "$":
          super.handleInput(key.deleteToLineEnd);
          return true;
        default:
          return true;
      }
    }

    if (pending === "c") {
      switch (data) {
        case "c":
          this.deleteCurrentLine();
          this.enterInsert();
          return true;
        case "w":
        case "e":
          super.handleInput(key.deleteWordForward);
          this.enterInsert();
          return true;
        case "$":
          super.handleInput(key.deleteToLineEnd);
          this.enterInsert();
          return true;
        default:
          return true;
      }
    }

    return false;
  }

  private deleteCurrentLine(): void {
    super.handleInput(key.home);
    super.handleInput(key.deleteToLineEnd);
    super.handleInput(key.deleteForward);
  }

  private enterInsert(): void {
    this.mode = "insert";
    this.pending = null;
    this.invalidate();
  }
}

export default function (pi) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setEditorComponent((tui, theme, keybindings) =>
      new ClaudeVimEditor(tui, theme, keybindings)
    );
  });
}
