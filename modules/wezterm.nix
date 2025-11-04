{ config, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = lib.mkDefault true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };

  # WezTerm configuration
  xdg.configFile."wezterm/wezterm.lua".source = ../config/wezterm/wezterm.lua;
}
