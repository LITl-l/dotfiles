# dotfiles

This repository contains personal configuration files for various tools.

## Wezterm

This configuration sets up the [Wezterm](https://wezfurlong.org/wezterm/) terminal emulator with:
- Fira Code font
- Gruvbox Dark color scheme
- Ctrl+Shift+C for copy, Ctrl+Shift+V for paste

### Installation

1.  **Install Wezterm**: Follow the instructions on the [official Wezterm installation page](https://wezfurlong.org/wezterm/installation.html).
2.  **Install Fira Code font**: Download and install "Fira Code" font from [Nerd Fonts](https://www.nerdfonts.com/font-downloads) or other sources. Ensure it's available to your system.
3.  **Place the configuration file**:
    ```bash
    mkdir -p ~/.config/wezterm
    cp .config/wezterm/wezterm.lua ~/.config/wezterm/
    ```
    (If you use a different `$XDG_CONFIG_HOME`, replace `~/.config` accordingly).

## Neovim

This configuration sets up [Neovim](https://neovim.io/) with:
- `lazy.nvim` for plugin management
- Tokyonight theme
- Basic keymappings (e.g., `<Space>w` to save, `<Space>q` to quit)

### Installation

1.  **Install Neovim**: Follow the instructions on the [official Neovim installation page](https://github.com/neovim/neovim/wiki/Installing-Neovim). Version 0.8+ is recommended.
2.  **Install `git`**: `lazy.nvim` and many plugins are installed using `git`. If you don't have it, install it using your system's package manager (e.g., `sudo apt install git` on Debian/Ubuntu, `brew install git` on macOS).
3.  **Place the configuration file**:
    ```bash
    mkdir -p ~/.config/nvim
    cp .config/nvim/init.lua ~/.config/nvim/
    ```
    (If you use a different `$XDG_CONFIG_HOME`, replace `~/.config` accordingly).
4.  **Install plugins**: The first time you launch Neovim (`nvim`), `lazy.nvim` will automatically install the configured plugins. You can also run `:Lazy sync` inside Neovim to manage plugins.