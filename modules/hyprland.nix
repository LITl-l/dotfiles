{ config, pkgs, lib, ... }:

let
  cfg = config.dotfiles.hyprland;
in
{
  options.dotfiles.hyprland.enable = lib.mkEnableOption "Hyprland WSL2 compositor setup";

  config = lib.mkIf cfg.enable {
    # Hyprland configuration (WSL2 + vkms + wayvnc)
    xdg.configFile."hypr/hyprland.conf".source = ../hyprland/hyprland.conf;

    # Waybar configuration
    xdg.configFile."waybar/config.jsonc".source = ../waybar/config.jsonc;
    xdg.configFile."waybar/style.css".source = ../waybar/style.css;

    # Fuzzel configuration
    xdg.configFile."fuzzel/fuzzel.ini".source = ../fuzzel/fuzzel.ini;

    # Start script for launching Hyprland on WSL2
    home.file."start-hyprland.sh" = {
      source = ../hyprland/start-hyprland.sh;
      executable = true;
    };

    home.packages = with pkgs; [
      hyprland
      foot
      wayvnc
      grim
      waybar
      fuzzel
      swww
      mako
    ];
  };
}
