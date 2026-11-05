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
--   local endpoint = caller.for_role(root, "fg-sora-1")  -- read now, not cached
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

-- {{{ function M.for_role()
-- The endpoint record a role uses now: name, url, kind, timeout, and any other
-- field the file gives it. Refused: no use. line for the role; an endpoint
-- with no timeout (every call needs a limit, and nothing has a default in
-- code); an endpoint that needs a key (outside providers come with issue 402,
-- and a request sent without its key would only be refused there).
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
    if endpoint["key-file"] then
        fail(endpoint, "it needs a key (" .. name .. ".key-file), and endpoints with "
            .. "keys come with issue 402; until then a role cannot use it")
    end
    return endpoint
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
