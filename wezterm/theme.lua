-- Theme and color scheme configuration
local M = {}

function M.apply(config)
  -- Color scheme (using Tokyo Night Day - warm peachy aesthetic)
  config.color_scheme = 'Tokyo Night Day'

  -- Custom warm color overrides for a peachy aesthetic
  config.colors = {
    -- Tab bar colors - warm peach/coral tones
    tab_bar = {
      background = '#f6f2ee',
      active_tab = {
        bg_color = '#ff9e64',
        fg_color = '#1a1b26',
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = '#e9e4df',
        fg_color = '#8c8378',
      },
      inactive_tab_hover = {
        bg_color = '#ffd6a5',
        fg_color = '#1a1b26',
      },
      new_tab = {
        bg_color = '#e9e4df',
        fg_color = '#8c8378',
      },
      new_tab_hover = {
        bg_color = '#ffd6a5',
        fg_color = '#1a1b26',
      },
    },
  }

  -- Visual bell
  config.audible_bell = "Disabled"
  config.visual_bell = {
    fade_in_duration_ms = 75,
    fade_out_duration_ms = 75,
    target = 'CursorColor',
  }

  -- Cursor configuration - warm orange
  config.default_cursor_style = 'BlinkingBar'
  config.cursor_blink_rate = 500
  config.cursor_blink_ease_in = 'Constant'
  config.cursor_blink_ease_out = 'Constant'
end

return M

