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
      nodePackages.bash-language-server
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
      nodePackages.yaml-language-server
      python3Packages.python-lsp-server
      rust-analyzer
      gopls

      # Formatters
      nixpkgs-fmt
      shfmt
      nodePackages.prettier
      black
      rustfmt

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

      # Mini.nvim will be bootstrapped in init.lua
    ];
  };

  # Copy entire nvim config directory
  xdg.configFile."nvim" = {
    source = ../nvim;
    recursive = true;
  };
}
