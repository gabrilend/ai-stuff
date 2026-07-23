-- {{{ neocities-api.lua
-- Thin, status-honest HTTP layer over the Neocities API, via curl. The stock
-- `neocities` gem throws the HTTP status away and JSON.parse-crashes on any
-- non-JSON body (a Cloudflare/timeout HTML page), which is why a big push dies
-- instead of backing off. This layer instead returns the REAL status code and a
-- parsed-or-nil body for every call, so the adaptive controller (neocities-sync)
-- can tell "too big" (shrink) from "rate limited" (wait) from "ok".
--
-- Verified request shapes (confirmed against the live API before writing this):
--   list   : GET  /api/list?path=...                         -> { files=[...] }
--   upload : POST /api/upload, multipart, field NAME = remote path, value = @file
--   delete : POST /api/delete, repeated form field filenames[] = remote path
--
-- Multi-file requests use a curl CONFIG FILE (-K) rather than a shell command
-- line, so paths never go through shell quoting (and the API key never appears in
-- a process argv). The config file lives in tmp/ (RAM) and is rewritten per call.
-- }}}

local M = {}
local dkjson = require("dkjson")

local API = "https://neocities.org/api/"
local api_key = nil
local project_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ M.set_key / M.set_project_root
function M.set_key(k) api_key = k end
function M.set_project_root(dir) if dir and dir ~= "" then project_root = dir end end
-- }}}

-- {{{ local function cfg_quote(s)
-- Escape a value for a curl config-file double-quoted string. Output paths are
-- clean (generated HTML), but escape backslash and quote defensively anyway.
local function cfg_quote(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end
-- }}}

-- {{{ local function run_curl(config_lines)
-- Write the curl options to a RAM config file, run curl, and split the trailing
-- "__HTTP__<code>" sentinel (added via write-out) off the body. Returns
-- (status:number, body:string). status 0 means curl itself failed (transport).
local function run_curl(config_lines)
    local path = project_root .. "/tmp/neocities-curl.cfg"
    local f = assert(io.open(path, "w"), "neocities-api: cannot write " .. path)
    f:write("silent\n")
    f:write("show-error\n")
    f:write('header = "Authorization: Bearer ' .. (api_key or "") .. '"\n')
    f:write('write-out = "\\n__HTTP__%{http_code}"\n')
    for _, line in ipairs(config_lines) do f:write(line .. "\n") end
    f:close()

    local h = io.popen("curl -K " .. cfg_quote(path) .. " 2>/dev/null")
    local out = h and h:read("*a") or ""
    if h then h:close() end

    local status = tonumber(out:match("__HTTP__(%d+)%s*$")) or 0
    local body = out:gsub("%s*__HTTP__%d+%s*$", "")
    return status, body
end
-- }}}

-- {{{ local function result(status, body)
-- Shape a response for the controller: ok_body is true only on 200 with a
-- parseable JSON body whose result is "success".
local function result(status, body)
    local ok_body = false
    if status == 200 then
        local parsed = dkjson.decode(body or "")
        ok_body = (type(parsed) == "table" and parsed.result == "success") or false
    end
    return { status = status, ok_body = ok_body, body = body }
end
-- }}}

-- {{{ function M.list(path)
-- GET the file list under `path` (or the whole site if nil). Returns the parsed
-- `files` array (each { path=, is_directory=, sha1_hash=, size= }), or nil+err.
function M.list(path)
    local lines = { 'url = ' .. cfg_quote(API .. "list" .. (path and ("?path=" .. path) or "")) }
    local status, body = run_curl(lines)
    if status ~= 200 then return nil, "list HTTP " .. status end
    local parsed = dkjson.decode(body or "")
    if type(parsed) ~= "table" or not parsed.files then
        return nil, "list: unparseable response (HTTP " .. status .. ")"
    end
    return parsed.files
end
-- }}}

-- {{{ function M.upload_batch(items)
-- items: array of { remote=<site path>, abspath=<local file> }. One multipart
-- POST carrying every file (field name = remote path, value = @localfile).
-- Returns { status, ok_body } for the controller.
function M.upload_batch(items)
    local lines = {
        'url = ' .. cfg_quote(API .. "upload"),
        'max-time = 300',
        'connect-timeout = 20',
    }
    for _, it in ipairs(items) do
        lines[#lines + 1] = 'form = ' .. cfg_quote(it.remote .. "=@" .. it.abspath)
    end
    return result(run_curl(lines))
end
-- }}}

-- {{{ function M.delete_batch(paths)
-- paths: array of remote site paths. One POST with repeated filenames[] fields.
function M.delete_batch(paths)
    local lines = {
        'url = ' .. cfg_quote(API .. "delete"),
        'max-time = 120',
        'connect-timeout = 20',
    }
    for _, p in ipairs(paths) do
        lines[#lines + 1] = 'form = ' .. cfg_quote("filenames[]=" .. p)
    end
    return result(run_curl(lines))
end
-- }}}

return M
