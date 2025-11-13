{ config, pkgs, lib, ... }:

{
  # Yazi file manager configuration
  # This configuration is managed by home-manager and generates read-only files
  # in ~/.config/yazi/ to ensure declarative configuration management.
  #
  # Note: Yazi deprecated 'manager' in favor of 'mgr' (see yazi PR #2803)
  # Using the new syntax prevents auto-migration warnings.
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    # Yazi settings
    settings = {
      # Manager settings (formerly 'manager', now 'mgr' as of yazi PR #2803)
      mgr = {
        # Layout: [parent_width, current_width, preview_width] ratios
        # Determines column widths in the 3-pane layout
        layout = [ 1 4 3 ];

        # Sorting configuration
        sort_by = "natural";        # Natural sorting (foo1, foo2, foo10)
        sort_sensitive = false;     # Case-insensitive sorting
        sort_reverse = false;       # Ascending order
        sort_dir_first = true;      # Directories before files

        # Display settings
        linemode = "size";          # Show file sizes in the listing
        show_hidden = false;        # Hide dotfiles by default (toggle with '.')
        show_symlink = true;        # Show symbolic link targets

        # Navigation: Keep cursor this many lines from top/bottom
        scrolloff = 5;
      };

      # File preview configuration
      preview = {
        tab_size = 2;               # Tab width for text file previews
        max_width = 600;            # Maximum preview width in pixels
        max_height = 900;           # Maximum preview height in pixels
        cache_dir = "${config.xdg.cacheHome}/yazi";  # Preview cache location
      };

      # File opener definitions
      # Define how different file types should be opened
      opener = {
        edit = [
          { run = "nvim \"$@\""; block = true; }  # Open in nvim, block until closed
        ];
        play = [
          { run = "mpv \"$@\""; orphan = true; }  # Play media, detach from yazi
        ];
        open = [
          { run = "xdg-open \"$@\""; desc = "Open"; }  # Use system default opener
        ];
      };

      # Rules for which opener to use based on file type
      open = {
        rules = [
          { name = "*/"; use = "edit"; }          # Directories
          { mime = "text/*"; use = "edit"; }      # Text files
          { mime = "image/*"; use = "open"; }     # Images with system viewer
          { mime = "video/*"; use = "play"; }     # Videos in mpv
          { mime = "audio/*"; use = "play"; }     # Audio in mpv
        ];
      };
    };

    # Keybindings
    # Custom keybindings for vim-like navigation and operations
    keymap = {
      mgr.prepend_keymap = [
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
    # Color scheme for different file types in the listing
    theme = {
      filetype = {
        rules = [
          # Media files
          { mime = "image/*"; fg = "cyan"; }      # Images in cyan
          { mime = "video/*"; fg = "yellow"; }    # Videos in yellow
          { mime = "audio/*"; fg = "magenta"; }   # Audio in magenta

          # Compressed archives in red
          { mime = "application/zip"; fg = "red"; }
          { mime = "application/gzip"; fg = "red"; }
          { mime = "application/x-tar"; fg = "red"; }
          { mime = "application/x-bzip"; fg = "red"; }
          { mime = "application/x-7z-compressed"; fg = "red"; }
          { mime = "application/x-rar"; fg = "red"; }

          # Documents
          { mime = "application/pdf"; fg = "green"; }  # PDFs in green

          # Code and text files in blue
          { mime = "text/*"; fg = "blue"; }
        ];
      };
    };
  };

  # Additional packages for enhanced yazi functionality
  # These packages enable rich previews for various file types
  home.packages = with pkgs; [
    ffmpegthumbnailer  # Generate video thumbnails in preview pane
    unar               # Preview and extract archive contents
    poppler-utils      # PDF text extraction and preview (pdftotext, pdfinfo)
    imagemagick        # Image format conversion and manipulation
  ];
}

