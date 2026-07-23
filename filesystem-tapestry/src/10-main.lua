-- 10-main.lua — the viewing half's entry: read input/, walk, write goodbye.
--
-- General description: the capstone that ties the pieces together for a browsing
-- session. Per house rule it does two bookend chores. FIRST, before anything, it
-- reads the input/ directory -- plain key=value lines there can pre-set where the
-- walk begins (which walk, which date, which direction), so the program starts
-- up already knowing how you want it. LAST, when you leave, it writes a goodbye
-- into output/ recording where the walk ended. In between it loads the catalog
-- and hands it to the navigator.

DIR = os.getenv("TAPESTRY_DIR")
    or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path

local cfg      = require("00-config")
local utils    = require("01-utils")
local store    = require("04-catalog-store")
local dispatch = require("08-media-dispatch")
local navigator = require("09-navigator")

-- {{{ read_input
-- The first thing the program does. Scan input/ for key=value lines and collect
-- the ones that set a starting walk. Unknown lines are ignored quietly -- input/
-- is a scratch space, not a config schema.
local function read_input()
    local startup = {}
    local pipe = io.popen("ls -1 '" .. cfg.paths.input .. "' 2>/dev/null")
    if not pipe then return startup end
    for name in pipe:lines() do
        local f = io.open(cfg.paths.input .. "/" .. name, "r")
        if f then
            for line in f:lines() do
                local k, v = line:match("^%s*([%w_]+)%s*=%s*(%S+)")
                if k == "mode" then startup.mode = v
                elseif k == "field" then startup.field = v
                elseif k == "direction" then startup.direction = v end
            end
            f:close()
        end
    end
    if next(startup) then
        utils.log_info(string.format("input/ preset the walk: mode=%s field=%s direction=%s",
            startup.mode or "(default)", startup.field or "(default)",
            startup.direction or "(default)"))
    end
    return startup
end
-- }}}

-- {{{ write_goodbye
-- The last thing the program does: leave a note about where the walk ended.
local function write_goodbye(ending)
    local f = io.open(cfg.paths.output .. "/goodbye", "w")
    if not f then
        utils.log_warn("could not write output/goodbye")
        return
    end
    f:write("filesystem tapestry -- session end\n")
    f:write(string.format("ended on the %s walk, at position %d of %d\n",
        ending.mode, ending.cursor, ending.total))
    f:write("last file: " .. ending.path .. "\n")
    f:write("goodbye.\n")
    f:close()
end
-- }}}

-- {{{ main
local function main()
    dispatch.apply_overrides(cfg.viewer_overrides)   -- let config re-point kinds
    local startup = read_input()                     -- FIRST: read input/

    local records = store.load(cfg.paths.catalog)
    if #records == 0 then
        utils.log_error("catalog is empty -- run the scan first: run.sh --scan")
        os.exit(1)
    end

    local ending = navigator.run(records, cfg, startup)

    write_goodbye(ending)                            -- LAST: write output/goodbye
    print("goodbye.")
end
-- }}}

main()
