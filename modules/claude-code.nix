{ config, pkgs, lib, ... }:

let
  claudeConfigPath = "${../.}/claude";
in
{
  # Claude Code stop hook - symlinked (read-only, safe as symlink)
  home.file.".claude/stop-hook-git-check.sh".source = "${claudeConfigPath}/stop-hook-git-check.sh";

  # Setup Claude Code configuration and plugins after build
  # settings.json is COPIED (not symlinked) so Claude CLI can modify it for plugin registration
  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.claude"
    cp -f "${claudeConfigPath}/settings.json" "$HOME/.claude/settings.json"
    chmod 644 "$HOME/.claude/settings.json"
    cp -f "${claudeConfigPath}/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    chmod 644 "$HOME/.claude/CLAUDE.md"
    if command -v claude &>/dev/null; then
      "${claudeConfigPath}/setup-marketplace.sh" --update 2>/dev/null || true
    fi
  '';
}
