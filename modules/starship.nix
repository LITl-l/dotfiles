{ config, pkgs, lib, ... }:

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
        "[┌](bold green) "
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$git_state"
        "$git_metrics"
        "$fill"
        "$all"
        "$line_break"
        "[└](bold green) "
        "$character"
      ];

      # Right prompt
      right_format = "$cmd_duration$jobs$time";

      # Prompt character
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vicmd_symbol = "[❮](bold green)";
      };

      # Username
      username = {
        show_always = false;
        format = "[$user]($style) ";
        style_user = "bold blue";
        style_root = "bold red";
      };

      # Hostname
      hostname = {
        ssh_only = true;
        format = "[@$hostname]($style) ";
        style = "bold green";
      };

      # Directory
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold cyan";
        read_only = " 󰌾";
        read_only_style = "red";
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
        style = "bold purple";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "bold red";
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
        style = "bold yellow";
      };

      git_metrics = {
        disabled = false;
        format = "([+$added]($added_style) )([-$deleted]($deleted_style) )";
        added_style = "bold green";
        deleted_style = "bold red";
      };

      # Languages and tools
      nodejs = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold green";
        detect_extensions = [ "js" "mjs" "cjs" "ts" "mts" "cts" ];
        detect_files = [ "package.json" ".node-version" ".nvmrc" ];
        detect_folders = [ "node_modules" ];
      };

      python = {
        format = "[\${symbol}\${pyenv_prefix}(\${version} )(\\($virtualenv\\) )]($style)";
        symbol = " ";
        style = "bold yellow";
        pyenv_version_name = true;
        pyenv_prefix = "pyenv ";
        detect_extensions = [ "py" ];
        detect_files = [ ".python-version" "Pipfile" "pyproject.toml" "requirements.txt" "setup.py" "tox.ini" ];
      };

      rust = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold red";
        detect_extensions = [ "rs" ];
        detect_files = [ "Cargo.toml" ];
      };

      golang = {
        format = "[$symbol($version )]($style)";
        symbol = " ";
        style = "bold cyan";
        detect_extensions = [ "go" ];
        detect_files = [ "go.mod" "go.sum" "glide.yaml" "Gopkg.yml" "Gopkg.lock" ".go-version" ];
        detect_folders = [ "Godeps" ];
      };

      docker_context = {
        format = "[$symbol$context]($style) ";
        symbol = " ";
        style = "blue bold";
        only_with_files = true;
        detect_files = [ "docker-compose.yml" "docker-compose.yaml" "Dockerfile" ];
      };

      kubernetes = {
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        symbol = "󱃾 ";
        style = "cyan bold";
        disabled = false;
      };

      terraform = {
        format = "[$symbol$workspace]($style) ";
        symbol = "󱁢 ";
        style = "bold purple";
        detect_extensions = [ "tf" "tfplan" "tfstate" ];
        detect_folders = [ ".terraform" ];
      };

      aws = {
        format = "[$symbol($profile )(\\($region\\) )(\\[$duration\\] )]($style)";
        symbol = " ";
        style = "bold orange";
      };

      # Other modules
      cmd_duration = {
        format = "[ $duration]($style)";
        style = "bold yellow";
        min_time = 2000;
        show_milliseconds = false;
      };

      jobs = {
        format = "[$symbol$number]($style) ";
        symbol = "✦";
        style = "bold blue";
        number_threshold = 1;
      };

      time = {
        format = "[$time]($style) ";
        style = "bold dimmed white";
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
