{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    # Git settings (replaces extraConfig)
    settings = {
      core = {
        editor = "nvim";
        excludesfile = "~/.config/git/ignore";
        attributesfile = "~/.config/git/attributes";
        autocrlf = "input";
        safecrlf = "warn";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };

      init = {
        defaultBranch = "main";
      };

      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        interactive = "auto";
        status = "auto";
      };

      push = {
        default = "current";
        autoSetupRemote = true;
      };

      pull = {
        rebase = true;
      };

      fetch = {
        prune = true;
      };

      merge = {
        ff = "only";
        conflictstyle = "diff3";
      };

      rebase = {
        autoStash = true;
      };

      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };

      ghq = {
        root = "~/src";
      };

      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };

      credential = {
        helper = "cache --timeout=3600";
      };

      include = {
        path = "~/.config/git/config.local";
      };
    };

    # Git ignore patterns
    ignores = [
      # OS generated files
      ".DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "ehthumbs.db"
      "Thumbs.db"
      "Desktop.ini"

      # Editor files
      "*~"
      "*.swp"
      "*.swo"
      "*.swn"
      ".vscode/"
      ".idea/"
      "*.iml"
      ".project"
      ".settings/"
      ".classpath"

      # Temporary files
      "*.tmp"
      "*.temp"
      "*.log"
      "*.cache"
      ".cache/"

      # Build artifacts
      "*.o"
      "*.so"
      "*.dylib"
      "*.exe"
      "*.dll"
      "*.out"
      "*.class"
      "*.jar"
      "*.war"
      "*.ear"

      # Language specific
      "__pycache__/"
      "*.py[cod]"
      "*$py.class"
      ".pytest_cache/"
      ".coverage"
      "htmlcov/"
      ".tox/"
      ".mypy_cache/"
      ".ruff_cache/"
      "node_modules/"
      "npm-debug.log*"
      "yarn-debug.log*"
      "yarn-error.log*"
      ".pnpm-debug.log*"
      "dist/"
      "build/"
      "target/"
      "Cargo.lock"
      "vendor/"

      # Environment files
      ".env"
      ".env.*"
      "!.env.example"
      "!.env.sample"
      ".envrc"

      # Secrets
      "*.pem"
      "*.key"
      "*.crt"
      "*.p12"
      ".secrets/"

      # Backup files
      "*.bak"
      "*.backup"
      "*.old"

      # Archives
      "*.zip"
      "*.tar"
      "*.tar.gz"
      "*.tgz"
      "*.rar"
      "*.7z"

      # Database
      "*.sqlite"
      "*.sqlite3"
      "*.db"

      # Misc
      ".directory"
      ".sass-cache/"

      # Claude Code settings
      "**/.claude/settings.local.json"

      # Proto trace dumps
      "dump-*.json"
    ];
  };

  # Delta for better diffs (separate from git)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = false;
    };
  };

  # Lazygit
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [ "blue" "bold" ];
          inactiveBorderColor = [ "white" ];
          selectedLineBgColor = [ "blue" ];
        };
        showFileTree = true;
        showCommandLog = false;
      };
      git = {
        paging = {
          colorArg = "always";
          pager = "delta --paging=never";
        };
      };
      os = {
        editPreset = "nvim";
      };
    };
  };

  # Copy git attributes file
  xdg.configFile."git/attributes".text = ''
    # Git attributes file

    # Auto detect text files and perform LF normalization
    * text=auto

    # Documents
    *.doc  diff=astextplain
    *.DOC  diff=astextplain
    *.docx diff=astextplain
    *.DOCX diff=astextplain
    *.dot  diff=astextplain
    *.DOT  diff=astextplain
    *.pdf  diff=astextplain
    *.PDF  diff=astextplain
    *.rtf  diff=astextplain
    *.RTF  diff=astextplain
    *.md text
    *.tex text
    *.adoc text
    *.textile text
    *.mustache text
    *.csv text
    *.tab text
    *.tsv text
    *.txt text

    # Programming languages
    *.sh text eol=lf
    *.bash text eol=lf
    *.zsh text eol=lf
    *.fish text eol=lf
    *.py text diff=python
    *.rb text diff=ruby
    *.rs text diff=rust
    *.go text diff=golang
    *.js text
    *.jsx text
    *.ts text
    *.tsx text
    *.json text
    *.toml text
    *.yaml text
    *.yml text
    *.xml text
    *.html text diff=html
    *.css text diff=css
    *.scss text diff=css
    *.sass text
    *.less text
    *.java text diff=java
    *.kt text
    *.groovy text
    *.scala text
    *.c text diff=cpp
    *.cc text diff=cpp
    *.cxx text diff=cpp
    *.cpp text diff=cpp
    *.h text diff=cpp
    *.hh text diff=cpp
    *.hxx text diff=cpp
    *.hpp text diff=cpp
    *.php text diff=php
    *.lua text
    *.vim text
    *.sql text

    # Config files
    Dockerfile text
    .dockerignore text
    .gitignore text
    .gitattributes text
    .editorconfig text
    Makefile text
    makefile text
    *.mk text

    # Binary files
    *.png binary
    *.jpg binary
    *.jpeg binary
    *.gif binary
    *.ico binary
    *.svg text
    *.webp binary
    *.pdf binary
    *.zip binary
    *.gz binary
    *.tar binary
    *.tgz binary
    *.jar binary
    *.war binary
    *.ear binary
    *.exe binary
    *.dll binary
    *.so binary
    *.dylib binary
    *.ttf binary
    *.eot binary
    *.woff binary
    *.woff2 binary
    *.otf binary
  '';
}
