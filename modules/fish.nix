{ config, pkgs, lib, inputs, ... }:

{
  programs.fish = {
    enable = true;

    # Fish shell options
    shellInit = ''
      # Disable greeting
      set -g fish_greeting

      # Vi mode
      fish_vi_key_bindings

      # Colors for vi mode indicator
      set -g fish_cursor_default block
      set -g fish_cursor_insert line
      set -g fish_cursor_replace_one underscore
      set -g fish_cursor_visual block

      # Set colors (Catppuccin Mocha theme)
      set -g fish_color_normal c6d0f5
      set -g fish_color_command 8caaee
      set -g fish_color_param eebebe
      set -g fish_color_keyword e78284
      set -g fish_color_quote a6d189
      set -g fish_color_redirection f4b8e4
      set -g fish_color_end ef9f76
      set -g fish_color_comment 838ba7
      set -g fish_color_error e78284
      set -g fish_color_gray 737994
      set -g fish_color_selection --background=414559
      set -g fish_color_search_match --background=414559
      set -g fish_color_operator f4b8e4
      set -g fish_color_escape ea999c
      set -g fish_color_autosuggestion 737994
      set -g fish_color_cancel e78284

      # Pager colors
      set -g fish_pager_color_progress 737994
      set -g fish_pager_color_prefix 8caaee
      set -g fish_pager_color_completion c6d0f5
      set -g fish_pager_color_description 737994
    '';

    # Interactive shell initialization
    interactiveShellInit = ''
      # Starship prompt will handle vi mode indicators via character.vicmd_symbol
      # No need for custom fish_mode_prompt as it conflicts with starship
    '';

    # Fish functions
    functions = {
      # Git commit with conventional format
      gcm = {
        description = "Git commit with message";
        body = ''
          git commit -m "$argv"
        '';
      };

      # Git add all and commit
      gac = {
        description = "Git add all and commit";
        body = ''
          git add .
          git commit -m "$argv"
        '';
      };

      # Git add all, commit and push
      gacp = {
        description = "Git add all, commit and push";
        body = ''
          git add .
          git commit -m "$argv"
          git push
        '';
      };

      # Make directory and cd into it
      mkcd = {
        description = "Make directory and cd into it";
        body = ''
          mkdir -p $argv[1]
          cd $argv[1]
        '';
      };

      # Extract archives
      extract = {
        description = "Extract various archive formats";
        body = ''
          if test -f $argv[1]
              switch $argv[1]
                  case '*.tar.bz2'
                      tar xjf $argv[1]
                  case '*.tar.gz'
                      tar xzf $argv[1]
                  case '*.bz2'
                      bunzip2 $argv[1]
                  case '*.rar'
                      unrar x $argv[1]
                  case '*.gz'
                      gunzip $argv[1]
                  case '*.tar'
                      tar xf $argv[1]
                  case '*.tbz2'
                      tar xjf $argv[1]
                  case '*.tgz'
                      tar xzf $argv[1]
                  case '*.zip'
                      unzip $argv[1]
                  case '*.Z'
                      uncompress $argv[1]
                  case '*.7z'
                      7z x $argv[1]
                  case '*'
                      echo "'$argv[1]' cannot be extracted via extract()"
              end
          else
              echo "'$argv[1]' is not a valid file"
          end
        '';
      };

      # Quick file search
      f = {
        description = "Quick file search with fd and fzf";
        body = ''
          set -l file (fd --type f --hidden --exclude .git | fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}')
          and echo $file
        '';
      };

      # Quick directory search
      fd_dir = {
        description = "Quick directory search with fd and fzf";
        body = ''
          set -l dir (fd --type d --hidden --exclude .git | fzf --preview 'eza --tree --level=2 {}')
          and cd $dir
        '';
      };

      # Nix shortcuts
      rebuild = {
        description = "Rebuild home-manager configuration";
        body = ''
          home-manager switch --flake ~/dotfiles
        '';
      };

      nix-search = {
        description = "Search for Nix packages";
        body = ''
          nix search nixpkgs $argv
        '';
      };
    };

    # Fish plugins
    plugins = [
      # z directory jumper
      {
        name = "z";
        src = inputs.fish-plugin-z;
      }
      # fzf integration
      {
        name = "fzf.fish";
        src = inputs.fish-plugin-fzf;
      }
    ];
  };

  # Set Fish as default shell
  home.sessionVariables = {
    SHELL = "${pkgs.fish}/bin/fish";
  };
}
