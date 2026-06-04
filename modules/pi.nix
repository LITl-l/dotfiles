{ pkgs, lib, ... }:

{
  # Pi coding-agent compatibility defaults for users migrating from Claude Code.
  # The extension imports pi's bundled libraries by absolute Nix store path, so it
  # does not depend on globally installed node packages or a local node_modules.
  home.file.".pi/agent/extensions/claude-vim.ts".text = builtins.replaceStrings
    [ "@PI_NODE_MODULES@" ]
    [ "${pkgs.pi-coding-agent}/lib/node_modules" ]
    (builtins.readFile ../pi/claude-vim.ts);
  home.file.".pi/agent/extensions/agent-compat.ts".source = ../pi/agent-compat.ts;
  home.file.".pi/agent/extensions/assistant-insight/index.ts".text = builtins.replaceStrings
    [ "@PI_NODE_MODULES@" "@PI_ASSISTANT_INSIGHT_CORE@" ]
    [ "${pkgs.pi-coding-agent}/lib/node_modules" "${../pi/assistant-insight/core.ts}" ]
    (builtins.readFile ../pi/assistant-insight/index.ts);
  home.file.".pi/agent/extensions/assistant-insight/core.ts".source = ../pi/assistant-insight/core.ts;
  home.file.".pi/agent/extensions/goal/index.ts".source = ../pi/goal/index.ts;
  home.file.".pi/agent/extensions/goal/core.ts".source = ../pi/goal/core.ts;
  home.file.".pi/agent/extensions/auto-model-router/index.ts".source = ../pi/auto-model-router/index.ts;
  home.file.".pi/agent/extensions/auto-model-router/core.ts".source = ../pi/auto-model-router/core.ts;
  home.file.".pi/agent/extensions/subagents/index.ts".text = builtins.replaceStrings
    [ "@PI_NODE_MODULES@" "@PI_SUBAGENTS_CORE@" ]
    [ "${pkgs.pi-coding-agent}/lib/node_modules" "${../pi/subagents/core.ts}" ]
    (builtins.readFile ../pi/subagents/index.ts);
  home.file.".pi/agent/extensions/subagents/core.ts".source = ../pi/subagents/core.ts;

  # Reuse global Claude Code instructions as pi global instructions. Pi also
  # discovers project AGENTS.md/CLAUDE.md files automatically.
  home.file.".pi/agent/AGENTS.md".source = ../claude/CLAUDE.md;

  home.file.".pi/agent/themes/claude-code.json".source = ../pi/claude-code-theme.json;

  # Register crumb's context store-and-stub MCP server (stdio transport). Pi reads
  # ~/.pi/agent/mcp.json. lifecycle "lazy" means Pi only spawns the server when a
  # crumb tool is actually invoked. crumb is on PATH via home.packages and has no
  # telemetry, so no opt-out env is needed.
  home.file.".pi/agent/mcp.json".text = ''
    {
      "mcpServers": {
        "crumb": {
          "command": "crumb",
          "args": ["mcp"],
          "lifecycle": "lazy"
        }
      }
    }
  '';

  # Keep existing pi settings/auth intact, but select the Claude Code-like theme.
  home.activation.setPiClaudeCodeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.pi/agent/settings.json"

    if [ -n "''${DRY_RUN:-}" ]; then
      echo "Would update $settings with the Claude Code-like pi theme"
    else
      mkdir -p "$HOME/.pi/agent"

      if [ -s "$settings" ]; then
        ${pkgs.jq}/bin/jq '.theme = "claude-code" | .enableSkillCommands = true' "$settings" > "$settings.tmp"
      else
        ${pkgs.jq}/bin/jq -n '{ theme: "claude-code", enableSkillCommands: true }' > "$settings.tmp"
      fi

      mv "$settings.tmp" "$settings"
    fi
  '';

  # Pi reads context-window metadata from models.json. The OpenAI Codex
  # GPT-5.4/GPT-5.5 models default to 272K in pi's bundled metadata, but can use
  # the experimental 1M-token context window. Merge the override so any existing
  # custom providers or model settings remain intact.
  home.activation.setPiCodexContextWindow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        models="$HOME/.pi/agent/models.json"

        if [ -n "''${DRY_RUN:-}" ]; then
          echo "Would update $models with 1M OpenAI Codex context-window overrides"
        else
          mkdir -p "$HOME/.pi/agent"

          MODELS_PATH="$models" ${pkgs.nodejs}/bin/node --input-type=module <<'NODE'
    import { existsSync, readFileSync, writeFileSync } from "node:fs";

    const modelsPath = process.env.MODELS_PATH;

    function stripJsonComments(input) {
      return input
        .replace(/"(?:\\.|[^"\\])*"|\/\/[^\n]*/g, (match) => match[0] === '"' ? match : "")
        .replace(/"(?:\\.|[^"\\])*"|,(\s*[}\]])/g, (match, tail) => tail ?? (match[0] === '"' ? match : ""));
    }

    let config = {};
    if (existsSync(modelsPath) && readFileSync(modelsPath, "utf8").trim().length > 0) {
      config = JSON.parse(stripJsonComments(readFileSync(modelsPath, "utf8")));
    }

    if (config === null || typeof config !== "object" || Array.isArray(config)) {
      config = {};
    }
    if (config.providers === null || typeof config.providers !== "object" || Array.isArray(config.providers)) {
      config.providers = {};
    }
    if (config.providers["openai-codex"] === null || typeof config.providers["openai-codex"] !== "object" || Array.isArray(config.providers["openai-codex"])) {
      config.providers["openai-codex"] = {};
    }

    const codex = config.providers["openai-codex"];
    if (codex.modelOverrides === null || typeof codex.modelOverrides !== "object" || Array.isArray(codex.modelOverrides)) {
      codex.modelOverrides = {};
    }

    for (const modelId of ["gpt-5.4", "gpt-5.5"]) {
      const current = codex.modelOverrides[modelId];
      codex.modelOverrides[modelId] = {
        ...(current && typeof current === "object" && !Array.isArray(current) ? current : {}),
        contextWindow: 1000000,
      };
    }

    writeFileSync(modelsPath + ".tmp", JSON.stringify(config, null, 2) + "\n");
    NODE

          mv "$models.tmp" "$models"
        fi
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
