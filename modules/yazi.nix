{ config, pkgs, lib, ... }:

{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    # Yazi settings
    settings = {
      manager = {
        # Layout
        layout = [ 1 4 3 ];
        sort_by = "natural";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
        linemode = "size";
        show_hidden = false;
        show_symlink = true;

        # Scrolloff
        scrolloff = 5;
      };

      preview = {
        # Preview settings
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        cache_dir = "${config.xdg.cacheHome}/yazi";
      };

      # Opener integration
      opener = {
        edit = [
          { run = "nvim \"$@\""; block = true; }
        ];
        play = [
          { run = "mpv \"$@\""; orphan = true; }
        ];
        open = [
          { run = "xdg-open \"$@\""; desc = "Open"; }
        ];
      };

      open = {
        rules = [
          { name = "*/"; use = "edit"; }
          { mime = "text/*"; use = "edit"; }
          { mime = "image/*"; use = "open"; }
          { mime = "video/*"; use = "play"; }
          { mime = "audio/*"; use = "play"; }
        ];
      };
    };

    # Keybindings
    keymap = {
      manager.prepend_keymap = [
        # Navigation
        { on = [ "h" ]; run = "leave"; desc = "Go back"; }
        { on = [ "l" ]; run = "enter"; desc = "Enter directory"; }
        { on = [ "k" ]; run = "arrow -1"; desc = "Move up"; }
        { on = [ "j" ]; run = "arrow 1"; desc = "Move down"; }

        # Jump
        { on = [ "g" "g" ]; run = "arrow -99999999"; desc = "Jump to top"; }
        { on = [ "G" ]; run = "arrow 99999999"; desc = "Jump to bottom"; }

        # Selection
        { on = [ "<Space>" ]; run = "select --state=none"; desc = "Toggle selection"; }
        { on = [ "v" ]; run = "visual_mode"; desc = "Enter visual mode"; }
        { on = [ "V" ]; run = "visual_mode --unset"; desc = "Exit visual mode"; }

        # Operations
        { on = [ "y" "y" ]; run = "yank"; desc = "Copy"; }
        { on = [ "x" "x" ]; run = "yank --cut"; desc = "Cut"; }
        { on = [ "p" ]; run = "paste"; desc = "Paste"; }
        { on = [ "P" ]; run = "paste --force"; desc = "Paste (overwrite)"; }
        { on = [ "d" "d" ]; run = "remove"; desc = "Delete"; }
        { on = [ "D" ]; run = "remove --permanently"; desc = "Delete permanently"; }

        # Create
        { on = [ "a" ]; run = "create"; desc = "Create file/dir"; }
        { on = [ "r" ]; run = "rename"; desc = "Rename"; }

        # Hidden files
        { on = [ "." ]; run = "hidden toggle"; desc = "Toggle hidden files"; }

        # Search
        { on = [ "/" ]; run = "find"; desc = "Find"; }
        { on = [ "?" ]; run = "find --previous"; desc = "Find previous"; }
        { on = [ "n" ]; run = "find_arrow"; desc = "Next match"; }
        { on = [ "N" ]; run = "find_arrow --previous"; desc = "Previous match"; }

        # Shell
        { on = [ "!" ]; run = "shell"; desc = "Run shell command"; }

        # Help
        { on = [ "~" ]; run = "help"; desc = "Show help"; }

        # Quit
        { on = [ "q" ]; run = "quit"; desc = "Quit"; }
        { on = [ "Q" ]; run = "quit --no-cwd-file"; desc = "Quit without cd"; }
      ];
    };

    # Theme configuration
    theme = {
      # File type colors
      filetype = {
        rules = [
          # Images
          { mime = "image/*"; fg = "cyan"; }
          # Videos
          { mime = "video/*"; fg = "yellow"; }
          # Audio
          { mime = "audio/*"; fg = "magenta"; }
          # Archives
          { mime = "application/zip"; fg = "red"; }
          { mime = "application/gzip"; fg = "red"; }
          { mime = "application/x-tar"; fg = "red"; }
          { mime = "application/x-bzip"; fg = "red"; }
          { mime = "application/x-7z-compressed"; fg = "red"; }
          { mime = "application/x-rar"; fg = "red"; }
          # Documents
          { mime = "application/pdf"; fg = "green"; }
          # Code
          { mime = "text/*"; fg = "blue"; }
        ];
      };
    };
  };

  # Additional packages for yazi functionality
  home.packages = with pkgs; [
    # Preview dependencies
    ffmpegthumbnailer  # Video thumbnails
    unar               # Archive preview
    poppler_utils      # PDF preview
    imagemagick        # Image operations
  ];
}
