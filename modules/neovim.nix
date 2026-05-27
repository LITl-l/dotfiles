{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Neovim packages
    extraPackages = with pkgs; [
      # Language servers
      lua-language-server
      nil # Nix LSP
      bash-language-server
      vtsls # TypeScript/JavaScript LSP (VSCode's tsserver wrapper)
      vscode-langservers-extracted # HTML, CSS, JSON, ESLint
      yaml-language-server
      basedpyright # Python LSP (pyright fork with stricter defaults)
      ruff # Python linter + formatter (native LSP via `ruff server`)
      rust-analyzer
      gopls

      # Formatters
      nixfmt # Official Nix formatter (RFC 166) — was nixfmt-rfc-style, now aliased
      shfmt
      oxfmt # JS/TS/JSON formatter (Rust, prettier-compatible output → zero style churn)
      prettierd # Used for CSS/SCSS/HTML/YAML/Markdown (oxfmt doesn't cover those yet)
      gofumpt # Stricter superset of gofmt
      rustfmt
      stylua # Lua formatter (used by conform)

      # Tools
      ripgrep
      fd
      tree-sitter
      git
    ];

    # Plugins
    plugins = with pkgs.vimPlugins; [
      # Treesitter for syntax highlighting
      # Use specific grammars instead of all for better performance
      (nvim-treesitter.withPlugins (p: [
        # Essential for Neovim
        p.lua
        p.vim
        p.vimdoc
        p.query

        # Dotfiles configuration languages
        p.nix
        p.bash
        p.markdown
        p.markdown_inline
        p.yaml
        p.toml

        # Common development languages
        p.javascript
        p.typescript
        p.tsx
        p.python
        p.rust
        p.go
        p.html
        p.css
        p.json
      ]))

      # Color scheme
      catppuccin-nvim

      # Snippet engine
      luasnip
      friendly-snippets

      # Formatter
      conform-nvim

      # Debugger
      nvim-dap
      nvim-dap-ui
      nvim-dap-virtual-text

      # Keybinding helper
      which-key-nvim

      # LSP UI enhancement
      lspsaga-nvim

      # Mini.nvim will be bootstrapped in init.lua
    ];
  };

  # Copy entire nvim config directory
  xdg.configFile."nvim" = {
    source = ../nvim;
    recursive = true;
  };
}
