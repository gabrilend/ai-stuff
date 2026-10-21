-- {{{ inference-server-config.lua
-- Issue 10-049: Inference-server configuration loader (originally written for
-- Ollama under 10-017; renamed and reframed for llama.cpp). Reads server
-- definitions from config.lua and provides an API for server selection. The
-- public surface intentionally stays close to the pre-migration shape so
-- existing call sites in the rest of the codebase keep their structure.
--
-- Usage:
--   local inference = require("inference-server-config")
--   inference.set_project_root("/path/to/project")  -- Required before other calls
--
--   -- Get servers
--   local servers = inference.get_servers()
--   local server = inference.get_server_by_name("gpu-server")
--   local default = inference.get_default_server()
--
--   -- Build URL
--   local url = inference.build_host_url(server)  -- "http://192.168.0.115:10265"
--
--   -- Validate connection
--   local ok, msg = inference.validate_server(server)
-- }}}

local M = {}

-- {{{ Module state
local project_root = nil
local config = nil
local selected_server = nil  -- CLI override
local selected_model = nil   -- CLI override

-- Whether the caller is in an interactive context. Off by default. The only
-- way to enable it is for a CLI driver to call set_interactive_mode(true)
-- after detecting -I on its command line — this is deliberately not a
-- config.lua key, because the user-editable config file should describe
-- what the project IS, not how the operator happens to be running it today.
--
-- The library applies a consistent policy whenever user input fails to
-- resolve against a configured set of options (a typo in --server, an
-- unrecognized --model, a missing default that points at a nonexistent
-- entry, etc.): non-interactive callers hard-error immediately so the
-- mistake is impossible to miss; interactive callers prompt the user to
-- choose between using a sensible default or aborting. Silent fallback to
-- a default is never the answer here — warnings get scrolled past in long
-- log streams, and the wrong default can produce hours of work against the
-- wrong endpoint before anyone notices.
local interactive_mode = false
-- }}}

-- {{{ set_project_root
-- Set the project root directory (required before loading config)
function M.set_project_root(path)
    project_root = path
    config = nil  -- Reset config when root changes
end
-- }}}

-- {{{ local function load_config
-- Load config.lua if not already loaded
local function load_config()
    if config then
        return config
    end

    if not project_root then
        -- Try to detect from package.path
        local path = package.path:match("([^;]+)/libs/%?%.lua")
        if path then
            project_root = path
        else
            -- Fallback default
            project_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
        end
    end

    local config_path = project_root .. "/config.lua"
    local ok, result = pcall(dofile, config_path)
    if not ok then
        -- Config not available, use empty
        config = {}
        return config
    end

    config = result
    return config
end
-- }}}

-- {{{ local function prompt_for_server_fallback
-- Interactive recovery for "--server=<name> did not resolve."
-- Shows the configured default server and asks whether to use it or abort.
-- Prompts go to stderr so callers that capture stdout still surface them
-- (though callers that capture stdout should not enable interactive mode
-- in the first place). On success, also caches the choice by clearing
-- selected_server, so a stage that calls get_selected_server twice does
-- not re-prompt the operator.
local function prompt_for_server_fallback(bad_name)
    local cfg = load_config()
    local default_name = cfg.default_inference_server
    local default_server = default_name and M.get_server_by_name(default_name) or nil

    io.stderr:write(string.format(
        "\n[!] Inference server '%s' was not found in config.lua's inference_servers.\n", bad_name))

    if not default_server then
        io.stderr:write("    No usable default_inference_server is configured to fall back to.\n")
        error(string.format(
            "inference-server-config: --server=%s did not resolve and no default is available.", bad_name))
    end

    io.stderr:write("\nThe configured default is:\n")
    io.stderr:write(string.format("  name:  %s\n", default_server.name))
    io.stderr:write(string.format("  host:  %s\n", default_server.host or "(missing in config!)"))
    io.stderr:write(string.format("  port:  %s\n", tostring(default_server.port or "(missing in config!)")))
    io.stderr:write("\n  1) Use the default\n")
    io.stderr:write("  2) Error and exit\n")
    io.stderr:write("\nSelect 1 or 2: ")

    local choice = io.read("*l")
    if choice == "1" then
        selected_server = nil  -- so subsequent calls go straight to the default without re-prompting
        return default_server
    end

    error(string.format(
        "inference-server-config: aborted by user — '%s' did not resolve and user chose to exit.", bad_name))
end
-- }}}

-- {{{ function M.set_interactive_mode
-- Flip the library into interactive mode. Only the CLI driver should call
-- this, and only after confirming -I was passed on the command line.
-- See the doc-comment on interactive_mode above for the policy this enables.
function M.set_interactive_mode(enabled)
    interactive_mode = enabled and true or false
end
-- }}}

-- {{{ get_servers
-- All configured inference servers. None configured is an error: a server
-- invented here (it used to be a hard-coded "local" entry with a default
-- model) would look like a choice nobody made.
function M.get_servers()
    local cfg = load_config()
    local servers = cfg.inference_servers
    if not (servers and #servers > 0) then
        error("inference-server-config: config.lua has no inference_servers")
    end
    return servers
end
-- }}}

-- {{{ function M.model_names
-- The names of the models a server lists (its available_models), in order.
-- server: a server entry from config.lua; returns a list of strings.
function M.model_names(server)
    local names = {}
    for _, entry in ipairs(server.available_models or {}) do
        names[#names + 1] = entry.model
    end
    return names
end
-- }}}
-- }}}

-- {{{ get_server_by_name
-- Get a specific server by name
-- Returns server object or nil if not found
function M.get_server_by_name(name)
    if not name then return nil end

    for _, server in ipairs(M.get_servers()) do
        if server.name == name then
            return server
        end
    end

    return nil
end
-- }}}

-- {{{ get_default_server
-- Resolve the configured default Inference server.
--
-- This is the "must work" path: callers that need an endpoint to make a
-- request rely on this. It errors loudly if either default_inference_server
-- is not set, or the named server does not exist in inference_servers.
--
-- A silent fallback to servers[1] used to live here. It was removed because
-- it masked config drift: if default_inference_server was renamed without
-- updating its referent, every consumer in the pipeline would silently
-- start talking to whatever server happened to be first in the list,
-- producing wrong results without any error message. Loud failure now
-- guarantees that "endpoint resolution succeeded" means "your config said
-- to use this server", not "we guessed."
function M.get_default_server()
    local cfg = load_config()

    if not cfg.default_inference_server then
        error("inference-server-config: config.lua does not set default_inference_server. "
            .. "Set it to one of the names in inference_servers, or pass --server=<name> on the CLI.")
    end

    local server = M.get_server_by_name(cfg.default_inference_server)
    if not server then
        error(string.format(
            "inference-server-config: default_inference_server is '%s' but no entry with that name exists in inference_servers. "
            .. "Fix the name in config.lua, or add a matching inference_servers entry.",
            cfg.default_inference_server))
    end

    return server
end
-- }}}

-- {{{ get_selected_server
-- Resolve the currently selected server.
--
-- Resolution order:
--   1. If --server=<name> was passed via set_selected_server, look it up
--      in inference_servers.
--      - If the name resolves, return that server.
--      - If the name does not resolve:
--          interactive: prompt the user to choose default or exit.
--          non-interactive: hard-error with a message that names the
--          offending --server=<name> and points at the fix.
--   2. If this run recorded a --server on the shared notepad, use that
--      (Issue 10-065; see the block below for why).
--   3. Otherwise delegate to get_default_server, which either returns a
--      resolved default or errors loudly if the default itself is missing
--      or unresolvable.
--
-- This function deliberately never falls back silently. A typoed --server
-- used to print a stderr warning and continue against the default, which
-- meant a busy operator could miss the warning in the log stream and
-- spend hours of pipeline time talking to the wrong endpoint.
function M.get_selected_server()
    if selected_server then
        local server = M.get_server_by_name(selected_server)
        if server then
            return server
        end

        if interactive_mode then
            return prompt_for_server_fallback(selected_server)
        end

        error(string.format(
            "inference-server-config: --server=%s does not match any entry in inference_servers (config.lua).\n"
            .. "Fix the name on the CLI, add a matching entry to inference_servers, "
            .. "or pass -I to enable interactive selection.",
            selected_server))
    end

    -- Issue 10-065: read the run's notepad, mirroring exactly what
    -- get_selected_model does one function below. Without this, a --server
    -- reached only the children run.sh remembered to hand it to on argv, and
    -- every other child silently resolved default_inference_server instead.
    --
    -- Why that mattered more than "wrong hostname": a server entry also carries
    -- embedding_prompt_prefix, the text prepended to every input before it is
    -- embedded (see format_embedding_prompt). So the server choice selects an
    -- embedding SPACE, not just an endpoint. The live symptom was inside a
    -- single stage: run.sh passed --server to the poem-embedding step but
    -- src/generate-word-pages.lua, which has no --server flag, resolved the
    -- config default -- so poem and word embeddings could be produced against
    -- different hosts with different prefixes, and the word pages then ranked
    -- words against poems by cosine similarity across two different spaces.
    --
    -- load_config() first: it is what resolves project_root, which the notepad
    -- reader needs in order to find tmp/shared-memory/run-overrides.lua.
    load_config()
    local overrides = require("runtime-overrides")
    overrides.set_project_root(project_root)
    local override_server = overrides.get("server")
    if override_server then
        local server = M.get_server_by_name(override_server)
        if server then
            return server
        end
        -- A name on the notepad that does not resolve gets the same hard error
        -- a bad --server gets, and for the same reason: the notepad IS this
        -- run's --server. Falling through to the config default here would
        -- reintroduce the silent substitution this whole function refuses.
        error(string.format(
            "inference-server-config: this run recorded --server=%s, which does not match "
            .. "any entry in inference_servers (config.lua).\n"
            .. "Fix the name on the run.sh command line, or add a matching entry.",
            override_server))
    end

    return M.get_default_server()
end
-- }}}

-- {{{ set_selected_server
-- Set the selected server name (from CLI --server flag)
function M.set_selected_server(name)
    selected_server = name
end
-- }}}

-- {{{ get_selected_model
-- The model this run uses, by name. There is no default (owner, 2026-10-21:
-- "we should not have a default model. It should be manually specified").
--
-- Resolution order:
--   1. --model=<name>, as set by the program's command line;
--   2. the model run.sh recorded on this run's notepad (tmp/run-overrides.lua),
--      so every child stage of one run uses the model the run was given;
--   3. neither: an error naming the server's models. (It used to return the
--      server entry's own `model`, nomic, which a stage run on its own or a
--      test then used without anyone choosing it.)
--
-- The name is not checked against the server's list here: stages that only
-- read caches use it as a folder name, and the server is the authority on
-- what is loaded. get_selected_model_config, which needs the model's file and
-- prompt prefix, refuses a model the server does not list.
function M.get_selected_model()
    local server = M.get_selected_server()
    if selected_model then
        return selected_model
    end
    local overrides = require("runtime-overrides")
    overrides.set_project_root(project_root)
    local override_model = overrides.get("model")
    if override_model then
        return override_model
    end
    error(string.format(
        "inference-server-config: no embedding model named. Pass --model=<name>; server '%s' serves: %s",
        server.name, table.concat(M.model_names(server), ", ")))
end
-- }}}

-- {{{ set_selected_model
-- Set the selected model (from CLI --model flag)
function M.set_selected_model(model)
    selected_model = model
end
-- }}}

-- {{{ build_host_url
-- Build the full URL for a server. Both host and port must be set in
-- config.lua — a server entry without them is a config bug, not a chance
-- for the library to guess sensible defaults. The previous code silently
-- substituted "localhost" and 11434, which meant a forgotten host = in
-- the config would silently redirect every embedding request to nothing.
-- Returns URL string like "http://192.168.0.115:10265".
function M.build_host_url(server)
    if not server then
        server = M.get_selected_server()
    end

    local name = server.name or "(unnamed server)"
    if not server.host then
        error(string.format(
            "inference-server-config: server '%s' has no 'host' field in config.lua. "
            .. "Add a host = \"<hostname-or-ip>\" field to that inference_servers entry.", name))
    end
    if not server.port then
        error(string.format(
            "inference-server-config: server '%s' has no 'port' field in config.lua. "
            .. "Add a port = <number> field to that inference_servers entry.", name))
    end

    return string.format("http://%s:%d", server.host, server.port)
end
-- }}}

-- {{{ validate_server
-- Check if a server is reachable
-- Returns: success (bool), message (string)
function M.validate_server(server)
    if not server then
        server = M.get_selected_server()
    end

    -- /v1/models is llama.cpp's OpenAI-compatible "what's loaded" endpoint.
    -- Was /api/tags under Ollama; migrated in 10-049 along with the rest
    -- of the API surface.
    local url = M.build_host_url(server) .. "/v1/models"
    local cmd = string.format("curl -s -o /dev/null -w '%%{http_code}' --max-time 3 '%s' 2>/dev/null", url)

    local handle = io.popen(cmd)
    local status = handle:read("*a")
    handle:close()

    status = status:gsub("%s+", "")  -- Trim whitespace

    if status == "200" then
        return true, "Server is reachable"
    elseif status == "000" then
        return false, "Connection timeout - server unreachable"
    else
        return false, "Server returned HTTP " .. status
    end
end
-- }}}

-- {{{ list_servers
-- Print a formatted list of available servers.
-- Reads default_inference_server directly rather than calling get_default_server
-- so that --list-servers works even when no default is configured (or is
-- misconfigured). The purpose of this function is diagnostic, not
-- request-issuing — it must not error when the user is trying to inspect
-- their config.
function M.list_servers()
    local cfg = load_config()
    local servers = M.get_servers()
    local default_name = cfg.default_inference_server  -- may be nil; that's fine here

    print("Available Inference servers:")
    print(string.rep("-", 70))

    for _, server in ipairs(servers) do
        local is_default = (default_name ~= nil and server.name == default_name)
        local default_marker = is_default and " (default)" or ""
        local url = M.build_host_url(server)

        print(string.format("  %s%s", server.name, default_marker))
        print(string.format("    %s", server.description or ""))
        print(string.format("    URL: %s", url))
        print(string.format("    Models (choose one with --model): %s",
            table.concat(M.model_names(server), ", ")))
        print("")
    end
end
-- }}}

-- {{{ format_embedding_prompt
-- Apply the active server's embedding_prompt_prefix to a text payload.
--
-- Some embedding models (notably nomic-embed-text v1.5+) require a
-- task-prefix on every input — "clustering: ", "search_query: ",
-- "search_document: ", etc. — that routes the model through different
-- internal weights. Models that don't need a prefix (embeddinggemma,
-- qwen3-embedding) leave the field nil and this function is a no-op.
--
-- Centralizing the prefix here means a model swap is a single config
-- edit even when the new model has different prefix requirements; no
-- caller needs to know which model is active to embed text correctly.
function M.format_embedding_prompt(text)
    local cfg = M.get_selected_model_config()
    local prefix = cfg and cfg.embedding_prompt_prefix
    if prefix and prefix ~= "" then
        return prefix .. text
    end
    return text
end
-- }}}

-- {{{ get_selected_model_config
-- { model, model_path, embedding_prompt_prefix } for the selected model, from
-- its entry in the selected server's available_models. This is what lets one
-- server serve several local GGUFs, each asked in its own phrasing. A model
-- the server does not list is an error: there is no server-level path or
-- prefix to fall back on, and embedding without the model's prefix would
-- quietly produce vectors in the wrong part of its space.
function M.get_selected_model_config()
    local server = M.get_selected_server()
    local model = M.get_selected_model()
    for _, entry in ipairs(server.available_models or {}) do
        if entry.model == model then
            return {
                model = model,
                model_path = entry.model_path,
                embedding_prompt_prefix = entry.embedding_prompt_prefix,
            }
        end
    end
    error(string.format(
        "inference-server-config: server '%s' does not list model '%s' (it lists: %s)",
        server.name, model, table.concat(M.model_names(server), ", ")))
end
-- }}}

return M
