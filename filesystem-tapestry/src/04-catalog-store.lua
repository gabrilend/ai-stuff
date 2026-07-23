-- 04-catalog-store.lua — the seam between making the catalog and reading it.
--
-- General description: the scanners each wrote a shard for one drive. This file
-- staples the shards into one catalog, and -- entirely separately -- reads that
-- catalog back into memory for the viewing half. It is the ONLY thing the two
-- halves share: the generation side writes catalog.jsonl, the viewing side reads
-- it, and neither ever calls the other's code. A crash while scanning cannot
-- reach the navigator, because the navigator only ever sees this one file.

local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
local utils = require("01-utils")

local M = {}

-- {{{ list_shards
-- Ask the shell for the shard files rather than reimplement directory reading.
-- Read-only, one command, returns absolute paths.
local function list_shards(tmp_dir)
    local shards = {}
    local pipe = io.popen("ls -1 " .. "'" .. tmp_dir .. "'/catalog-*.jsonl 2>/dev/null")
    if not pipe then return shards end
    for line in pipe:lines() do shards[#shards + 1] = line end
    pipe:close()
    return shards
end
-- }}}

-- {{{ M.merge_shards
-- Concatenate every per-root shard into one catalog file. Returns the total
-- record count so the run can report how big the tapestry is.
function M.merge_shards(tmp_dir, out_path)
    local shards = list_shards(tmp_dir)
    if #shards == 0 then
        utils.log_warn("no shards found in " .. tmp_dir
            .. " -- did the scan run? catalog will be empty")
    end
    local out = assert(io.open(out_path, "w"))
    local total = 0
    for _, shard in ipairs(shards) do
        local f = io.open(shard, "r")
        if f then
            for line in f:lines() do
                if line ~= "" then out:write(line, "\n"); total = total + 1 end
            end
            f:close()
        end
    end
    out:close()
    utils.log_info(string.format("catalog merged: %d records from %d shards -> %s",
        total, #shards, out_path))
    return total
end
-- }}}

-- {{{ M.load
-- Read catalog.jsonl into an array of records for the viewing half. Loading the
-- whole catalog into memory is what lets the navigator jump to any index
-- instantly; a future issue can page it if a drive's catalog ever outgrows RAM.
function M.load(path)
    local records = {}
    local f = io.open(path, "r")
    if not f then
        utils.log_error("catalog not found at " .. path
            .. " -- run the scan first (run.sh --scan)")
        return records
    end
    local n = 0
    for line in f:lines() do
        if line ~= "" then
            n = n + 1
            local ok, rec = pcall(utils.json_decode, line)
            if ok and type(rec) == "table" then
                records[#records + 1] = rec
            else
                -- One bad line should not sink the whole catalog; report it and
                -- keep going, because partial data still makes a usable walk.
                utils.log_warn("skipping unparseable catalog line " .. n)
            end
        end
    end
    f:close()
    return records
end
-- }}}

return M
