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
      # Vi mode cursor shapes
      function fish_vi_cursor_bind
          set -l mode $argv[1]
          set -l cursor $argv[2]

          set -l bind_mode
          switch $mode
              case default
                  set bind_mode normal
              case insert
                  set bind_mode insert
              case visual
                  set bind_mode visual
              case replace_one
                  set bind_mode replace
          end

          bind -M $bind_mode -m $bind_mode "" "set fish_cursor_$mode $cursor; commandline -f repaint"
      end

      # Enhanced vi mode indicator
      function fish_mode_prompt
          switch $fish_bind_mode
              case default
                  echo -n "🅝 "
                  set_color --bold blue
                  echo -n "NORMAL"
              case insert
                  echo -n "🅘 "
                  set_color --bold green
                  echo -n "INSERT"
              case visual
                  echo -n "🅥 "
                  set_color --bold yellow
                  echo -n "VISUAL"
              case replace_one
                  echo -n "🅡 "
                  set_color --bold red
                  echo -n "REPLACE"
          end
          set_color normal
          echo -n " "
      end

      # Yazi keybinding - open with Ctrl+O
      bind \co yazi-cd
    '';

    # Fish abbreviations
    shellAbbrs = {
      # Eza abbreviations (modern ls)
      ls = "eza --icons --group-directories-first";
      ll = "eza --icons --group-directories-first -l";
      la = "eza --icons --group-directories-first -la";
      lt = "eza --icons --group-directories-first --tree";

      # Git abbreviations
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

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Config shortcuts
      dotfiles = "cd ~/.config/dotfiles";
      config = "cd ~/.config";

      # Nix shortcuts (using nix-manager)
      nix-rebuild = "nix-manager rebuild";
      nix-update = "nix-manager update";
      nix-clean = "nix-manager clean";
    };

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

      # Yazi wrapper to change directory on exit
      yazi-cd = {
        description = "Open yazi and cd to the directory on exit";
        body = ''
          set tmp (mktemp -t "yazi-cwd.XXXXX")
          yazi $argv --cwd-file="$tmp"
          if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            cd -- "$cwd"
          end
          rm -f -- "$tmp"
        '';
      };

      # Quick yazi shortcut
      y = {
        description = "Open yazi file manager";
        body = ''
          yazi-cd $argv
        '';
      };

      # Git worktree wrapper with file copying
      git-worktree-add = {
        description = "Create git worktree and copy configured files";
        body = ''
          # Get the repository root
          set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
          if test -z "$repo_root"
            echo "Error: Not in a git repository" >&2
            return 1
          end

          # Create the worktree
          git worktree add $argv
          if test $status -ne 0
            return 1
          end

          # The last argument should be the path (or extract from output)
          set -l worktree_path $argv[-1]

          # If path is relative, make it absolute
          if not string match -q '/*' $worktree_path
            set worktree_path (pwd)/$worktree_path
          end

          # Copy files using the script
          set -l script_path "$repo_root/scripts/copy-workspace-files.sh"
          if test -x "$script_path"
            echo "🔄 Copying workspace files..."
            $script_path "$repo_root" "$worktree_path"
          end
        '';
      };

      # Jujutsu workspace wrapper with file copying
      jj-workspace-add = {
        description = "Create jj workspace and copy configured files";
        body = ''
          # Get the repository root
          set -l repo_root (jj root 2>/dev/null)
          if test -z "$repo_root"
            echo "Error: Not in a jujutsu repository" >&2
            return 1
          end

          # Create the workspace
          jj workspace add $argv
          if test $status -ne 0
            return 1
          end

          # The last argument should be the path
          set -l workspace_path $argv[-1]

          # If path is relative, make it absolute
          if not string match -q '/*' $workspace_path
            set workspace_path (pwd)/$workspace_path
          end

          # Copy files using the script
          set -l script_path "$repo_root/scripts/copy-workspace-files.sh"
          if test -x "$script_path"
            echo "🔄 Copying workspace files..."
            $script_path "$repo_root" "$workspace_path"
          end
        '';
      };

      # Navigate to ghq-managed repositories interactively
      repo = {
        description = "Navigate to ghq repositories with fzf";
        body = ''
          set -l selected (ghq list | fzf)
          if test -n "$selected"
            cd (ghq root)/$selected
          end
        '';
      };

      # Navigate to jj workspaces interactively
      jj-ws = {
        description = "Navigate to jj workspaces with fzf";
        body = ''
          # Get the repository root
          set -l repo_root (jj root 2>/dev/null)
          if test -z "$repo_root"
            echo "Error: Not in a jujutsu repository" >&2
            return 1
          end

          # Get workspace list and select with fzf
          set -l selected (jj workspace list 2>/dev/null | awk '{print $1}' | fzf)
          if test -n "$selected"
            # Get workspace path from jj workspace list output
            set -l workspace_info (jj workspace list 2>/dev/null | grep "^$selected ")
            set -l workspace_path (echo $workspace_info | awk '{print $2}')
            if test -n "$workspace_path"
              cd $workspace_path
            end
          end
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
