-- Remote multiplexer domains (cross-machine wezterm session sharing).
--
-- Contract: an ssh_config alias named MUX_SSH_ALIAS below must exist on
-- each client machine's OS-level ssh config (Windows: %USERPROFILE%\.ssh\config,
-- Linux/macOS: ~/.ssh/config). It must resolve HostName / User / IdentityFile
-- for the target Linux server. Real host details are per-machine and NOT
-- committed to this repo.

local M = {}

local MUX_SSH_ALIAS = 'wez-mux'
local MUX_NAME      = 'mux:wez-mux'

function M.apply(config)
  config.ssh_domains = config.ssh_domains or {}
  table.insert(config.ssh_domains, {
    name           = MUX_NAME,
    remote_address = MUX_SSH_ALIAS,
    multiplexing   = 'WezTerm',
    assume_shell   = 'Posix',
    -- username taken from ssh_config
  })

  config.launch_menu = config.launch_menu or {}
  table.insert(config.launch_menu, {
    label = 'Attach: ' .. MUX_NAME,
    args  = { 'wezterm', 'connect', MUX_NAME },
  })
end

M.name = MUX_NAME

return M
