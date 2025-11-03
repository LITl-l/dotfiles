{ config, pkgs, lib, ... }:

{
  # Common settings across all platforms

  # Enable readline for better command line editing
  programs.readline = {
    enable = true;
    variables = {
      editing-mode = "vi";
      show-mode-in-prompt = true;
      vi-cmd-mode-string = "\\1\\e[2 q\\2";
      vi-ins-mode-string = "\\1\\e[6 q\\2";
    };
  };

  # SSH client configuration
  programs.ssh = {
    enable = true;
    compression = true;
    serverAliveInterval = 60;
    serverAliveCountMax = 3;
    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  # GPG
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
