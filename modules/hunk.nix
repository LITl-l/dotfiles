{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hunk # Terminal diff viewer for agent-authored changesets (git/jj/sl aware)
  ];

  # This environment's VCS is Jujutsu (see modules/jujutsu.nix), not git.
  xdg.configFile."hunk/config.toml".text = ''
    vcs = "jj"
  '';

  # Expose hunk's bundled review skill to Claude Code as a personal-scope skill
  # (~/.claude/skills/<name>/SKILL.md is auto-discovered and symlinks are
  # followed) so Claude Code can drive a live `hunk` session via
  # `hunk session ...` while coding.
  home.file.".claude/skills/hunk-review".source = "${pkgs.hunk}/skills/hunk-review";
}
