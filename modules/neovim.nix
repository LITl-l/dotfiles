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
      nvim-treesitter.withAllGrammars

      # Color scheme
      catppuccin-nvim

      # Mini.nvim will be bootstrapped in init.lua
    ];
  };

  # Copy entire nvim config directory
  xdg.configFile."nvim" = {
    source = ../nvim;
    recursive = true;
  };
}
