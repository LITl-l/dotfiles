-- Theme and color scheme configuration
local M = {}

function M.apply(config)
  -- Base color scheme (light, warm foundation)
  config.color_scheme = 'Breath (Gogh)'

  -- Custom warm white, orange, and brown color palette
  config.colors = {
    -- Foreground/Background - warm white base
    foreground = '#5c4d3d',  -- warm brown text
    background = '#fefdf8',  -- soft warm white

    -- Cursor - orange accent
    cursor_bg = '#d97742',   -- warm orange
    cursor_fg = '#fefdf8',   -- warm white
    cursor_border = '#d97742',

    -- Selection - light brown
    selection_bg = '#f5e6d3',  -- light beige
    selection_fg = '#5c4d3d',  -- warm brown

    -- Tab bar colors - warm white with orange and brown accents
    tab_bar = {
      background = '#faf8f3',  -- very light warm white
      active_tab = {
        bg_color = '#d97742',  -- warm orange
        fg_color = '#fefdf8',  -- warm white
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = '#f5ede3',  -- light cream
        fg_color = '#8b7355',  -- medium brown
      },
      inactive_tab_hover = {
        bg_color = '#edb88b',  -- light orange
        fg_color = '#5c4d3d',  -- warm brown
      },
      new_tab = {
        bg_color = '#f5ede3',  -- light cream
        fg_color = '#8b7355',  -- medium brown
      },
      new_tab_hover = {
        bg_color = '#edb88b',  -- light orange
        fg_color = '#5c4d3d',  -- warm brown
      },
    },

    -- ANSI colors - warm palette
    ansi = {
      '#5c4d3d',  -- black (warm brown)
      '#c04f30',  -- red (terracotta)
      '#8a9a5b',  -- green (olive)
      '#d99545',  -- yellow (amber)
      '#7c8fa3',  -- blue (muted slate)
      '#a06469',  -- magenta (dusty rose)
      '#8ea59d',  -- cyan (sage)
      '#f5ede3',  -- white (cream)
    },
    brights = {
      '#8b7355',  -- bright black (medium brown)
      '#d97742',  -- bright red (warm orange)
      '#a8b86c',  -- bright green (light olive)
      '#ebad5f',  -- bright yellow (golden)
      '#97aec2',  -- bright blue (light slate)
      '#b88b8f',  -- bright magenta (rose)
      '#abd5c9',  -- bright cyan (mint)
      '#fefdf8',  -- bright white (warm white)
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


