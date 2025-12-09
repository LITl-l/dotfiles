{ config, pkgs, lib, ... }:

{
  programs.jujutsu = {
    enable = true;

    settings = {
      # User identity: set via `jj config set --user user.name "Your Name"`
      # or create ~/.jjconfig.toml manually

      # UI preferences
      ui = {
        editor = "nvim";
        pager = "delta";
        diff.format = "git";
      };

      # Git backend settings
      git = {
        auto-local-branch = true;
      };
    };
  };

  # jjui - TUI for Jujutsu VCS
  home.packages = with pkgs; [
    jjui
  ];
}
