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

  # Explicitly register the WSLInterop binfmt handler so Windows .exe files
  # (powershell.exe, clip.exe, etc.) are directly executable from bash.
  # Required for the `wsl-clipboard-image-hook.sh` Windows→WSL image bridge.
  wsl.interop.register = true;

  # vkms kernel module (requires custom WSL2 kernel with CONFIG_DRM_VKMS=m)
  boot.kernelModules = [ "vkms" ];

  # seatd for Wayland compositor device access
  services.seatd.enable = true;
  users.users.nixos.extraGroups = [ "seat" "video" ];

  # nix-ld: run unpatched dynamic binaries on NixOS
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
    curl
    glib
    icu
    expat
    nss
    nspr
    atk
    cups
    dbus
    libdrm
    pango
    cairo
    mesa
    libGL
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  # System-level packages for Hyprland compositor
  environment.systemPackages = with pkgs; [
    hyprland
    foot
    wayvnc
    seatd
  ];

  system.stateVersion = "25.05";
}
