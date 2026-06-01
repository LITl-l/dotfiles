# Neovim Startup Performance Design

## Goal

Make Neovim feel faster on launch while keeping the file explorer available from `<leader>e` in every buffer.

## Scope

- Preserve the existing mini.nvim-based setup.
- Optimize empty `nvim` startup and common file-open startup.
- Keep `<leader>e` and `<leader>E` dedicated to `mini.files`.
- Move LSP line diagnostics away from `<leader>e`.
- Keep package changes limited to Neovim startup support, LSP defaults, and automated verification.

## Design

Startup should load only core editor settings, keymaps, autocmd definitions, the active monochrome colorscheme, lightweight mini UI components, and enough lazy trigger functions to load tools on demand. Heavy Nix-managed plugins should be installed as optional packages and loaded with `:packadd` from events or keypresses: file explorer on `<leader>e`, picker on `<leader>f*` and LSP symbol keys, completion/snippets/pairs on `InsertEnter`, LSP/formatting/git helpers when editing real files, and DAP on debug key usage.

The plugin configuration module will expose idempotent setup helpers so each feature initializes once. Keymaps will call helper functions instead of assuming plugins were loaded during startup.

## Keymap changes

- `<leader>e`: open `mini.files` at the current working directory.
- `<leader>E`: open `mini.files` at the current file.
- `<leader>cd`: show line diagnostics with Lspsaga after LSP attaches.
- `<leader>e` will not be remapped by LSP buffer-local mappings.

## Performance changes

- Enable Neovim's Lua module cache with `vim.loader.enable()` when available.
- Remove global Treesitter fold expression from startup; configure Treesitter folds buffer-locally after parser startup and keep folding disabled by default.
- Apply the active local monochrome colorscheme directly; configure Catppuccin only before selecting Catppuccin.
- Avoid loading starter/session/DAP/snippet/picker/LSP modules during empty startup.

## Verification

- Add a headless Lua regression test that fails if `<leader>e` does not call the file explorer helper before and after a synthetic `LspAttach` event.
- Wire the Neovim regression test into `nix flake check` for x86_64-linux.
- Run headless startup smoke tests.
- Compare `nvim --startuptime` before and after the optimization.
- Run `nix flake check` and `home-manager switch --flake .` from the workspace.
