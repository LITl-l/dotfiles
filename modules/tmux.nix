{ config, pkgs, lib, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 50000;
    baseIndex = 1;
    keyMode = "vi";
    escapeTime = 0;
    mouse = true;
    shell = "${pkgs.fish}/bin/fish";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
      vim-tmux-navigator
    ];

    extraConfig = ''
      # Set prefix to Ctrl-a
      unbind C-b
      set-option -g prefix C-a
      bind-key C-a send-prefix

      # Terminal overrides
      set -ga terminal-overrides ",*256col*:Tc"

      # Display time
      set -g display-time 4000

      # Status interval
      set -g status-interval 5

      # Focus events
      set -g focus-events on

      # Aggressive resize
      setw -g aggressive-resize on

      # Renumber windows
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Vi-style copy mode
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Split panes using | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"

      # Switch panes using vim keys
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes using vim keys
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Maximize pane
      bind -r m resize-pane -Z

      # Window navigation
      bind -r C-h previous-window
      bind -r C-l next-window
      bind Tab last-window

      # Status bar configuration (Catppuccin Mocha)
      set -g status-position top
      set -g status-style "bg=#1e1e2e fg=#cdd6f4"
      set -g status-left-length 60
      set -g status-right-length 60

      # Status left
      set -g status-left "#[fg=#1e1e2e,bg=#89b4fa,bold] #S #[fg=#89b4fa,bg=#1e1e2e,nobold]"

      # Status right
      set -g status-right "#[fg=#45475a,bg=#1e1e2e]#[fg=#cdd6f4,bg=#45475a] %Y-%m-%d #[fg=#585b70,bg=#45475a]#[fg=#cdd6f4,bg=#585b70] %H:%M #[fg=#89b4fa,bg=#585b70]#[fg=#1e1e2e,bg=#89b4fa,bold] #h "

      # Window status
      set -g window-status-format "#[fg=#1e1e2e,bg=#45475a] #I #[fg=#cdd6f4,bg=#313244] #W "
      set -g window-status-current-format "#[fg=#1e1e2e,bg=#89b4fa,bold] #I #[fg=#1e1e2e,bg=#a6adc8,bold] #W#{?window_zoomed_flag, 󰊓,} "
      set -g window-status-separator ""

      # Pane borders
      set -g pane-border-style "fg=#45475a"
      set -g pane-active-border-style "fg=#89b4fa"

      # Message style
      set -g message-style "fg=#cdd6f4 bg=#313244 bold"

      # Plugin settings
      set -g @resurrect-capture-pane-contents "on"
      set -g @continuum-restore "on"
      set -g @continuum-save-interval "10"
    '';
  };
}
