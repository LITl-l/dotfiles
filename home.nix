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
    ./modules/pi.nix
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
    eza # Modern ls replacement
    yazi # Terminal file manager
    fd # Modern find replacement
    ripgrep # Modern grep replacement
    ast-grep # AST-aware structural code search
    fzf # Fuzzy finder
    bat # Better cat
    delta # Better git diff
    lazygit # Terminal UI for git
    jq # JSON processor
    yq-go # YAML processor
    htop # Process viewer
    tree # Directory tree viewer
    curl # HTTP client
    wget # File downloader
    unzip # Archive extractor
    gzip # Compression tool
    rsync # File sync

    # Development tools
    git-lfs # Git Large File Storage
    gh # GitHub CLI
    gh-dash # TUI dashboard for GitHub PRs and issues
    ghq # Git repository manager
    claude-code # Claude AI coding assistant (native binary via ryoppippi/claude-code-overlay)
    pi-coding-agent # Pi coding agent (native binary via lukasl-dev/pi.nix; Codex/Claude/Copilot subscription login)

    # Containers
    podman # Daemonless container engine (docker-compatible CLI)

    # Nix tools
    nixpkgs-fmt # Nix formatter
    nil # Nix LSP
    nix-manager # Custom nix-manager command
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    # headroom-ai context-compression CLI + MCP server (via LITl-l/headroom-overlay).
    # Linux-guarded: the overlay only publishes x86_64-linux. pkgs.headroom is
    # fully qualified because this append is outside the `with pkgs;` scope above.
    pkgs.headroom
  ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    BROWSER = "xdg-open";

    # Opt out of headroom-ai's on-by-default telemetry. Its TelemetryBeacon
    # (site-packages/headroom/telemetry/beacon.py) otherwise POSTs anonymous
    # aggregate stats — plus a SHA256(hostname) machine fingerprint — to a
    # hardcoded Supabase endpoint every 5 minutes. This is headroom's documented
    # kill-switch; collector.py honours it too (gates the /v1/telemetry report).
    # Set at session scope so the `headroom` CLI *and* the MCP servers (which
    # inherit this env) are covered; also baked into each MCP registration as
    # defense-in-depth (see modules/claude-code.nix and modules/pi.nix).
    HEADROOM_TELEMETRY = "off";

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
      extra-substituters = https://ryoppippi.cachix.org https://pi.cachix.org
      extra-trusted-public-keys = ryoppippi.cachix.org-1:b2LbtWNvJeL/qb1B6TYOMK+apaCps4SCbzlPRfSQIms= pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk=
      # headroom-overlay cachix cache (deferred): once the cache + public key exist,
      # append " https://headroom-overlay.cachix.org" to extra-substituters above and
      # " headroom-overlay.cachix.org-1:<KEY>" to extra-trusted-public-keys above.
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
