-- print-roots.lua — emit the configured scan roots, one per line.
-- Exists so run.sh can fan out one scanner per root without duplicating the
-- root list; the roots are defined once, in src/00-config.lua.
DIR = os.getenv("TAPESTRY_DIR")
    or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. package.path
local cfg = require("00-config")
for _, root in ipairs(cfg.roots) do print(root) end
