{ config, pkgs, lib, ... }:

let
  # Path to dotfiles repo (adjust if needed)
  dotfilesPath = ../.; # Relative to this module
  localPluginsPath = "${dotfilesPath}/claude/plugins";
in
{
  # Note: Local plugins are symlinked via activation script below
  # because ~/.claude/plugins/marketplaces/ is not fully managed by home-manager

  # Claude Code global settings
  # Note: Project-specific settings remain in .claude/settings.local.json
  home.file.".claude/settings.json".text = builtins.toJSON {
    # Permission settings
    permissions = {
      allow = [
        # Read-only operations
        "Read"
        "Explorer"
        "WebFetch"
        "WebSearch"

        # Safe shell commands
        "Bash(ls:*)"
        "Bash(echo:*)"
        "Bash(cat:*)"
        "Bash(cd:*)"
        "Bash(pwd:*)"
        "Bash(which:*)"
        "Bash(env)"
        "Bash(tree:*)"
        "Bash(wc:*)"

        # Git operations (read)
        "Bash(git status:*)"
        "Bash(git log:*)"
        "Bash(git diff:*)"
        "Bash(git branch:*)"
        "Bash(git show:*)"
        "Bash(git fetch:*)"
        "Bash(git worktree list:*)"

        # Git operations (write)
        "Bash(git add:*)"
        "Bash(git commit:*)"
        "Bash(git worktree:*)"

        # Jujutsu operations (read)
        "Bash(jj status:*)"
        "Bash(jj log:*)"
        "Bash(jj diff:*)"
        "Bash(jj show:*)"
        "Bash(jj config:*)"
        "Bash(jj help:*)"
        "Bash(jj workspace list:*)"

        # Jujutsu operations (write)
        "Bash(jj new:*)"
        "Bash(jj commit:*)"
        "Bash(jj describe:*)"
        "Bash(jj workspace add:*)"
        "Bash(jj git clone:*)"

        # Nix operations
        "Bash(nix flake check:*)"
        "Bash(nix eval:*)"
        "Bash(nix search:*)"
        "Bash(nix-instantiate:*)"

        # GitHub CLI (read)
        "Bash(gh pr view:*)"
        "Bash(gh pr list:*)"
        "Bash(gh pr checks:*)"
        "Bash(gh run view:*)"
        "Bash(gh run list:*)"
        "Bash(gh auth:*)"
        "Bash(gh repo view:*)"

        # Jujutsu git remote (for PR workflow)
        "Bash(jj git remote:*)"

        # Development tools
        "Bash(direnv:*)"
      ];

      deny = [
        # Dangerous operations
        "Bash(rm -rf ~)"
        "Bash(rm -rf /)"
        "Bash(rm -rf /*)"
        "Bash(sudo rm:*)"
        "Bash(chmod -R 777:*)"
      ];

      ask = [
        # Operations requiring confirmation
        "Bash(git push:*)"
        "Bash(jj git push:*)"
        "Bash(gh pr create:*)"
        "Bash(gh pr merge:*)"
        "Bash(gh api:*)"
      ];

      defaultMode = "default";
    };

    # Status line configuration
    statusLine = {
      type = "command";
      command = ''
        input=$(cat)
        dir=$(echo "$input" | jq -r '.workspace.current_dir')
        model=$(echo "$input" | jq -r '.model.display_name')
        style=$(echo "$input" | jq -r '.output_style.name')
        git_branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "")
        git_status=""
        if [ -n "$git_branch" ]; then
          git_dirty=$(git -C "$dir" diff --quiet 2>/dev/null || echo "!")
          git_staged=$(git -C "$dir" diff --cached --quiet 2>/dev/null || echo "+")
          git_status="''${git_dirty}''${git_staged}"
        fi
        printf '\033[1;35m%s\033[0m \033[2;36m%s\033[0m' "$(basename "$dir")" "$model"
        if [ -n "$git_branch" ]; then
          printf ' \033[1;34m\ue0a0 %s\033[0m' "$git_branch"
        fi
        if [ -n "$git_status" ]; then
          printf ' \033[1;31m%s\033[0m' "$git_status"
        fi
        if [ "$style" != "null" ] && [ "$style" != "default" ]; then
          printf ' \033[2;33m[%s]\033[0m' "$style"
        fi
      '';
    };

    # Enabled plugins
    enabledPlugins = {
      "frontend-design@claude-plugins-official" = true;
      "context7@claude-plugins-official" = true;
      "feature-dev@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "ralph-wiggum@claude-plugins-official" = true;
      "hookify@claude-plugins-official" = true;
      "mgrep@Mixedbread-Grep" = true;
      "jj-master@local" = true;
    };

    # Register local marketplace for custom plugins
    extraKnownMarketplaces = {
      local = {
        source = {
          source = "directory";
          path = "~/.claude/plugins/marketplaces/local";
        };
      };
    };

    # Additional directories Claude can access
    additionalDirectories = [
      "~/wkspace/**"
      "~/.config/dotfiles/**"
    ];
  };

  # Register local plugin (symlink plugins and register in installed_plugins.json)
  home.activation.registerClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
    MARKETPLACES_FILE="$HOME/.claude/plugins/known_marketplaces.json"
    MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/local"
    PLUGIN_PATH="$MARKETPLACE_DIR/jj-master"
    LOCAL_PLUGINS_SOURCE="${localPluginsPath}"

    # Create directories
    mkdir -p "$HOME/.claude/plugins/marketplaces"

    # Symlink local marketplace (remove old symlink/dir if exists)
    rm -rf "$MARKETPLACE_DIR"
    ln -sf "$LOCAL_PLUGINS_SOURCE" "$MARKETPLACE_DIR"

    # Create plugins file if not exists
    if [ ! -f "$PLUGINS_FILE" ]; then
      echo '{"version":2,"plugins":{}}' > "$PLUGINS_FILE"
    fi

    # Remove invalid local marketplace entry from known_marketplaces.json if it exists
    if [ -f "$MARKETPLACES_FILE" ]; then
      ${pkgs.jq}/bin/jq 'del(.["local"])' "$MARKETPLACES_FILE" > "$MARKETPLACES_FILE.tmp" && mv "$MARKETPLACES_FILE.tmp" "$MARKETPLACES_FILE"
    fi

    # Add jj-master plugin entry
    ${pkgs.jq}/bin/jq --arg path "$PLUGIN_PATH" '
      .plugins["jj-master@local"] = [{
        "scope": "user",
        "installPath": $path,
        "version": "local",
        "installedAt": (now | strftime("%Y-%m-%dT%H:%M:%S.000Z")),
        "lastUpdated": (now | strftime("%Y-%m-%dT%H:%M:%S.000Z"))
      }]
    ' "$PLUGINS_FILE" > "$PLUGINS_FILE.tmp" && mv "$PLUGINS_FILE.tmp" "$PLUGINS_FILE"
  '';
}

