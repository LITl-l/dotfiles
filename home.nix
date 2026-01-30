{ config, pkgs, lib, inputs, ... }:

let
  # Custom nix-manager package
  nix-manager = pkgs.callPackage ./pkgs/nix-manager.nix { };
in
{
  imports = [
    ./modules/fish.nix
    ./modules/wezterm.nix
    ./modules/neovim.nix
    ./modules/starship.nix
    ./modules/git.nix
    ./modules/jujutsu.nix
    ./modules/yazi.nix
    ./modules/common.nix
    ./modules/claude-code.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # XDG Base Directory Specification
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };

  # Essential packages
  home.packages = with pkgs; [
    # Modern CLI tools
    eza        # Modern ls replacement
    yazi       # Terminal file manager
    fd         # Modern find replacement
    ripgrep    # Modern grep replacement
    fzf        # Fuzzy finder
    bat        # Better cat
    delta      # Better git diff
    lazygit    # Terminal UI for git
    jq         # JSON processor
    yq-go      # YAML processor
    htop       # Process viewer
    tree       # Directory tree viewer
    curl       # HTTP client
    wget       # File downloader
    unzip      # Archive extractor
    gzip       # Compression tool
    rsync      # File sync

    # Development tools
    git-lfs    # Git Large File Storage
    gh         # GitHub CLI
    ghq        # Git repository manager
    # Claude Code is installed via native installer (not npm)
    # Run: curl -fsSL https://claude.ai/install.sh | bash

    # Nix tools
    nixpkgs-fmt # Nix formatter
    nil        # Nix LSP
    nix-manager # Custom nix-manager command
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # WSL utilities (Linux only)
    wslu       # WSL utilities for Windows integration
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    BROWSER = "wslview";  # Use wslview to open URLs in Windows default browser

    # XDG directories
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_BIN_HOME = "${config.home.homeDirectory}/.local/bin";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable programs with simple configs
  programs = {
    # Directory jumper
    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    # Automatic environment loading
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Silence verbose output
      config.global = {
        hide_env_diff = true;
      };
    };

    # Man pages
    man = {
      enable = true;
      generateCaches = true;
    };

    # Less pager
    less.enable = true;

    # Bat (better cat)
    bat = {
      enable = true;
      config = {
        style = "numbers,changes,header";
      };
    };

    # FZF fuzzy finder
    fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--inline-info"
      ];
    };
  };
}
