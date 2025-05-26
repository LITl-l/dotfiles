# dotfiles

This repository contains personal configuration files for various tools.

## Wezterm

This configuration sets up the [Wezterm](https://wezfurlong.org/wezterm/) terminal emulator with:
- Cica font
- Gruvbox Dark color scheme
- Ctrl+Shift+C for copy, Ctrl+Shift+V for paste

### Installation

1.  **Install Wezterm**: Follow the instructions on the [official Wezterm installation page](https://wezfurlong.org/wezterm/installation.html).
2.  **Install Cica font**: Download the latest release of "Cica" font from the [official GitHub repository](https://github.com/miiton/Cica/releases/latest). Extract the archive and install the font files (e.g., by moving them to `~/.local/share/fonts` on Linux or `~/Library/Fonts` on macOS, or by using your system's font installer). Ensure it's available to your system.
3.  **Place the configuration file**:
    ```bash
    mkdir -p ~/.config/wezterm
    cp .config/wezterm/wezterm.lua ~/.config/wezterm/
    ```
    (If you use a different `$XDG_CONFIG_HOME`, replace `~/.config` accordingly).

## Neovim

This configuration sets up [Neovim](https://neovim.io/) with:
- `mini.nvim` (specifically `mini.deps`) for plugin management.
- A custom dark, futuristic theme via `mini.hues` (part of `mini.nvim`).
- Basic keymappings (e.g., `<Space>w` to save, `<Space>q` to quit).

### Installation

1.  **Install Neovim**: Follow the instructions on the [official Neovim installation page](https://github.com/neovim/neovim/wiki/Installing-Neovim). Version 0.8+ is recommended.
2.  **Install `git`**: `mini.nvim` and its module `mini.deps` use `git` to clone and manage plugins. If you don't have it, install it using your system's package manager (e.g., `sudo apt install git` on Debian/Ubuntu, `brew install git` on macOS).
3.  **Place the configuration file**:
    ```bash
    mkdir -p ~/.config/nvim
    cp .config/nvim/init.lua ~/.config/nvim/
    # If you want to copy the entire lua subdirectory as well:
    # cp -r .config/nvim/lua ~/.config/nvim/
    ```
    (If you use a different `$XDG_CONFIG_HOME`, replace `~/.config` accordingly).
    The main configuration file is `init.lua`. It includes a script to install `mini.nvim` itself. It then loads modularized settings from files located in the `.config/nvim/lua/` directory (e.g., `plugins.lua` for plugin management using `mini.deps`, `options.lua` for editor settings and `mini.hues` theme configuration, and `keymaps.lua` for keybindings). You'll need to copy the `lua` subdirectory as well if you are copying files manually.
4.  **Install plugins**: `mini.nvim` itself is cloned and installed by a script in `init.lua` the first time you launch Neovim. Other plugins, managed by `mini.deps` (as defined in `lua/plugins.lua`), are typically installed automatically when Neovim starts and detects they are missing. You can also use commands provided by `mini.deps` if you need to manage dependencies manually (refer to `mini.deps` documentation for details).