# NixOS system configuration for WSL2 + Hyprland
# This file is a reference copy of /etc/nixos/configuration.nix
# Apply with: sudo cp nixos/configuration.nix /etc/nixos/configuration.nix && sudo nixos-rebuild switch
{
  config,
  lib,
  pkgs,
  ...
}:
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

  # vkms kernel module (requires custom WSL2 kernel with CONFIG_DRM_VKMS=m).
  # tun is needed so pasta can create its TAP device for rootless container
  # networking; /dev/net/tun is otherwise absent on this WSL build.
  boot.kernelModules = [
    "vkms"
    "tun"
    "bridge"
    "br_netfilter"
  ];

  # seatd for Wayland compositor device access
  services.seatd.enable = true;
  users.users.nixos.extraGroups = [
    "seat"
    "video"
    "podman"
  ];

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
    passt
  ];

  # Podman: rootless container engine with docker CLI compatibility.
  # dockerCompat aliases `docker` -> podman and exposes /var/run/docker.sock.
  # dns_enabled is required for inter-container name resolution under compose.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Use pasta (from passt) for rootless container networking instead of the
  # slirp4netns userspace stack. Faster, IPv6-capable, and the upstream default
  # since podman 5; pinning it here keeps the choice declarative.
  virtualisation.containers.containersConf.settings.network.default_rootless_network_cmd = "pasta";

  # earlyoom: userspace OOM prevention. WSL2 gives this VM a fixed memory
  # ceiling with no host-side pressure valve, so a single runaway allocation
  # (a `uv lock` resolver blowup, a parallel cargo/nix build) exhausts RAM and
  # swap and the whole VM thrashes for minutes before the kernel's OOM killer
  # finally fires. By then every terminal session is already unusable, and
  # losing the WSL client tears the VM down with it.
  #
  # earlyoom polls /proc/meminfo and SIGTERMs the largest consumer while the
  # box is still responsive, turning a machine-wide freeze into one dead
  # process.
  #
  # Both thresholds must be crossed before it acts, which makes the swap figure
  # the one that actually decides when. Swap here is VHD-backed and slow, so
  # waiting for it to fill is waiting for the freeze we are trying to avoid.
  # At 90% the swap clause is satisfied once roughly 800 MB of the 8 GB in
  # .wslconfig is in use, which lets the memory clause do the real work and
  # fires while paging is still shallow.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 10; # SIGTERM below ~2 GB free of 20 GB
    freeSwapThreshold = 90; # ...once any meaningful paging has begun
  };

  # Automatic store garbage collection. On WSL2 the backing ext4.vhdx only ever
  # grows to its high-water mark and never shrinks on its own, so unbounded
  # /nix/store growth steadily fills the Windows host disk. A weekly sweep that
  # drops generations older than 7 days keeps that high-water mark in check.
  # (Reclaims old NixOS system generations; run `nix-collect-garbage -d` as your
  # user to also expire standalone home-manager generations.)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Deduplicate identical files in /nix/store via hardlinks. Applied inline as
  # new paths are added; run `nix store optimise` once to dedupe what's already
  # there. This is what actually shrinks the live store between GC sweeps.
  nix.settings.auto-optimise-store = true;

  system.stateVersion = "25.05";
}
