-- find-divergence.lua — the headline datapoint of Phase 1.
--
-- Lists files whose creation date on THIS drive is more than a year later than
-- their content's modified date -- old things copied here recently. This gap is
-- the plain proof that recording BOTH dates matters: one date alone would hide
-- either when the bytes were written or when they arrived on the disk.
--
-- Usage: TAPESTRY_DIR=<dir> luajit scripts/find-divergence.lua [show_n]
DIR = os.getenv("TAPESTRY_DIR")
    or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
local cfg   = require("00-config")
local utils = require("01-utils")

local YEAR = 31536000              -- seconds in ~365 days
local show_n = tonumber(arg and arg[1]) or 5

local f = io.open(cfg.paths.catalog, "r")
if not f then
    io.stderr:write("no catalog -- run ./run.sh --scan first\n")
    os.exit(1)
end

local total, shown = 0, 0
for line in f:lines() do
    local ok, r = pcall(utils.json_decode, line)
    if ok and r.created and r.modified and (r.created - r.modified) > YEAR then
        total = total + 1
        if shown < show_n then
            shown = shown + 1
            print(string.format("  born %s  |  content %s  |  %s",
                os.date("%Y-%m-%d", r.created),
                os.date("%Y-%m-%d", r.modified),
                utils.basename(r.path)))
        end
    end
end
f:close()
print(string.format("  ... %d files have a >1yr gap between arrival and content date",
    total))
