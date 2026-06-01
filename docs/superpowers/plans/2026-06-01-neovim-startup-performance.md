# Neovim Startup Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Neovim launch faster and keep `<leader>e` opening the file explorer in all buffers.

**Architecture:** Keep the existing mini.nvim configuration, but split eager setup into idempotent lazy helpers. Keymaps call helper functions that initialize their feature on first use. LSP no longer shadows the file explorer keymap.

**Tech Stack:** Neovim Lua config, mini.nvim, Lspsaga, Nix/Home Manager, Jujutsu.

---

### Task 1: Add keymap regression test

**Files:**
- Create: `nvim/tests/leader_e_minifiles.lua`

- [ ] **Step 1: Write the failing test**

```lua
local plugins = require('config.plugins')

assert(type(plugins.open_files) == 'function', 'config.plugins.open_files must exist')

local function assert_open_files_loads_minifiles()
  local ok, err = pcall(function()
    plugins.open_files()
  end)

  assert(ok, 'config.plugins.open_files() errored: ' .. tostring(err))
  assert(_G.MiniFiles and type(MiniFiles.open) == 'function', 'MiniFiles.open was not loaded')

  if type(MiniFiles.close) == 'function' then
    pcall(MiniFiles.close)
  end
end

local function assert_map_invokes_file_explorer(lhs, expected_path, label)
  local call = { seen = false, path = nil }
  local original = plugins.open_files

  plugins.open_files = function(path)
    call.seen = true
    call.path = path
  end

  local ok, err = pcall(function()
    vim.api.nvim_feedkeys(vim.keycode(lhs), 'xt', false)
  end)

  plugins.open_files = original

  assert(ok, label .. ': pressing ' .. lhs .. ' errored: ' .. tostring(err))
  assert(call.seen, label .. ': ' .. lhs .. ' did not invoke config.plugins.open_files(); effective map = ' .. vim.inspect(vim.fn.maparg(lhs, 'n', false, true)))
  assert(call.path == expected_path, label .. ': ' .. lhs .. ' passed path ' .. vim.inspect(call.path) .. ', expected ' .. vim.inspect(expected_path))
end

local function assert_file_explorer_maps(label)
  assert_map_invokes_file_explorer('<leader>e', nil, label)
  assert_map_invokes_file_explorer('<leader>E', vim.api.nvim_buf_get_name(0), label)
end

assert_open_files_loads_minifiles()
assert_file_explorer_maps('startup')

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_exec_autocmds('LspAttach', {
  buffer = buf,
  data = { client_id = 1 },
})

assert_file_explorer_maps('after LspAttach')
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
XDG_CONFIG_HOME="$PWD" nvim --headless +'luafile nvim/tests/leader_e_minifiles.lua' +'qa!'
```

Expected: FAIL with `config.plugins.open_files must exist` on the pre-implementation config.

### Task 2: Split Neovim startup and lazy helpers

**Files:**
- Modify: `nvim/init.lua`
- Modify: `nvim/lua/config/plugins.lua`
- Modify: `nvim/lua/config/options.lua`
- Modify: `modules/neovim.nix`

- [ ] **Step 1: Implement lazy setup helpers**

Add idempotent helpers in `nvim/lua/config/plugins.lua`:

```lua
local loaded = {}
local function setup_once(name, callback)
  if loaded[name] then return end
  loaded[name] = true
  callback()
end
```

Expose helpers including `setup_core`, `setup_files`, `open_files`, `setup_editing`, `setup_completion`, `setup_picker`, `pick`, `pick_lsp`, `setup_git`, `setup_colorscheme`, `apply_colorscheme`, `setup_treesitter`, `setup_lspsaga`, `setup_lsp`, `setup_format`, and `setup_dap`.

- [ ] **Step 2: Update startup orchestration**

In `nvim/init.lua`, enable `vim.loader`, load options/keymaps/autocmds, initialize `mini.deps`, configure core plugins and colorscheme immediately, then register lazy keymaps/autocmds:

```lua
if vim.loader then
  vim.loader.enable()
end

plugins.setup_core()
plugins.setup_colorscheme()
plugins.setup_treesitter()

vim.keymap.set('n', '<leader>e', function() plugins.open_files() end, { desc = 'Open file explorer' })
vim.keymap.set('n', '<leader>E', function() plugins.open_files(vim.api.nvim_buf_get_name(0)) end, { desc = 'Open file explorer at current file' })
```

Use `InsertEnter` for completion/snippets/editing, `BufReadPre`/`BufNewFile` for LSP/format/git, `vim.defer_fn` for which-key, and lazy debug keymaps for DAP. Add `mini-nvim` to `modules/neovim.nix` so Nix-managed Neovim does not need a network bootstrap for mini.nvim, and mark heavy plugins optional so helpers load them with `:packadd` on demand.

- [ ] **Step 3: Remove global Treesitter folds**

In `nvim/lua/config/options.lua`, change global folding defaults to manual and disabled:

```lua
vim.opt.foldmethod = 'manual'
vim.opt.foldtext = ''
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = false
```

Configure Treesitter folds buffer-locally in `setup_treesitter()` after a parser starts.

- [ ] **Step 4: Run regression test to verify it passes**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
XDG_CONFIG_HOME="$PWD" nvim --headless +'luafile nvim/tests/leader_e_minifiles.lua' +'qa!'
```

Expected: PASS with exit code 0 and no output.

### Task 3: Move diagnostics key and update docs

**Files:**
- Modify: `nvim/lua/config/autocmds.lua`
- Modify: `nvim/lua/config/keymaps.lua`
- Modify: `nvim/KEYMAPS.md`
- Modify: `nvim/README.md`

- [ ] **Step 1: Move LSP diagnostic keymap**

Change the LSP attach mapping from:

```lua
map('<leader>e', '<cmd>Lspsaga show_line_diagnostics<cr>', 'Line Diagnostics')
```

to:

```lua
map('<leader>cd', '<cmd>Lspsaga show_line_diagnostics<cr>', 'Line Diagnostics')
```

Change the global diagnostics list keymap from `<leader>q` to `<leader>cl` so `<leader>q` keeps its documented quit behavior.

- [ ] **Step 2: Update keymap documentation**

Document `<leader>cd` as line diagnostics, `<leader>cl` as the diagnostics list, and keep `<leader>e` documented only as the file explorer.

- [ ] **Step 3: Run regression test again**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
XDG_CONFIG_HOME="$PWD" nvim --headless +'luafile nvim/tests/leader_e_minifiles.lua' +'qa!'
```

Expected: PASS with exit code 0 and no output.

### Task 4: Verify startup and flake

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add Neovim config flake check**

Add an x86_64-linux `nvim-config-tests` check in `flake.nix` that uses `self.homeConfigurations."nixos@wsl".config.programs.neovim.finalPackage` and runs:

```bash
nvim --headless +'luafile nvim/tests/leader_e_minifiles.lua' +'qa!'
nvim --headless nvim/init.lua +'lua assert(vim.fn.exists(":LspServers") == 2, "LspServers command missing"); local cfg = vim.lsp.config.lua_ls; assert(cfg and type(cfg.cmd) == "table" and #cfg.cmd > 0, "lua_ls cmd missing"); assert(vim.fn.maparg("<leader>l", "n") == "", "<leader>l maps to missing Lazy command")' +'qa!'
```

- [ ] **Step 2: Run startup smoke test**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
XDG_CONFIG_HOME="$PWD" nvim --headless +qa
```

Expected: PASS with exit code 0.

- [ ] **Step 3: Measure startup time**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
for i in $(seq 1 10); do
  log="$tmpdir/startup-$i.log"
  XDG_CONFIG_HOME="$PWD" nvim --headless --startuptime "$log" +qa >/dev/null 2>&1
  awk '/NVIM STARTED/ { print $1 }' "$log"
done | sort -n | awk '{ a[NR] = $1 } END { mid = int((NR + 1) / 2); printf("runs=%d median=%.3fms min=%.3fms max=%.3fms\n", NR, a[mid], a[1], a[NR]) }'
```

Expected: Reports startup timing without errors.

- [ ] **Step 4: Run Nix verification**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
nix flake check
home-manager switch --flake '.#nixos@wsl'
```

Expected: Both commands exit 0. The unqualified `home-manager switch --flake .` is expected to fail in this repo because the flake exposes named home configurations such as `nixos@wsl` rather than a default `nixos` configuration.

- [ ] **Step 5: Describe jj change**

Run:

```bash
cd /home/nixos/wkspace/worktree/refactor/nvim-performance
jj describe -m ':zap: perf(neovim): optimize startup and preserve filer keymap'
```

Expected: Working copy description is updated.
