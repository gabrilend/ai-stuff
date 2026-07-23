#!/usr/bin/env luajit
-- llama-chat-client.lua — the single choke-point through which delta-version's
-- transcript tooling talks to the project-local llama.cpp chat server.
--
-- General description (for the CEO): this is the "phone line" to the local AI.
-- It dials a fixed number (an inference server running on the GPU box), reads
-- it a block of text, and hands back what the AI says. It also offers a "how
-- long is this?" service (token counting) so the summarizer upstream knows how
-- much text it can send at once without overflowing the AI's memory.
--
-- Why llama.cpp and not Ollama: the inference stack migrated to a llama.cpp
-- server (words-pdf, "Issue 025") serving Qwen3-8B on an OpenAI-compatible
-- /v1/chat/completions. The older issue-049d design pointed at Ollama's
-- /api/generate, which no longer exists here.
--
-- This file is meant to be `require`d as a library. It also runs standalone as
-- a small CLI (--ping / --tokens / --prompt) for testing the line by hand.

-- {{{ DIR + shared-library resolution
-- The client itself keeps no project-local state, but it must find the shared
-- dkjson encoder. Everything is anchored on AISTUFF_ROOT, hard-coded per house
-- convention and overridable from the environment so the file runs unchanged
-- from any working directory.
local AISTUFF_ROOT = os.getenv("AISTUFF_ROOT") or "/home/ritz/programming/ai-stuff"
package.path = AISTUFF_ROOT .. "/libs/lua/?.lua;" .. package.path
local dkjson = require("dkjson")
-- }}}

local M = {}

-- {{{ endpoint state + M.configure()
-- The endpoint is resolved once here and can be re-pointed by callers or by the
-- INFERENCE_CHAT_HOST env var (which replaces the whole host:port, mirroring
-- words-pdf/libs/inference-server-config.lua). There is deliberately no probing
-- and no fallback list: a caller that cannot reach the configured server should
-- fail loudly, not silently talk to "whatever answered first".
local config = {
   host    = "192.168.1.100",
   port    = 20166,
   model   = "Qwen3-8B",   -- server --alias; llama-server ignores it but the API wants a value
   timeout = 300,          -- seconds; a full-chunk summary can be slow, so be generous
}

-- {{{ local function endpoint_base()
-- Build the "http://host:port" prefix, honoring the env override. The override
-- replaces host and port together — a partial override would be more machinery
-- than this one knob deserves.
local function endpoint_base()
   local override = os.getenv("INFERENCE_CHAT_HOST")
   if override and override ~= "" then
      return "http://" .. override
   end
   return string.format("http://%s:%d", config.host, config.port)
end
-- }}}

-- {{{ function M.configure(opts)
-- Point the client at a different server or change defaults. Any omitted field
-- keeps its current value. Returns the module for chaining.
function M.configure(opts)
   opts = opts or {}
   if opts.host    then config.host    = opts.host    end
   if opts.port    then config.port    = opts.port    end
   if opts.model   then config.model   = opts.model   end
   if opts.timeout then config.timeout = opts.timeout end
   return M
end
-- }}}
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
-- }}}

-- {{{ local function http_post_json(path, body, timeout)
-- POST a Lua table as JSON to <endpoint><path> and return the decoded reply.
-- The body is written to a unique temp file and handed to curl with -d @file:
-- unique names (os.tmpname) keep back-to-back calls from reading each other's
-- half-written bodies, and a file avoids shell-escaping a huge JSON payload on
-- the command line. Returns decoded_table on success, or nil,err on any failure
-- (curl error, empty reply, JSON parse failure, or a server {"error":...}).
local function http_post_json(path, body, timeout)
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
      "curl -sS --max-time %d -w '\\n%%{http_code}' -X POST %s%s "
         .. "-H 'Content-Type: application/json' -d @%s > %s 2>%s.err",
      timeout or config.timeout, endpoint_base(), path, input_file, output_file, output_file)

   local ok = os.execute(curl_cmd)

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
      return nil, "no reply from " .. endpoint_base() .. path
         .. (curl_err ~= "" and (" (" .. curl_err:gsub("%s+$", "") .. ")") or "")
   end

   -- Peel the status code off the last line that -w appended.
   local http_code = reply:match("(%d%d%d)%s*$") or "000"
   local body_text = reply:gsub("%d%d%d%s*$", "")

   -- HTTP 000 means curl never got a response line — the connection failed
   -- (server down, wrong host, timeout). Say so plainly instead of blaming the
   -- (empty) body on a parse error.
   if http_code == "000" then
      return nil, "unreachable: " .. endpoint_base() .. path
         .. (curl_err ~= "" and (" (" .. curl_err:gsub("%s+$", "") .. ")") or "")
         .. "; start the server with words-pdf/scripts/start-llamacpp-server.sh"
   end

   local decoded = dkjson.decode(body_text)
   if not decoded then
      return nil, string.format("could not parse reply (HTTP %s) from %s%s",
         http_code, endpoint_base(), path)
   end
   if decoded.error then
      local msg = type(decoded.error) == "table"
         and (decoded.error.message or dkjson.encode(decoded.error))
         or tostring(decoded.error)
      return nil, "server error (HTTP " .. http_code .. "): " .. msg
   end
   return decoded
end
-- }}}

-- {{{ local function http_get_code(path, timeout)
-- Lightweight reachability probe: return the numeric HTTP status of a GET, or
-- "000" if the connection never completed. Used by M.is_reachable().
local function http_get_code(path, timeout)
   local cmd = string.format(
      "curl -s -o /dev/null -w '%%{http_code}' --max-time %d %s%s",
      timeout or 5, endpoint_base(), path)
   local h = io.popen(cmd)
   local code = h and h:read("*all") or "000"
   if h then h:close() end
   return (code or "000"):gsub("%s+", "")
end
-- }}}

-- {{{ function M.is_reachable()
-- True when the chat server answers GET /v1/models with 200. This is the same
-- readiness surface start-llamacpp-server.sh waits on, so agreement is exact.
function M.is_reachable()
   return http_get_code("/v1/models") == "200"
end
-- }}}

-- {{{ function M.count_tokens(text)
-- Exact token count via the server's /tokenize endpoint. Returns an integer, or
-- nil,err. The summarizer uses this to fill each chunk right up to the context
-- budget without tripping the "input too large" batch error — far more precise
-- than a chars-per-token estimate. Empty text short-circuits to 0 (no request).
function M.count_tokens(text)
   if not text or text == "" then return 0 end
   local decoded, err = http_post_json("/tokenize", { content = sanitize_utf8(text) })
   if not decoded then return nil, err end
   if type(decoded.tokens) == "table" then
      return #decoded.tokens
   end
   return nil, "unexpected /tokenize reply shape"
end
-- }}}

-- {{{ function M.chat(messages, opts)
-- Send an OpenAI-style messages array and return the assistant's text.
-- messages: { {role="system", content=...}, {role="user", content=...}, ... }.
-- opts: temperature (default 0.3, chosen for stable factual summaries),
-- max_tokens, timeout, model. Returns content_string, or nil,err.
function M.chat(messages, opts)
   opts = opts or {}
   -- Defensive copy with sanitized content so a corrupt byte anywhere in the
   -- transcript can't 500 the whole request.
   local clean = {}
   for i, m in ipairs(messages) do
      clean[i] = { role = m.role, content = sanitize_utf8(m.content) }
   end
   local body = {
      model       = opts.model or config.model,
      messages    = clean,
      temperature = opts.temperature or 0.3,
      stream      = false,
   }
   if opts.max_tokens then body.max_tokens = opts.max_tokens end

   local decoded, err = http_post_json("/v1/chat/completions", body, opts.timeout)
   if not decoded then return nil, err end
   if decoded.choices and decoded.choices[1] and decoded.choices[1].message then
      return decoded.choices[1].message.content
   end
   return nil, "reply had no choices[1].message.content"
end
-- }}}

-- {{{ function M.complete(system_prompt, user_text, opts)
-- Convenience wrapper for the common one-shot case: a system instruction plus a
-- single user block. Returns the same as M.chat.
function M.complete(system_prompt, user_text, opts)
   local messages = {}
   if system_prompt and system_prompt ~= "" then
      messages[#messages + 1] = { role = "system", content = system_prompt }
   end
   messages[#messages + 1] = { role = "user", content = user_text }
   return M.chat(messages, opts)
end
-- }}}

-- {{{ function M.endpoint()
-- Expose the resolved endpoint string, so callers can put it in error messages
-- ("start the server at <endpoint>") without re-deriving it.
function M.endpoint()
   return endpoint_base()
end
-- }}}

-- {{{ CLI entry point
-- Only runs when the file is executed directly (not when required). Provides
-- three probes for testing the line by hand. Exits non-zero on failure so a
-- shell caller (or the operator) can tell up from down.
local function main(argv)
   local mode, payload
   local i = 1
   while argv[i] do
      local a = argv[i]
      if a:match("^%-%-dir=") then
         -- accepted for house-convention symmetry; the client keeps no project
         -- state, so the value is simply ignored here.
      elseif a == "--ping" then
         mode = "ping"
      elseif a == "--tokens" then
         mode, payload, i = "tokens", argv[i + 1], i + 1
      elseif a == "--prompt" then
         mode, payload, i = "prompt", argv[i + 1], i + 1
      elseif a == "-h" or a == "--help" then
         print("Usage: llama-chat-client.lua [--ping | --tokens TEXT | --prompt TEXT]")
         print("  Endpoint: " .. endpoint_base() .. "  (override with INFERENCE_CHAT_HOST)")
         return 0
      else
         io.stderr:write("Unknown argument: " .. a .. "\n")
         return 2
      end
      i = i + 1
   end

   if mode == "ping" then
      if M.is_reachable() then
         print("reachable: " .. endpoint_base())
         return 0
      end
      io.stderr:write("UNREACHABLE: " .. endpoint_base()
         .. "\n  Start it with words-pdf/scripts/start-llamacpp-server.sh\n")
      return 1
   elseif mode == "tokens" then
      local n, err = M.count_tokens(payload or "")
      if not n then io.stderr:write("error: " .. err .. "\n"); return 1 end
      print(n)
      return 0
   elseif mode == "prompt" then
      local out, err = M.complete("You are a concise assistant.", payload or "", {})
      if not out then io.stderr:write("error: " .. err .. "\n"); return 1 end
      print(out)
      return 0
   end

   io.stderr:write("Nothing to do. Try --ping, --tokens TEXT, or --prompt TEXT.\n")
   return 2
end

-- Detect direct execution: when required as a library, `arg` is nil or the
-- script is not arg[0]. This guard keeps `require("llama-chat-client")` silent.
if arg and arg[0] and arg[0]:match("llama%-chat%-client%.lua$") then
   os.exit(main(arg))
end
-- }}}

return M
