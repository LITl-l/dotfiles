{ pkgs, ... }:

{
  # Pi coding-agent compatibility defaults for users migrating from Claude Code.
  # The extension imports pi's bundled libraries by absolute Nix store path, so it
  # does not depend on globally installed node packages or a local node_modules.
  home.file.".pi/agent/extensions/claude-vim.ts".text = builtins.replaceStrings
    [ "@PI_NODE_MODULES@" ]
    [ "${pkgs.pi-coding-agent}/lib/node_modules" ]
    (builtins.readFile ../pi/claude-vim.ts);
  home.file.".pi/agent/extensions/agent-compat.ts".source = ../pi/agent-compat.ts;
  home.file.".pi/agent/extensions/subagents/index.ts".text = builtins.replaceStrings
    [ "@PI_NODE_MODULES@" "@PI_SUBAGENTS_CORE@" ]
    [ "${pkgs.pi-coding-agent}/lib/node_modules" "${../pi/subagents/core.ts}" ]
    (builtins.readFile ../pi/subagents/index.ts);
  home.file.".pi/agent/extensions/subagents/core.ts".source = ../pi/subagents/core.ts;

  # Reuse global Claude Code instructions as pi global instructions. Pi also
  # discovers project AGENTS.md/CLAUDE.md files automatically.
  home.file.".pi/agent/AGENTS.md".source = ../claude/CLAUDE.md;

  home.file.".pi/agent/themes/claude-code.json".source = ../pi/claude-code-theme.json;

  # Keep existing pi settings/auth intact, but select the Claude Code-like theme.
  home.activation.setPiClaudeCodeTheme = ''
    settings="$HOME/.pi/agent/settings.json"
    mkdir -p "$HOME/.pi/agent"

    if [ -s "$settings" ]; then
      ${pkgs.jq}/bin/jq '.theme = "claude-code" | .enableSkillCommands = true' "$settings" > "$settings.tmp"
    else
      ${pkgs.jq}/bin/jq -n '{ theme: "claude-code", enableSkillCommands: true }' > "$settings.tmp"
    fi

    mv "$settings.tmp" "$settings"
  '';

  # Extra insert-mode navigation that mirrors pi's documented Vim example.
  home.file.".pi/agent/keybindings.json".text = ''
    {
      "tui.editor.cursorUp": ["up", "alt+k"],
      "tui.editor.cursorDown": ["down", "alt+j"],
      "tui.editor.cursorLeft": ["left", "alt+h"],
      "tui.editor.cursorRight": ["right", "alt+l"],
      "tui.editor.cursorWordLeft": ["alt+left", "alt+b"],
      "tui.editor.cursorWordRight": ["alt+right", "alt+w"],
      "tui.input.newLine": ["shift+enter", "ctrl+j"]
    }
  '';
}
