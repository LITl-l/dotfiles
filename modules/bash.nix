{ config, pkgs, lib, ... }:

{
  programs.bash = {
    enable = true;

    # Auto-start fish for interactive shells
    # This ensures fish starts when you open a terminal, even if bash is the login shell
    initExtra = ''
      # If running interactively and fish is available, exec fish
      if [[ $- == *i* ]] && command -v fish &> /dev/null; then
        exec fish
      fi
    '';
  };
}
