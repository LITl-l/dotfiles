-- Window appearance configuration
local M = {}

function M.apply(config)
  -- Window configuration
  config.window_decorations = "RESIZE"
  config.window_background_opacity = 0.95
  config.window_padding = {
    left = 10,
    right = 10,
    top = 10,
    bottom = 10,
  }

  -- Tab bar configuration
  -- Configured for tabline.wez plugin compatibility
  config.enable_tab_bar = true
  config.tab_bar_at_bottom = false
  config.use_fancy_tab_bar = false  -- Use retro tab bar for tabline.wez plugin
  config.hide_tab_bar_if_only_one_tab = false  -- Always show tabline with system info

  -- Scrollback
  config.scrollback_lines = 10000
end

return M
