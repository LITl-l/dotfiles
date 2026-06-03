{ config, pkgs, lib, ... }:

let
  # Renders the Jujutsu (jj) prompt segment: the workspace name (always shown),
  # the nearest ancestor bookmark (jj's "branch"-like pointer), and state flags
  # (◌ empty / ✖ conflict / ÷ divergent). A single read-only `jj` call per
  # prompt: `--ignore-working-copy` so it never snapshots/mutates, and `jj`
  # walks up to find the repo so it works in subdirectories too. Prints nothing
  # outside a jj repo or on any error, which hides the module.
  jjPrompt = pkgs.writeShellScript "starship-jj-prompt" ''
    out=$(${pkgs.jujutsu}/bin/jj log \
      -r '@ | heads(::@ & bookmarks())' \
      --no-graph --ignore-working-copy --color never \
      -T 'if(current_working_copy, "ws " ++ working_copies ++ "\n" ++ "bm " ++ bookmarks.join(",") ++ "\n" ++ if(empty, "st ◌\n") ++ if(conflict, "st ✖\n") ++ if(divergent, "st ÷\n"), "bm " ++ bookmarks.join(",") ++ "\n")' \
      2>/dev/null) || exit 0
    [ -n "$out" ] || exit 0

    ws=""
    bm=""
    st=""
    while IFS=' ' read -r key val; do
      case "$key" in
        ws) [ -n "$val" ] && ws=$val ;;
        bm) [ -n "$val" ] && bm=$val ;;
        st) st="$st $val" ;;
      esac
    done <<< "$out"

    [ -n "$ws" ] || exit 0
    # Nerd Font glyphs (U+F401 nf-oct-repo, U+F02E nf-fa-bookmark; swap to taste):
    wsg=$(printf '')   # nf-oct-repo    (workspace)
    bmg=$(printf '')   # nf-fa-bookmark (bookmark)
    seg="$wsg $ws"
    [ -n "$bm" ] && seg="$seg    $bmg $bm"
    [ -n "$st" ] && seg="$seg$st"
    printf '%s ' "$seg"
  '';
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = false; # We're using Fish now

    # Starship configuration
    settings = {
      # Timeout for commands
      command_timeout = 1000;

      # Prompt format
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_state"
        "$git_metrics"
        "\${custom.jj}"
        "$fill"
        "$all"
        "$line_break"
        "$character"
      ];

      # Right prompt
      right_format = "$cmd_duration$jobs$time";

      # Prompt character
      character = {
        success_symbol = "[❯](bold #40a02b)";
        error_symbol = "[❯](bold #d20f39)";
        vicmd_symbol = "[❮](bold #ea76cb)";
      };

      # Username
      username = {
        show_always = false;
        format = "[$user]($style) ";
        style_user = "bold #8839ef";
        style_root = "bold #d20f39";
      };

      # Hostname
      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = "bold #40a02b";
      };

      # Directory
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold #04a5e5";
        read_only = " 󰌾";
        read_only_style = "#d20f39";
        truncation_length = 3;
        truncate_to_repo = true;
        truncation_symbol = "…/";
        substitutions = {
          "~/Documents" = "󰈙";
          "~/Downloads" = "󰉍";
          "~/Music" = "󰝚";
          "~/Pictures" = "󰉏";
          "~/Projects" = "󰲋";
          "~/src" = "";
        };
      };

      # Git
      git_branch = {
        format = "[$symbol$branch(:$remote_branch)]($style) ";
        symbol = " ";
        style = "bold #8839ef";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "bold #e64553";
        conflicted = "=";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "$\${count}";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };

      git_state = {
        format = "([$state( $progress_current/$progress_total)]($style)) ";
        style = "bold #df8e1d";
      };

      git_metrics = {
        disabled = false;
        format = "([+$added]($added_style) )([-$deleted]($deleted_style) )";
        added_style = "bold #40a02b";
        deleted_style = "bold #d20f39";
      };

      # Jujutsu (jj): workspace name (always), nearest bookmark, and state flags.
      # Coexists with the git_* modules above — in colocated repos you will see
      # both the git branch and the jj bookmark, by design. The helper script
      # (defined in the `let` block above) does its own repo detection, so no
      # detect_folders is needed and it works in subdirectories like git does.
      custom.jj = {
        command = "${jjPrompt}";
        shell = [ "${pkgs.bash}/bin/bash" "--noprofile" "--norc" ];
        when = true;
        use_stdin = false;
        format = "[$output]($style)";
        style = "bold #ea76cb";
        ignore_timeout = true;
      };

      # Languages and tools
      nodejs = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold #40a02b";
        not_capable_style = "bold #d20f39";
        detect_extensions = [ "js" "mjs" "cjs" "ts" "mts" "cts" ];
        detect_files = [ "package.json" ".node-version" ".nvmrc" ];
        detect_folders = [ "node_modules" ];
      };

      python = {
        format = "[\${symbol}\${pyenv_prefix}(\${version} )(\\($virtualenv\\) )]($style)";
        symbol = " ";
        style = "bold #df8e1d";
        pyenv_version_name = true;
        pyenv_prefix = "pyenv ";
        detect_extensions = [ "py" ];
        detect_files = [ ".python-version" "Pipfile" "__pycache__" "pyproject.toml" "requirements.txt" "setup.py" "tox.ini" ];
        detect_folders = [ ];
      };

      rust = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold #fe640b";
        detect_extensions = [ "rs" ];
        detect_files = [ "Cargo.toml" ];
        detect_folders = [ ];
      };

      golang = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold #179299";
        detect_extensions = [ "go" ];
        detect_files = [ "go.mod" "go.sum" "glide.yaml" "Gopkg.yml" "Gopkg.lock" ".go-version" ];
        detect_folders = [ "Godeps" ];
      };

      docker_context = {
        format = "[$symbol$context]($style) ";
        symbol = " ";
        style = "#1e66f5 bold";
        only_with_files = true;
        detect_extensions = [ ];
        detect_files = [ "docker-compose.yml" "docker-compose.yaml" "Dockerfile" ];
        detect_folders = [ ];
      };

      kubernetes = {
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        symbol = "󱃾 ";
        style = "#04a5e5 bold";
        disabled = false;
      };

      terraform = {
        format = "[$symbol$workspace]($style) ";
        symbol = "󱁢 ";
        style = "bold #8839ef";
        detect_extensions = [ "tf" "tfplan" "tfstate" ];
        detect_files = [ ];
        detect_folders = [ ".terraform" ];
      };

      aws = {
        format = "[$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
        symbol = " ";
        style = "bold #fe640b";
      };

      # Other modules
      cmd_duration = {
        format = "[ $duration]($style)";
        style = "bold #df8e1d";
        min_time = 2000;
        show_milliseconds = false;
      };

      jobs = {
        format = "[$symbol$number]($style) ";
        symbol = "✨";
        style = "bold #8839ef";
        number_threshold = 1;
      };

      time = {
        format = "[$time]($style) ";
        style = "bold dimmed #dc8a78";
        disabled = false;
        time_format = "%R";
      };

      line_break = {
        disabled = false;
      };

      fill = {
        symbol = " ";
      };

      # Disabled modules
      package = {
        disabled = true;
      };

      battery = {
        disabled = true;
      };

      memory_usage = {
        disabled = true;
      };

      # Nix shell
      nix_shell = {
        format = "[$symbol$state( \\($name\\))]($style) ";
        symbol = " ";
        style = "bold blue";
      };
    };
  };
}
