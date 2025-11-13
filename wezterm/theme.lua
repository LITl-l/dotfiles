-- Theme and color scheme configuration
local M = {}

function M.apply(config)
  -- Color scheme (using Catppuccin Latte - warm light theme)
  config.color_scheme = 'Catppuccin Latte'

  -- Visual bell
  config.audible_bell = "Disabled"
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = 'CursorColor',
  }

  -- Cursor configuration
  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 500
  config.cursor_blink_ease_in = 'Constant'
  config.cursor_blink_ease_out = 'Constant'
end

return M
