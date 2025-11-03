{ config, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };

  # WezTerm configuration
  xdg.configFile."wezterm/wezterm.lua".source = ../config/wezterm/wezterm.lua;
}
