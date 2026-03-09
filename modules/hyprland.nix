{ config, pkgs, lib, ... }:

let
  cfg = config.dotfiles.hyprland;
in
{
  options.dotfiles.hyprland.enable = lib.mkEnableOption "Hyprland WSL2 compositor setup";

  config = lib.mkIf cfg.enable {
    # Hyprland configuration (WSL2 + vkms + wayvnc)
    xdg.configFile."hypr/hyprland.conf".source = ../hyprland/hyprland.conf;

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
    ];
  };
}
