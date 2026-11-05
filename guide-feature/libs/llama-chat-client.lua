#!/usr/bin/env luajit
-- llama-chat-client.lua — the single choke-point through which guide-feature
-- talks to its llama.cpp servers.
--
-- A copy of delta-version's client (libs/llama-chat-client.lua.upstream names
-- the source and its commit). This project's changes are made here, in the
-- copy, and listed in that note: an endpoint record per call, an embedding
-- call, and nothing loaded from outside the project.
--
-- General description (for the CEO): this is the "phone line" to the local AI.
-- It dials the number it is handed (an inference server named in the project's
-- endpoints file), reads it a block of text, and hands back what the AI says.
-- It also offers a "how long is this?" service (token counting) and, for the
-- embedding servers, a "where does this text sit in meaning?" service.
--
-- Every call takes an endpoint record:
--   { name = "kuvalu-chat", url = "http://host:port", timeout = 300 }
-- name is only used in messages; url is the server; timeout is the whole
-- request's limit in seconds.
--
-- This file is meant to be `require`d (or dofile'd) as a library. It also runs
-- standalone as a small CLI (--ping / --tokens / --prompt / --embed) for
-- testing the line by hand.

-- {{{ DIR + dkjson
-- The client keeps no state, but it needs dkjson, which this project keeps its
-- own copy of beside this file (libs/dkjson.lua). Found from this file's own
-- path, so the client runs from any working directory and never reaches into
-- another project.
local LIBS = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
local dkjson = dofile(LIBS .. "/dkjson.lua")
-- }}}

local M = {}

-- {{{ local function endpoint_base(endpoint)
-- The "http://host:port" prefix of an endpoint record, without a trailing
-- slash. There is deliberately no probing and no fallback list: a caller that
-- cannot reach the endpoint it was handed fails loudly, not silently talking to
-- "whatever answered first".
local function endpoint_base(endpoint)
   return (endpoint.url:gsub("/+$", ""))
end
-- }}}

-- {{{ local function sanitize_utf8(s)
-- Replace ill-formed UTF-8 byte sequences with U+FFFD. The server's JSON parser
-- rejects invalid UTF-8 with HTTP 500, and real transcripts contain corrupt
-- bytes (line-wrapping through multi-byte box-drawing characters is the usual
-- culprit). The substitution is lossy but localized; the rest of the string is
-- untouched. Borrowed in spirit from words-pdf/libs/fuzzy-computing.lua.
local function sanitize_utf8(s)
   if type(s) ~= "string" then return s end
   local out, i, n = {}, 1, #s
   while i <= n do
      local c = s:byte(i)
      local len, ok = 1, false
      if c < 0x80 then
         len, ok = 1, true
      elseif c >= 0xC2 and c <= 0xDF then
         len = 2
      elseif c >= 0xE0 and c <= 0xEF then
         len = 3
      elseif c >= 0xF0 and c <= 0xF4 then
         len = 4
      end
      if len > 1 then
         ok = (i + len - 1) <= n
         for j = 1, len - 1 do
            local cc = s:byte(i + j)
            if not cc or cc < 0x80 or cc > 0xBF then ok = false break end
         end
      end
      if ok then
         out[#out + 1] = s:sub(i, i + len - 1)
         i = i + len
      else
         out[#out + 1] = "\239\191\189"  -- U+FFFD
         i = i + 1
      end
   end
   return table.concat(out)
end
M.sanitize_utf8 = sanitize_utf8
-- }}}

-- {{{ local function http_post_json(endpoint, path, body)
-- POST a Lua table as JSON to <endpoint><path> and return the decoded reply.
-- The body is written to a unique temp file and handed to curl with -d @file:
-- unique names (os.tmpname) keep back-to-back calls from reading each other's
-- half-written bodies, and a file avoids shell-escaping a huge JSON payload on
-- the command line. Returns decoded_table on success, or nil,err on any failure
-- (curl error, empty reply, JSON parse failure, or a server {"error":...}).
local function http_post_json(endpoint, path, body)
   local json_data = dkjson.encode(body)
   local input_file  = os.tmpname()
   local output_file = os.tmpname()

   local f = io.open(input_file, "w")
   if not f then
      os.remove(input_file); os.remove(output_file)
      return nil, "could not open temp file for request body"
   end
   f:write(json_data)
   f:close()

   -- -sS: quiet but still print transport errors. -w captures the HTTP status
   -- on its own trailing line so we can tell "server said no" from "curl could
   -- not connect" without a second request.
   local curl_cmd = string.format(
      "curl -sS --max-time %d -w '\\n%%{http_code}' -X POST '%s%s' "
         .. "-H 'Content-Type: application/json' -d @%s > %s 2>%s.err",
      endpoint.timeout, endpoint_base(endpoint), path, input_file, output_file, output_file)

   os.execute(curl_cmd)

   local rf = io.open(output_file, "r")
   local reply = rf and rf:read("*all") or ""
   if rf then rf:close() end

   -- curl's stderr (connection refused, timeout, DNS) lands here; surface it.
   local ef = io.open(output_file .. ".err", "r")
   local curl_err = ef and ef:read("*all") or ""
   if ef then ef:close() end

   os.remove(input_file)
   os.remove(output_file)
   os.remove(output_file .. ".err")

   if reply == "" then
      return nil, "no reply from " .. endpoint_base(endpoint) .. path
         .. (curl_err ~= "" and (" (" .. curl_err:gsub("%s+$", "") .. ")") or "")
   end

   -- Peel the status code off the last line that -w appended.
   local http_code = reply:match("(%d%d%d)%s*$") or "000"
   local body_text = reply:gsub("%d%d%d%s*$", "")

   -- HTTP 000 means curl never got a response line — the connection failed
   -- (server down, wrong host, timeout). Say so plainly instead of blaming the
   -- (empty) body on a parse error.
   if http_code == "000" then
      return nil, "unreachable: " .. endpoint_base(endpoint) .. path
         .. (curl_err ~= "" and (" (" .. curl_err:gsub("%s+$", "") .. ")") or "")
         .. "; this project's own servers start with scripts/start-servers"
   end

   local decoded = dkjson.decode(body_text)
   if type(decoded) ~= "table" then
      return nil, string.format("could not parse reply (HTTP %s) from %s%s",
         http_code, endpoint_base(endpoint), path)
   end
   if decoded.error then
      local msg = type(decoded.error) == "table"
         and (decoded.error.message or dkjson.encode(decoded.error))
         or tostring(decoded.error)
      return nil, "server error (HTTP " .. http_code .. "): " .. msg
   end
   if http_code:sub(1, 1) ~= "2" then
      return nil, "server error (HTTP " .. http_code .. ") from "
         .. endpoint_base(endpoint) .. path
   end
   return decoded
end
-- }}}

-- {{{ local function http_get_code(endpoint, path)
-- Lightweight reachability probe: return the numeric HTTP status of a GET, or
-- "000" if the connection never completed. Used by M.is_reachable().
local function http_get_code(endpoint, path)
   local cmd = string.format(
      "curl -s -o /dev/null -w '%%{http_code}' --max-time %d '%s%s'",
      endpoint.timeout, endpoint_base(endpoint), path)
   local h = io.popen(cmd)
   local code = h and h:read("*all") or "000"
   if h then h:close() end
   return ((code or "000"):gsub("%s+", ""))
end
-- }}}

-- {{{ function M.is_reachable(endpoint)
-- True when the server answers GET /v1/models with 200. This is the same
-- readiness surface scripts/start-servers waits on, so agreement is exact.
function M.is_reachable(endpoint)
   return http_get_code(endpoint, "/v1/models") == "200"
end
-- }}}

-- {{{ function M.count_tokens(endpoint, text)
-- Exact token count via the server's /tokenize endpoint. Returns an integer, or
-- nil,err. Empty text short-circuits to 0 (no request).
function M.count_tokens(endpoint, text)
   if not text or text == "" then return 0 end
   local decoded, err = http_post_json(endpoint, "/tokenize", { content = sanitize_utf8(text) })
   if not decoded then return nil, err end
   if type(decoded.tokens) == "table" then
      return #decoded.tokens
   end
   return nil, "unexpected /tokenize reply shape"
end
-- }}}

-- {{{ function M.chat(endpoint, messages, opts)
-- Send an OpenAI-style messages array and return the assistant's text, and the
-- whole decoded reply (its `usage` holds the token counts).
-- messages: { {role="system", content=...}, {role="user", content=...}, ... }.
-- opts: temperature (default 0.3, chosen for stable factual summaries),
-- max_tokens, model. Returns content_string, decoded, or nil,err.
function M.chat(endpoint, messages, opts)
   opts = opts or {}
   -- Defensive copy with sanitized content so a corrupt byte anywhere in the
   -- conversation can't 500 the whole request.
   local clean = {}
   for i, m in ipairs(messages) do
      clean[i] = { role = m.role, content = sanitize_utf8(m.content) }
   end
   local body = {
      -- llama-server ignores the model name, but the API wants a value.
      model       = opts.model or endpoint.name,
      messages    = clean,
      temperature = opts.temperature or 0.3,
      stream      = false,
   }
   if opts.max_tokens then body.max_tokens = opts.max_tokens end

   local decoded, err = http_post_json(endpoint, "/v1/chat/completions", body)
   if not decoded then return nil, err end
   if type(decoded.choices) == "table" and type(decoded.choices[1]) == "table"
      and type(decoded.choices[1].message) == "table"
      and type(decoded.choices[1].message.content) == "string" then
      return decoded.choices[1].message.content, decoded
   end
   return nil, "reply had no choices[1].message.content"
end
-- }}}

-- {{{ function M.complete(endpoint, system_prompt, user_text, opts)
-- Convenience wrapper for the common one-shot case: a system instruction plus a
-- single user block. Returns the same as M.chat.
function M.complete(endpoint, system_prompt, user_text, opts)
   local messages = {}
   if system_prompt and system_prompt ~= "" then
      messages[#messages + 1] = { role = "system", content = system_prompt }
   end
   messages[#messages + 1] = { role = "user", content = user_text }
   return M.chat(endpoint, messages, opts)
end
-- }}}

-- {{{ function M.embed(endpoint, texts, opts)
-- Embeddings via the server's OpenAI-style /v1/embeddings (llama-server run
-- with --embeddings). texts is one string or a list of them. Returns a list of
-- vectors (lists of numbers), one per text in the order given, or nil,err.
-- opts: model. Added in guide-feature (issue 401b).
function M.embed(endpoint, texts, opts)
   opts = opts or {}
   local list = type(texts) == "table" and texts or { texts }
   if #list == 0 then return {} end
   local clean = {}
   for i, t in ipairs(list) do clean[i] = sanitize_utf8(t) end
   local decoded, err = http_post_json(endpoint, "/v1/embeddings",
      { model = opts.model or endpoint.name, input = clean })
   if not decoded then return nil, err end
   if type(decoded.data) ~= "table" then
      return nil, "unexpected /v1/embeddings reply shape"
   end
   -- Each item carries its own index; put them back in the order sent.
   local vectors = {}
   for position, item in ipairs(decoded.data) do
      if type(item) ~= "table" or type(item.embedding) ~= "table" then
         return nil, "unexpected /v1/embeddings reply shape"
      end
      local index = type(item.index) == "number" and item.index + 1 or position
      vectors[index] = item.embedding
   end
   for i = 1, #list do
      if not vectors[i] then
         return nil, "the reply has no embedding for text " .. i .. " of " .. #list
      end
   end
   return vectors
end
-- }}}

-- {{{ function M.endpoint(endpoint)
-- Expose the resolved address, so callers can put it in error messages
-- without re-deriving it.
function M.endpoint(endpoint)
   return endpoint_base(endpoint)
end
-- }}}

-- {{{ CLI entry point
-- Only runs when the file is executed directly (not when required). Provides
-- four probes for testing the line by hand. Exits non-zero on failure so a
-- shell caller (or the operator) can tell up from down.
local function main(argv)
   local mode, payload
   local endpoint = { name = "cli" }
   local i = 1
   while argv[i] do
      local a = argv[i]
      if a:match("^%-%-dir=") then
         -- accepted for house-convention symmetry; the client keeps no project
         -- state, so the value is simply ignored here.
      elseif a == "--url" then
         endpoint.url, i = argv[i + 1], i + 1
      elseif a == "--timeout" then
         endpoint.timeout, i = tonumber(argv[i + 1]), i + 1
      elseif a == "--ping" then
         mode = "ping"
      elseif a == "--tokens" then
         mode, payload, i = "tokens", argv[i + 1], i + 1
      elseif a == "--prompt" then
         mode, payload, i = "prompt", argv[i + 1], i + 1
      elseif a == "--embed" then
         mode, payload, i = "embed", argv[i + 1], i + 1
      elseif a == "-h" or a == "--help" then
         print("Usage: llama-chat-client.lua --url URL --timeout SECONDS"
            .. " [--ping | --tokens TEXT | --prompt TEXT | --embed TEXT]")
         return 0
      else
         io.stderr:write("Unknown argument: " .. a .. "\n")
         return 2
      end
      i = i + 1
   end
   if not endpoint.url or not endpoint.timeout then
      io.stderr:write("Give the server with --url URL and --timeout SECONDS.\n")
      return 2
   end

   if mode == "ping" then
      if M.is_reachable(endpoint) then
         print("reachable: " .. endpoint_base(endpoint))
         return 0
      end
      io.stderr:write("UNREACHABLE: " .. endpoint_base(endpoint)
         .. "\n  This project's own servers start with scripts/start-servers\n")
      return 1
   elseif mode == "tokens" then
      local n, err = M.count_tokens(endpoint, payload or "")
      if not n then io.stderr:write("error: " .. err .. "\n"); return 1 end
      print(n)
      return 0
   elseif mode == "prompt" then
      local out, err = M.complete(endpoint, "You are a concise assistant.", payload or "", {})
      if not out then io.stderr:write("error: " .. err .. "\n"); return 1 end
      print(out)
      return 0
   elseif mode == "embed" then
      local vectors, err = M.embed(endpoint, payload or "")
      if not vectors then io.stderr:write("error: " .. err .. "\n"); return 1 end
      print(dkjson.encode(vectors[1]))
      return 0
   end

   io.stderr:write("Nothing to do. Try --ping, --tokens TEXT, --prompt TEXT or --embed TEXT.\n")
   return 2
end

-- Detect direct execution: when loaded as a library, `arg` is nil or the
-- script is not arg[0]. This guard keeps a library load silent.
if arg and arg[0] and arg[0]:match("llama%-chat%-client%.lua$") then
   os.exit(main(arg))
end
-- }}}

return M
