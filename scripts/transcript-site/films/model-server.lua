-- model-server.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Part of the films (films/). Taken from double-diaper-dungeon's
-- src/063-model-server.lua (issue 035d).
--
-- Talks to the local model server: asks the vision model about a picture, and
-- turns text into lists of numbers.
--
-- The server is Ollama, running on this computer and listening only here. It
-- speaks HTTP with JSON, so every call is: write the request to a file in RAM,
-- have curl send that file, read the answer back from another file. Going
-- through files rather than the command line means a message's text never
-- meets shell quoting, however many quotes and dollar signs it holds.
--
-- Every failure raises, with the server's own words when it gave any. There is
-- no "no answer, carry on" here: a film with no description, or a message with
-- no numbers, would be chosen for by nothing, and the page would show a film
-- that was picked by accident while looking as though it meant something.

local M = {}

-- This folder; the JSON library is in the library's shared libs/.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function json()
-- The JSON library, David Kolf's dkjson, from the library's own copy. Loaded
-- by path rather than through require, so a different dkjson somewhere on
-- the machine's search path can never be the one that answers.
local JSON = nil
local function json()
  if not JSON then
    JSON = dofile(HERE .. "../libs/dkjson.lua")
  end
  return JSON
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end
-- }}}

-- {{{ local function spit()
local function spit(path, text)
  local file = assert(io.open(path, "wb"))
  file:write(text)
  file:close()
end
-- }}}

-- {{{ local function post()
-- Sends one JSON request and returns the decoded answer. `seconds` is how long
-- to wait before giving up; loading a large model the first time takes a
-- couple of minutes, so the callers pass generous numbers.
local function post(client, route, request, seconds)
  local lib = json()
  local ask = client.scratch .. "/model-request.json"
  local answer = client.scratch .. "/model-answer.json"
  spit(ask, lib.encode(request))
  os.remove(answer)
  local command = string.format(
    "curl -s -S --max-time %d -o '%s' -w '%%{http_code}' -d @'%s' 'http://%s%s'",
    seconds, answer, ask, client.address, route)
  local pipe = io.popen(command .. " 2>&1", "r")
  local status = pipe:read("*a")
  pipe:close()

  -- curl prints the HTTP status, three digits, and nothing else when the
  -- server answered. Anything else is curl's own complaint: no server, or
  -- out of time.
  if not status:match("^%d%d%d$") then
    error("the model server at " .. client.address .. " did not answer: " .. status)
  end
  local body = slurp(answer)
  local decoded = lib.decode(body)
  if status ~= "200" then
    local said = type(decoded) == "table" and decoded.error or body
    error("the model server said " .. status .. ": " .. tostring(said))
  end
  if type(decoded) ~= "table" then
    error("the model server's answer was not JSON: " .. body:sub(1, 200))
  end
  return decoded
end
-- }}}

-- {{{ function M.new()
-- A client for the server at `address` ("host:port"). Request and answer
-- files go in `scratch`, which should be in RAM: tmp/shared-memory.
function M.new(address, scratch)
  os.execute("mkdir -p '" .. scratch .. "'")
  return { address = address, scratch = scratch }
end
-- }}}

-- {{{ function M.alive()
-- Whether the server answers at all. Asked once, before a run, so a stopped
-- server is reported in one plain sentence rather than as the first film's
-- failure.
function M.alive(client)
  local pipe = io.popen(string.format(
    "curl -s -o /dev/null -w '%%{http_code}' --max-time 5 'http://%s/api/tags'",
    client.address), "r")
  local status = pipe:read("*a")
  pipe:close()
  return status == "200"
end
-- }}}

-- {{{ function M.describe()
-- Shows the model one picture with one instruction and returns what it wrote,
-- a string. The picture travels inside the request as base64, which is the
-- picture's bytes spelled out in letters so it fits in JSON.
function M.describe(client, model, prompt, image_path)
  local pipe = io.popen("base64 -w0 '" .. image_path .. "'", "r")
  local encoded = pipe:read("*a")
  pipe:close()
  if encoded == "" then error("could not read the picture " .. image_path) end
  local answer = post(client, "/api/generate", {
    model = model, prompt = prompt, images = { encoded }, stream = false,
  }, 600)
  local text = answer.response
  if type(text) ~= "string" or text:match("^%s*$") then
    error("the vision model gave an empty description for " .. image_path)
  end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ function M.embed()
-- Turns a list of strings into a list of vectors, in the same order. A vector
-- is a list of numbers (768 for the model chosen here) placed so that similar
-- meanings sit close together. Sent in one request, because the model is
-- loaded once either way and one request is far faster than many.
function M.embed(client, model, texts)
  local answer = post(client, "/api/embed", {
    model = model, input = texts, truncate = true,
  }, 600)
  local vectors = answer.embeddings
  if type(vectors) ~= "table" or #vectors ~= #texts then
    error(string.format("asked for %d lists of numbers and got %s",
      #texts, type(vectors) == "table" and #vectors or "none"))
  end
  return vectors
end
-- }}}

return M
