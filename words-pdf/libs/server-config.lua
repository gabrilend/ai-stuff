-- {{{ Server Configuration for Words-PDF Web Interface
local config = {}

-- System status display configuration
config.SHOW_MILLISECONDS = true  -- Set to false to hide milliseconds in status
config.STATUS_UPDATE_MIN = 600   -- Minimum update interval (ms)
config.STATUS_UPDATE_MAX = 800   -- Maximum update interval (ms)

-- Character limit configuration
config.DEFAULT_CHAR_LIMIT = 80   -- Default character limit for AI responses
config.MIN_CHAR_LIMIT = 10       -- Minimum allowed character limit
config.MAX_CHAR_LIMIT = 1000     -- Maximum allowed character limit

-- Debug configuration
config.DEBUG_MODE = true         -- Enable debug output
config.SHOW_TIMING_INFO = true   -- Show timing info in debug output

return config
-- }}}