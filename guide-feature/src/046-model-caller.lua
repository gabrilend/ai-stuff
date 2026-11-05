-- 046-model-caller.lua - which endpoint a role uses, and the calls to it.
--
-- In plain terms: every language model and embedding model guide-feature
-- uses is a llama.cpp server named in the project-root `endpoints` file
-- (docs/endpoints.md). This answers "which endpoint does this role use?" by
-- reading that file again every time it is asked, so an edited `use.` line
-- takes effect on the role's next turn with nothing restarted. Then it makes
-- the calls against that endpoint through this project's copy of the
-- llama.cpp client (libs/llama-chat-client.lua): chat, token count,
-- embedding, and "does it answer?". A failure is an error naming the endpoint
-- and its address. It never falls back to another endpoint: the canvas would
-- then look as if one model wrote it when another did. (issue 401b)
--
--   local caller = dofile(DIR .. "/src/046-model-caller.lua")
--   local endpoint = caller.for_role(root, "distiller")  -- read now, not cached
--   local endpoint = caller.from_canvas(record, "fg-sora-1", root)  -- a voice's
--   local text, info = caller.chat(endpoint, messages)    -- info.usage, info.seconds
--   local n = caller.count_tokens(endpoint, text)
--   local vectors = caller.embed(caller.for_role(root, "embedder"), { "a", "b" })
--   caller.reachable(endpoint)                            -- true or false
--   caller.describe(endpoint)                             -- "name (url)"
--
-- Every failure is a Lua error (level 0) whose message starts with the
-- endpoint's name and address: "endpoint 'kuvalu-chat' (http://...): ...".
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local ffi = require("ffi")
local settings = dofile(DIR .. "/src/001-settings.lua")
local client = dofile(DIR .. "/libs/llama-chat-client.lua")

pcall(ffi.cdef, [[
    typedef struct { long tv_sec; long tv_nsec; } guide_model_timespec;
    int clock_gettime(int clock, guide_model_timespec *spec);
]])

local M = {}
M.client = client

-- {{{ local function now()
-- Seconds, with milliseconds, from the monotonic clock (1): how long a call
-- took, unaffected by the wall clock being set.
local function now()
    local spec = ffi.new("guide_model_timespec")
    if ffi.C.clock_gettime(1, spec) == 0 then
        return tonumber(spec.tv_sec) + tonumber(spec.tv_nsec) / 1e9
    end
    return os.time()
end
-- }}}

-- {{{ function M.describe()
-- An endpoint as messages and logs name it.
function M.describe(endpoint)
    return "'" .. endpoint.name .. "' (" .. endpoint.url .. ")"
end
-- }}}

-- {{{ local function fail()
local function fail(endpoint, text)
    error("endpoint " .. M.describe(endpoint) .. ": " .. text, 0)
end
-- }}}

-- {{{ function M.read()
-- The endpoints file, read and checked now (001's read_endpoints: every
-- endpoint has a url and a kind, every use. line names an endpoint of the
-- kind its role needs). Never cached: each call reads the file again.
function M.read(root)
    return settings.read_endpoints({ root = root })
end
-- }}}

-- {{{ local function realpath()
-- A path with ~ expanded and made absolute and plain (`realpath -m`, which
-- does not need the path to exist).
local function realpath(path)
    path = path:gsub("^~", os.getenv("HOME") or "~")
    local pipe = io.popen("realpath -m -- '" .. path:gsub("'", "'\\''") .. "' 2>/dev/null")
    local real = pipe and pipe:read("*l")
    if pipe then pipe:close() end
    return real ~= "" and real or path
end
-- }}}

-- {{{ function M.load_key()
-- For an endpoint with a key file (an outside provider, issue 402): its key,
-- read now, at the start of the turn, into endpoint.key. The file must be
-- outside the project (`docs/endpoints.md`: the key itself is never in the
-- repository), and must hold the key. Each refusal names the endpoint and
-- the file, never the key. An endpoint with no key file is left alone.
function M.load_key(endpoint, root)
    local path = endpoint["key-file"]
    if not path then return endpoint end
    local file, project = realpath(path), realpath(root)
    if file == project or file:sub(1, #project + 1) == project .. "/" then
        fail(endpoint, "its key file " .. path .. " is inside the project; keys live "
            .. "outside the repository")
    end
    local handle = io.open(file, "rb")
    if not handle then
        fail(endpoint, "its key file " .. path .. " is missing or cannot be read")
    end
    local key = (handle:read("*a") or ""):match("^%s*(.-)%s*$")
    handle:close()
    if key == "" or key:find("[%c%s]") then
        fail(endpoint, "its key file " .. path .. " does not hold one key on one line")
    end
    endpoint.key = key
    return endpoint
end
-- }}}

-- {{{ function M.for_role()
-- The endpoint record a role uses now: name, url, kind, timeout, and any other
-- field the file gives it, with its key read when it has a key file. Refused:
-- no use. line for the role; an endpoint with no timeout (every call needs a
-- limit, and nothing has a default in code); a key file that cannot be used.
-- kuvalu's own roles (the distiller, the embedder) are found this way; a voice
-- finds its endpoint in the canvas kuvalu sends it (from_canvas).
function M.for_role(root, role)
    local file = M.read(root)
    local name = file.use[role]
    if not name then
        error("endpoints: there is no use." .. role .. " line, so the role '" .. role
            .. "' has no endpoint (docs/endpoints.md)", 0)
    end
    local endpoint = { name = name, role = role }
    for field, value in pairs(file.endpoints[name]) do endpoint[field] = value end
    if not endpoint.timeout then
        error("endpoints: the endpoint '" .. name .. "' has no " .. name
            .. ".timeout; every endpoint a role uses needs one, in seconds", 0)
    end
    return M.load_key(endpoint, root)
end
-- }}}

-- {{{ function M.from_canvas()
-- The endpoint a voice uses for this turn, from the canvas kuvalu sent it:
-- its own line in the `endpoints:` section (docs/canvas-format.md), which
-- kuvalu writes from its endpoints file at every version. Only kuvalu keeps
-- that file (docs/endpoints.md). The key, when the line names a key file, is
-- read from that file on this machine. Refused: no line for this voice.
function M.from_canvas(record, voice, root)
    for _, line in ipairs(record.endpoints or {}) do
        if line.voice == voice then
            local endpoint = { name = line.name, url = line.address, kind = "chat",
                               timeout = line.timeout, role = voice,
                               ["key-file"] = line.key_file }
            return M.load_key(endpoint, root)
        end
    end
    error("the canvas names no endpoint for " .. voice .. ": kuvalu's endpoints file has "
        .. "no use." .. voice .. " line, or could not be read when this version was sent", 0)
end
-- }}}

-- {{{ local function needs_kind()
-- Refuses a call the endpoint is not for, before anything is sent: a chat
-- server cannot embed and an embedding server cannot chat.
local A = { chat = "a chat", embedding = "an embedding" }
local function needs_kind(endpoint, kind)
    if endpoint.kind ~= kind then
        fail(endpoint, "it is " .. (A[endpoint.kind] or tostring(endpoint.kind)) .. " endpoint, and "
            .. A[kind] .. " call needs " .. A[kind] .. " endpoint")
    end
end
-- }}}

-- {{{ function M.reachable()
-- True when the endpoint answers GET /v1/models now.
function M.reachable(endpoint)
    return client.is_reachable(endpoint)
end
-- }}}

-- {{{ function M.chat()
-- The assistant's reply to a conversation ({ role, content } turns), and
-- { usage = { prompt_tokens, completion_tokens, total_tokens } or {},
--   seconds = how long the call took, endpoint = its name }.
function M.chat(endpoint, messages, opts)
    needs_kind(endpoint, "chat")
    local started = now()
    local text, decoded = client.chat(endpoint, messages, opts)
    if not text then fail(endpoint, decoded) end
    return text, { usage = decoded.usage or {}, seconds = now() - started,
                   endpoint = endpoint.name }
end
-- }}}

-- {{{ function M.count_tokens()
-- The exact number of tokens the endpoint's model makes of `text`. Either
-- kind of endpoint can count; each counts with its own model's tokenizer.
function M.count_tokens(endpoint, text)
    local count, problem = client.count_tokens(endpoint, text)
    if not count then fail(endpoint, problem) end
    return count
end
-- }}}

-- {{{ function M.embed()
-- One vector per text, in the order given. `texts` is a string or a list.
function M.embed(endpoint, texts, opts)
    needs_kind(endpoint, "embedding")
    local vectors, problem = client.embed(endpoint, texts, opts)
    if not vectors then fail(endpoint, problem) end
    return vectors
end
-- }}}

return M
