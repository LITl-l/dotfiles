# NixOS system configuration for WSL2 + Hyprland
# This file is a reference copy of /etc/nixos/configuration.nix
# Apply with: sudo cp nixos/configuration.nix /etc/nixos/configuration.nix && sudo nixos-rebuild switch
{ config, lib, pkgs, ... }:
{
  imports = [
    <nixos-wsl/modules>
  ];

  wsl.enable = true;
  wsl.defaultUser = "nixos";

  # vkms kernel module (requires custom WSL2 kernel with CONFIG_DRM_VKMS=m)
  boot.kernelModules = [ "vkms" ];

  # seatd for Wayland compositor device access
  services.seatd.enable = true;
  users.users.nixos.extraGroups = [ "seat" "video" ];

  # System-level packages for Hyprland compositor
  environment.systemPackages = with pkgs; [
    hyprland
    foot
    wayvnc
    seatd
  ];

  system.stateVersion = "25.05";
}
