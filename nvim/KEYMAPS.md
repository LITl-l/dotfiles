# Neovim Keybindings Reference

Leader key: `<Space>`

## Navigation

| Key | Mode | Description |
|-----|------|-------------|
| `j/k` | n, x | Better up/down (respects wrapped lines) |
| `<C-h/j/k/l>` | n | Move to window (left/down/up/right) |
| `<C-h/j/k/l>` | t | Move to window from terminal |
| `<S-h>` | n | Previous buffer |
| `<S-l>` | n | Next buffer |
| `[b` / `]b` | n | Previous/Next buffer |
| `<leader>bb` | n | Switch to other buffer |

## File Operations

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>e` | n | Open file explorer |
| `<leader>E` | n | Open explorer at current file |
| `<leader>w` | n | Save file |
| `<leader>W` | n | Save all files |
| `<C-s>` | i, n, x, s | Save file |
| `<leader>q` | n | Quit |
| `<leader>Q` | n | Quit without saving |
| `<leader>qq` | n | Quit all |
| `<leader>fn` | n | New file |

## Fuzzy Finder (mini.pick)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>ff` | n | Find files |
| `<leader>fg` | n | Live grep |
| `<leader>fb` | n | Find buffers |
| `<leader>fh` | n | Find help |
| `<leader>fr` | n | Recent files |
| `<leader>fd` | n | Find diagnostics |
| `<leader>fk` | n | Find keymaps |
| `<leader>fc` | n | Find commands |
| `<leader>fm` | n | Find marks |
| `<leader>fo` | n | Find options |

## LSP

| Key | Mode | Description |
|-----|------|-------------|
| `gd` | n | Go to definition |
| `gr` | n | Go to references |
| `gI` | n | Go to implementation |
| `gD` | n | Go to declaration |
| `K` | n | Hover documentation |
| `<leader>D` | n | Type definition |
| `<leader>ds` | n | Document symbols |
| `<leader>ws` | n | Workspace symbols |
| `<leader>rn` | n | Rename symbol |
| `<leader>ca` | n | Code action |
| `<leader>cf` | n, v | Code format |
| `<leader>wa` | n | Add workspace folder |
| `<leader>wr` | n | Remove workspace folder |
| `<leader>wl` | n | List workspace folders |

## Diagnostics

| Key | Mode | Description |
|-----|------|-------------|
| `[d` | n | Previous diagnostic |
| `]d` | n | Next diagnostic |
| `<leader>e` | n | Open floating diagnostic |
| `<leader>q` | n | Open diagnostics list |

## Editing

| Key | Mode | Description |
|-----|------|-------------|
| `<A-j>` | n, i, v | Move line down |
| `<A-k>` | n, i, v | Move line up |
| `<` / `>` | v | Indent left/right (keeps selection) |
| `<Esc>` | i, n | Clear search highlight |
| `<leader>sr` | n | Search and replace word under cursor |

## Windows & Splits

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>-` | n | Split window below |
| `<leader>\|` | n | Split window right |
| `<leader>ww` | n | Other window |
| `<leader>wd` | n | Delete window |
| `<C-Up/Down>` | n | Increase/Decrease window height |
| `<C-Left/Right>` | n | Decrease/Increase window width |

## Tabs

| Key | Mode | Description |
|-----|------|-------------|
| `<leader><tab><tab>` | n | New tab |
| `<leader><tab>]` | n | Next tab |
| `<leader><tab>[` | n | Previous tab |
| `<leader><tab>l` | n | Last tab |
| `<leader><tab>f` | n | First tab |
| `<leader><tab>d` | n | Close tab |

## Toggles

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>uf` | n | Toggle format on save |
| `<leader>us` | n | Toggle spelling |
| `<leader>uw` | n | Toggle word wrap |
| `<leader>ul` | n | Toggle list chars |
| `<leader>un` | n | Toggle line numbers |
| `<leader>ur` | n | Toggle relative numbers |

## Treesitter (Incremental Selection)

| Key | Mode | Description |
|-----|------|-------------|
| `<C-Space>` | n | Start incremental selection |
| `<C-Space>` | x | Expand selection to parent node |
| `<BS>` | x | Shrink selection to child node |

## Snippets (LuaSnip)

| Key | Mode | Description |
|-----|------|-------------|
| `<C-k>` | i, s | Expand or jump to next snippet |
| `<C-j>` | i, s | Jump to previous snippet |
| `<C-l>` | i, s | Cycle through choices |

## Debugger (DAP)

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>db` | n | Toggle breakpoint |
| `<leader>dB` | n | Conditional breakpoint |
| `<leader>dc` | n | Continue |
| `<leader>di` | n | Step into |
| `<leader>do` | n | Step over |
| `<leader>dO` | n | Step out |
| `<leader>dr` | n | Open REPL |
| `<leader>dl` | n | Run last |
| `<leader>dx` | n | Terminate |
| `<leader>du` | n | Toggle DAP UI |
| `<leader>de` | n, v | Eval expression |

## Terminal

| Key | Mode | Description |
|-----|------|-------------|
| `<Esc><Esc>` | t | Enter normal mode |
| `<C-/>` | t | Hide terminal |

## Mini.nvim Plugins

### mini.surround
- `sa` - Add surrounding
- `sd` - Delete surrounding
- `sr` - Replace surrounding
- `sf` - Find surrounding (forward)
- `sF` - Find surrounding (backward)
- `sh` - Highlight surrounding

### mini.comment
- `gc` - Toggle comment (works with motion)
- `gcc` - Toggle comment on line

### mini.splitjoin
- `gS` - Toggle split/join

## Commands

| Command | Description |
|---------|-------------|
| `:Format` | Format buffer or range |
| `:FormatDisable` | Disable format on save (buffer) |
| `:FormatDisable!` | Disable format on save (global) |
| `:FormatEnable` | Enable format on save |
| `:LspServers` | Show enabled LSP servers |
