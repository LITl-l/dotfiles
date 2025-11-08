-- Performance and rendering configuration
local platform = require 'platform'

local M = {}

function M.apply(config)
  -- Default performance settings
  config.front_end = "OpenGL"
  config.max_fps = 120

  -- Platform-specific optimizations
  if platform.is_linux then
    config.enable_wayland = true
  end

  -- Windows-specific performance settings
  if platform.is_windows then
    -- Better font rendering on Windows
    config.front_end = "WebGpu"
    config.webgpu_power_preference = "HighPerformance"
  end
end

return M
