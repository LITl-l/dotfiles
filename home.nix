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
    ./modules/hyprland.nix
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
    ast-grep   # AST-aware structural code search
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
    claude-code # Claude AI coding assistant (native binary via ryoppippi/claude-code-overlay)

    # Nix tools
    nixpkgs-fmt # Nix formatter
    nil        # Nix LSP
    nix-manager # Custom nix-manager command
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    BROWSER = "xdg-open";

    # XDG directories
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_BIN_HOME = "${config.home.homeDirectory}/.local/bin";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix configuration (managed by Home Manager)
  # Uses !include to optionally load a local config with GitHub access token
  xdg.configFile."nix/nix.conf" = {
    # Force overwrite in case install.sh created a regular file here
    force = true;
    text = ''
      experimental-features = nix-command flakes
      warn-dirty = false
      accept-flake-config = true
      extra-substituters = https://ryoppippi.cachix.org
      extra-trusted-public-keys = ryoppippi.cachix.org-1:b2LbtWNvJeL/qb1B6TYOMK+apaCps4SCbzlPRfSQIms=
      !include ${config.home.homeDirectory}/.config/nix/nix.local.conf
    '';
  };

  # Generate nix.local.conf with GitHub token for authenticated API access
  # This avoids GitHub API rate limiting during `nix flake update`
  home.activation.setupNixGithubToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    local_conf="${config.home.homeDirectory}/.config/nix/nix.local.conf"
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
      token=$(gh auth token 2>/dev/null)
      if [ -n "$token" ]; then
        echo "access-tokens = github.com=$token" > "$local_conf"
      else
        touch "$local_conf"
      fi
    else
      touch "$local_conf"
    fi
  '';

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
