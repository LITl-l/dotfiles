-- Debug Adapter Protocol (DAP) configuration
-- Provides debugging support for various languages

local M = {}

M.setup = function()
  local dap_ok, dap = pcall(require, 'dap')
  if not dap_ok then
    return
  end

  local dapui_ok, dapui = pcall(require, 'dapui')
  local dap_virtual_text_ok, dap_virtual_text = pcall(require, 'nvim-dap-virtual-text')

  -- Setup DAP UI
  if dapui_ok then
    dapui.setup({
      icons = { expanded = '▾', collapsed = '▸', current_frame = '▸' },
      mappings = {
        expand = { '<CR>', '<2-LeftMouse>' },
        open = 'o',
        remove = 'd',
        edit = 'e',
        repl = 'r',
        toggle = 't',
      },
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.25 },
            { id = 'breakpoints', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'watches', size = 0.25 },
          },
          size = 40,
          position = 'left',
        },
        {
          elements = {
            { id = 'repl', size = 0.5 },
            { id = 'console', size = 0.5 },
          },
          size = 10,
          position = 'bottom',
        },
      },
      floating = {
        max_height = nil,
        max_width = nil,
        border = 'rounded',
        mappings = {
          close = { 'q', '<Esc>' },
        },
      },
    })

    -- Auto open/close DAP UI
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end
  end

  -- Setup virtual text
  if dap_virtual_text_ok then
    dap_virtual_text.setup({
      enabled = true,
      enabled_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      show_stop_reason = true,
      commented = false,
    })
  end

  -- Signs
  vim.fn.sign_define('DapBreakpoint', { text = '●', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
  vim.fn.sign_define('DapLogPoint', { text = '◆', texthl = 'DapLogPoint', linehl = '', numhl = '' })
  vim.fn.sign_define('DapStopped', { text = '▶', texthl = 'DapStopped', linehl = 'DapStopped', numhl = 'DapStopped' })
  vim.fn.sign_define('DapBreakpointRejected', { text = '○', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })

  -- Python configuration (using debugpy)
  dap.adapters.python = {
    type = 'executable',
    command = 'python',
    args = { '-m', 'debugpy.adapter' },
  }
  dap.configurations.python = {
    {
      type = 'python',
      request = 'launch',
      name = 'Launch file',
      program = '${file}',
      pythonPath = function()
        local cwd = vim.fn.getcwd()
        if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
          return cwd .. '/venv/bin/python'
        elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
          return cwd .. '/.venv/bin/python'
        else
          return 'python'
        end
      end,
    },
  }

  -- Keymaps
  local map = vim.keymap.set
  map('n', '<leader>db', dap.toggle_breakpoint, { desc = '[D]ebug [B]reakpoint toggle' })
  map('n', '<leader>dB', function()
    dap.set_breakpoint(vim.fn.input('Breakpoint condition: '))
  end, { desc = '[D]ebug [B]reakpoint conditional' })
  map('n', '<leader>dc', dap.continue, { desc = '[D]ebug [C]ontinue' })
  map('n', '<leader>di', dap.step_into, { desc = '[D]ebug step [I]nto' })
  map('n', '<leader>do', dap.step_over, { desc = '[D]ebug step [O]ver' })
  map('n', '<leader>dO', dap.step_out, { desc = '[D]ebug step [O]ut' })
  map('n', '<leader>dr', dap.repl.open, { desc = '[D]ebug [R]EPL' })
  map('n', '<leader>dl', dap.run_last, { desc = '[D]ebug [L]ast' })
  map('n', '<leader>dx', dap.terminate, { desc = '[D]ebug terminate' })

  if dapui_ok then
    map('n', '<leader>du', dapui.toggle, { desc = '[D]ebug [U]I toggle' })
    map('n', '<leader>de', dapui.eval, { desc = '[D]ebug [E]val' })
    map('v', '<leader>de', dapui.eval, { desc = '[D]ebug [E]val' })
  end
end

return M
