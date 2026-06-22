-- inference-server-config.lua
-- Issue 025: resolves which llama-server endpoints the runtime talks to for
-- embeddings and chat. Replaces the old ollama-config.lua, which probed a
-- list of addresses for a live /api/tags reply; the new design does not
-- probe — both endpoints are configured, and a caller that cannot reach
-- one is supposed to fail loudly so the operator notices instead of
-- silently falling through to a "first-thing-that-answered" default.
--
-- llama-server is single-model per process, so the project runs two
-- instances on adjacent ports: one bound to the embedding model (nomic-
-- embed-text v1.5), one bound to the chat model (Qwen3-8B). Both live on
-- the same GPU box at 192.168.1.100; the port distinguishes them.
--
-- Operators who need to point either endpoint elsewhere set
-- INFERENCE_EMBEDDING_HOST or INFERENCE_CHAT_HOST in the environment
-- before running. Each variable replaces the entire "host:port" of its
-- endpoint, e.g. INFERENCE_CHAT_HOST=localhost:8080. The library will
-- not validate the format — a typo there produces a connection error
-- on first use, which is the failure mode we want (loud, immediate).

local M = {}

-- {{{ local function build_endpoint(env_var, default_host, default_port)
-- Build a full http:// URL from a host:port pair, honoring an optional
-- env-var override. The override replaces the host and port together
-- (not just one or the other) — a partial override would be more
-- code than it's worth for the one config knob this module exposes.
local function build_endpoint(env_var, default_host, default_port)
    local override = os.getenv(env_var)
    if override and override ~= "" then
        return "http://" .. override
    end
    return string.format("http://%s:%d", default_host, default_port)
end
-- }}}

-- The embedding server serves nomic-embed-text v1.5 (Q8_0) on port
-- 20165 with --embeddings. Callers post to /v1/embeddings.
M.EMBEDDING_ENDPOINT = build_endpoint("INFERENCE_EMBEDDING_HOST", "192.168.1.100", 20165)

-- The chat server serves Qwen3-8B (Q4_K_M) on port 20166 without
-- --embeddings. Callers post to /v1/chat/completions.
M.CHAT_ENDPOINT = build_endpoint("INFERENCE_CHAT_HOST", "192.168.1.100", 20166)

return M
