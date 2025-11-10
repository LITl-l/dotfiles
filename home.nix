{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./modules/fish.nix
    ./modules/wezterm.nix
    ./modules/neovim.nix
    ./modules/starship.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/yazi.nix
    ./modules/common.nix
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

    # Nix tools
    nixpkgs-fmt # Nix formatter
    nil        # Nix LSP
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";

    # XDG directories
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
    XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
    XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
    XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
    XDG_BIN_HOME = "${config.home.homeDirectory}/.local/bin";
  };

  # Shell aliases (available in all shells)
  home.shellAliases = {
    # Eza aliases (modern ls)
    ls = "eza --icons --group-directories-first";
    ll = "eza --icons --group-directories-first -l";
    la = "eza --icons --group-directories-first -la";
    lt = "eza --icons --group-directories-first --tree";

    # Git aliases
    g = "git";
    gs = "git status";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
    gd = "git diff";
    gco = "git checkout";
    gb = "git branch";
    glg = "git log --graph --oneline --decorate";

    # Neovim
    vi = "nvim";
    vim = "nvim";

    # Safety
    rm = "rm -i";
    cp = "cp -i";
    mv = "mv -i";

    # Shortcuts
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    # Config shortcuts
    dotfiles = "cd ~/dotfiles";
    config = "cd ~/.config";

    # Nix shortcuts
    nix-rebuild = "home-manager switch --flake ~/dotfiles";
    nix-update = "nix flake update ~/dotfiles";
    nix-clean = "nix-collect-garbage -d";
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

    # Better cd with fzf
    direnv = {
      enable = true;
      nix-direnv.enable = true;
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
