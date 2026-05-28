-- LSP configuration
-- Auto-configures LSP servers that are available in PATH

local M = {}

-- LSP server configurations
-- Each server can have custom settings
local server_configs = {
  -- Lua
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file('', true),
        },
        completion = { callSnippet = 'Replace' },
        telemetry = { enable = false },
        diagnostics = {
          globals = { 'vim' },
        },
      },
    },
  },

  -- Nix
  nil_ls = {
    settings = {
      ['nil'] = {
        formatting = {
          command = { 'nixfmt' },
        },
        nix = {
          flake = {
            autoArchive = true,
          },
        },
      },
    },
  },

  -- Python: basedpyright handles type checking, completion, navigation
  basedpyright = {
    cmd = { 'basedpyright-langserver', '--stdio' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt', 'Pipfile', 'pyrightconfig.json', '.git' },
    settings = {
      basedpyright = {
        analysis = {
          typeCheckingMode = 'basic',
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = 'openFilesOnly',
          -- Defer linting to ruff to avoid duplicate diagnostics
          diagnosticSeverityOverrides = {
            reportUnusedImport = 'none',
            reportUnusedVariable = 'none',
          },
        },
      },
    },
  },

  -- Python: ruff provides fast linting + organize imports via LSP
  ruff = {
    cmd = { 'ruff', 'server' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
    init_options = {
      settings = {
        -- Disable hover from ruff so basedpyright owns it
        hover = { enable = false },
      },
    },
  },

  -- Rust
  rust_analyzer = {
    settings = {
      ['rust-analyzer'] = {
        checkOnSave = {
          command = 'clippy',
        },
        cargo = {
          allFeatures = true,
        },
      },
    },
  },

  -- TypeScript/JavaScript: vtsls = VSCode's TS LSP wrapper
  -- (richer auto-imports, code actions, organize-imports vs ts_ls)
  vtsls = {
    cmd = { 'vtsls', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
    settings = {
      typescript = {
        updateImportsOnFileMove = { enabled = 'always' },
        suggest = { completeFunctionCalls = true },
        inlayHints = {
          parameterNames = { enabled = 'literals' },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = false },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        },
      },
      javascript = {
        updateImportsOnFileMove = { enabled = 'always' },
        suggest = { completeFunctionCalls = true },
      },
      vtsls = {
        enableMoveToFileCodeAction = true,
        autoUseWorkspaceTsdk = true,
        experimental = {
          completion = { enableServerSideFuzzyMatch = true },
        },
      },
    },
  },

  -- Go
  gopls = {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
        gofumpt = true,
      },
    },
  },

  -- Bash
  bashls = {},

  -- JSON
  jsonls = {
    settings = {
      json = {
        validate = { enable = true },
      },
    },
  },

  -- YAML
  yamlls = {
    settings = {
      yaml = {
        keyOrdering = false,
      },
    },
  },

  -- HTML
  html = {},

  -- CSS
  cssls = {},

  -- Docker
  dockerls = {},

  -- Terraform
  terraformls = {},
}

-- Server name to executable mapping
local server_executables = {
  lua_ls = 'lua-language-server',
  nil_ls = 'nil',
  basedpyright = 'basedpyright-langserver',
  ruff = 'ruff',
  rust_analyzer = 'rust-analyzer',
  vtsls = 'vtsls',
  gopls = 'gopls',
  bashls = 'bash-language-server',
  jsonls = 'vscode-json-language-server',
  yamlls = 'yaml-language-server',
  html = 'vscode-html-language-server',
  cssls = 'vscode-css-language-server',
  dockerls = 'docker-langserver',
  terraformls = 'terraform-ls',
}

-- Check if executable exists in PATH
local function executable_exists(name)
  return vim.fn.executable(name) == 1
end

-- Setup a single LSP server
local function setup_server(server_name)
  local config = server_configs[server_name] or {}
  local executable = server_executables[server_name]

  -- Skip if executable not found
  if executable and not executable_exists(executable) then
    return false
  end

  -- Merge with default capabilities
  config.capabilities = vim.lsp.protocol.make_client_capabilities()

  -- Start LSP for matching filetypes
  vim.lsp.config(server_name, config)
  vim.lsp.enable(server_name)

  return true
end

-- Setup all LSP servers
M.setup = function()
  -- Configure diagnostics display
  vim.diagnostic.config({
    virtual_text = {
      spacing = 4,
      prefix = '●',
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      border = 'rounded',
      source = true,
    },
  })

  -- Set diagnostic signs
  local signs = { Error = ' ', Warn = ' ', Hint = '󰌵 ', Info = ' ' }
  for type, icon in pairs(signs) do
    local hl = 'DiagnosticSign' .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
  end

  -- Setup all configured servers
  local enabled_servers = {}
  for server_name, _ in pairs(server_configs) do
    if setup_server(server_name) then
      table.insert(enabled_servers, server_name)
    end
  end

  -- Create command to show enabled LSP servers
  vim.api.nvim_create_user_command('LspServers', function()
    vim.notify('Enabled LSP servers:\n' .. table.concat(enabled_servers, '\n'), vim.log.levels.INFO)
  end, { desc = 'Show enabled LSP servers' })
end

return M
