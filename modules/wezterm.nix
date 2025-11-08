{ config, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = lib.mkDefault true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };

  # WezTerm configuration files
  xdg.configFile."wezterm/wezterm.lua".source = ../wezterm/wezterm.lua;
  xdg.configFile."wezterm/appearance.lua".source = ../wezterm/appearance.lua;
  xdg.configFile."wezterm/domains.lua".source = ../wezterm/domains.lua;
  xdg.configFile."wezterm/fonts.lua".source = ../wezterm/fonts.lua;
  xdg.configFile."wezterm/keybindings.lua".source = ../wezterm/keybindings.lua;
  xdg.configFile."wezterm/mouse.lua".source = ../wezterm/mouse.lua;
  xdg.configFile."wezterm/performance.lua".source = ../wezterm/performance.lua;
  xdg.configFile."wezterm/platform.lua".source = ../wezterm/platform.lua;
  xdg.configFile."wezterm/theme.lua".source = ../wezterm/theme.lua;

  # Create a shell configuration file with the correct fish path
  xdg.configFile."wezterm/shell.lua".text = ''
    -- Shell configuration with Nix-managed paths
    local M = {}

    -- Fish shell path from Nix
    M.fish_path = "${pkgs.fish}/bin/fish"

    return M
  '';
}
