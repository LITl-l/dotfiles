{ config, pkgs, lib, ... }:

{
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

        # Development tools
        "Bash(direnv:*)"
        "Bash(devbox:*)"
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
    };

    # Additional directories Claude can access
    additionalDirectories = [
      "~/wkspace/**"
      "~/.config/dotfiles/**"
    ];
  };
}
