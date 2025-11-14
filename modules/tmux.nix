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

      # Status bar configuration (Catppuccin Latte)
      set -g status-position top
      set -g status-style "bg=#eff1f5 fg=#4c4f69"
      set -g status-left-length 60
      set -g status-right-length 60

      # Status left
      set -g status-left "#[fg=#eff1f5,bg=#1e66f5,bold] #S #[fg=#1e66f5,bg=#eff1f5,nobold]"

      # Status right
      set -g status-right "#[fg=#ccd0da,bg=#eff1f5]#[fg=#4c4f69,bg=#ccd0da] %Y-%m-%d #[fg=#bcc0cc,bg=#ccd0da]#[fg=#4c4f69,bg=#bcc0cc] %H:%M #[fg=#1e66f5,bg=#bcc0cc]#[fg=#eff1f5,bg=#1e66f5,bold] #h "

      # Window status
      set -g window-status-format "#[fg=#eff1f5,bg=#ccd0da] #I #[fg=#4c4f69,bg=#e6e9ef] #W "
      set -g window-status-current-format "#[fg=#eff1f5,bg=#1e66f5,bold] #I #[fg=#eff1f5,bg=#7287fd,bold] #W#{?window_zoomed_flag, 󰊓,} "
      set -g window-status-separator ""

      # Pane borders
      set -g pane-border-style "fg=#ccd0da"
      set -g pane-active-border-style "fg=#1e66f5"

      # Message style
      set -g message-style "fg=#4c4f69 bg=#e6e9ef bold"

      # Plugin settings
      set -g @resurrect-capture-pane-contents "on"
      set -g @continuum-restore "on"
      set -g @continuum-save-interval "10"
    '';
  };
}
