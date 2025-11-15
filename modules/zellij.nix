{ config, pkgs, lib, ... }:

{
  programs.zellij = {
    enable = true;
    enableFishIntegration = true;
  };

  # Zellij configuration will be managed via config files
  xdg.configFile = {
    "zellij/config.kdl".source = ../zellij/config.kdl;
    "zellij/themes/catppuccin-mocha.kdl".source = ../zellij/themes/catppuccin-mocha.kdl;
    "zellij/themes/warm-light.kdl".source = ../zellij/themes/warm-light.kdl;
    "zellij/layouts/default.kdl".source = ../zellij/layouts/default.kdl;
    "zellij/layouts/dev.kdl".source = ../zellij/layouts/dev.kdl;
  };

  home.packages = with pkgs; [
    zellij
  ];
}
