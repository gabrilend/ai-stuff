-- film-matcher.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Part of the films (films/). Taken from double-diaper-dungeon's
-- src/065-film-matcher.lua (issue 035d).
--
-- Chooses a film for every message by meaning, keeps neighbours different, and
-- writes each choice down for good.
--
-- HOW A MESSAGE FINDS ITS FILM. Every film has a description (the describer
-- wrote it), and every message has its words. Both are turned into lists of
-- 768 numbers by the same model, which places similar meanings near each
-- other. "Near" is measured as the angle between two lists: the cosine of that
-- angle is 1 when they point the same way and falls toward 0 as they part. A
-- message gets the film whose description points most nearly its way.
--
-- EACH SIDE IS MEASURED FROM ITS OWN MIDDLE. The first full run compared the
-- raw lists and one film won 120 of 288 messages, a second won 60, and
-- fourteen films were never chosen at all. The descriptions all share a lot
-- of wording ("the animation features... calm, dreamy"), and so do the
-- messages (code, issues, design), so most of each list is the part every
-- film or every message has in common, and a film whose common part happened
-- to lean toward the messages' common part won almost everything. Taking each
-- side's own average away first leaves only what makes one film different
-- from the other films and one message different from the other messages.
-- Tried on the same 294 messages: all 34 films used, the busiest 44 times.
--
-- The films' average is worked out fresh every run, from the films, which is
-- the same every run while the folder is the same. The messages' average is
-- measured once, from every message there is at the time, and kept in a file
-- (settings.message_centre_file), because a middle that moved every time a
-- message was added would measure new messages against a different middle
-- from the old ones. Delete the file to measure it again.
--
-- NEIGHBOURS ALWAYS LOOK DIFFERENT. Her rule, 2026-10-02. If the nearest film
-- is the one just before or just after this message, it takes the next
-- nearest, and so on down the list.
--
-- A CHOICE IS WRITTEN DOWN, NOT WORKED OUT AGAIN. Her words: "The same message
-- always gets the same gif, which is why we only update the gifs for new or
-- modified messages." So each conversation has a choices file, and a message
-- whose key is already in it keeps its film without asking any model. Only
-- new messages are matched. That is what makes the choice survive a new
-- model, a new film in the folder, or a rebuild on another computer.
--
-- A MESSAGE'S KEY is the SHA-256 of who said it and what they said. The same
-- words said twice in one conversation would share a key, and so a film,
-- which could put two identical films side by side; so the second one gets
-- ":2" on the end, the third ":3", and each is chosen for on its own. Edit a
-- message and its key changes, so it is matched again, as a new message.
--
-- The choices file is plain text, one message per line:
--   message key <tab> film fingerprint
-- in the order the messages were first matched. Lines are only ever added:
-- an edited message's old line stays, harmless, because nothing will ask for
-- that key again, and keeping it means the file never has to be rewritten in
-- a way that could lose a choice.
--
-- The harness's recaps get no film, and neither do the lines the harness
-- wrote above the first request. Both are said by neither speaker.
--
-- THIS FILE READS NO TRANSCRIPT. The films are their own part of the
-- library, so the conversations are read by the caller -- the library's
-- joining file -- and handed in as tables. That is also what keeps a
-- project's choices about which turns exist (the harness lines on or off)
-- the same here as on the page.

local M = {}

-- This folder, where the describer and the model server's files sit.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function shell()
local function shell(command)
  local pipe = io.popen(command, "r")
  local out = pipe:read("*a")
  pipe:close()
  return out
end
-- }}}

-- Which kinds of turn get a film. A dispatch table, so a new kind is a row.
local FILMED = { user = true, assistant = true, recap = false, harness = false, context = false }

-- {{{ function M.cosine()
-- How nearly two lists of numbers point the same way: 1 is the same
-- direction, 0 is unrelated. Both lists must be the same length.
function M.cosine(a, b)
  if #a ~= #b then error("cannot compare lists of " .. #a .. " and " .. #b .. " numbers") end
  local dot, aa, bb = 0, 0, 0
  for i = 1, #a do
    dot = dot + a[i] * b[i]
    aa = aa + a[i] * a[i]
    bb = bb + b[i] * b[i]
  end
  if aa == 0 or bb == 0 then error("a list of numbers was all zeros") end
  return dot / math.sqrt(aa * bb)
end
-- }}}

-- {{{ function M.average()
-- The average of a list of lists of numbers, position by position.
function M.average(lists)
  if #lists == 0 then error("cannot average no lists") end
  local out = {}
  for i = 1, #lists[1] do out[i] = 0 end
  for _, list in ipairs(lists) do
    if #list ~= #out then error("cannot average lists of different lengths") end
    for i = 1, #list do out[i] = out[i] + list[i] end
  end
  for i = 1, #out do out[i] = out[i] / #lists end
  return out
end
-- }}}

-- {{{ function M.minus()
-- One list of numbers with another taken away, position by position.
function M.minus(list, centre)
  local out = {}
  for i = 1, #list do out[i] = list[i] - centre[i] end
  return out
end
-- }}}

-- {{{ function M.rank()
-- Every film, nearest first, for one message's numbers. `films` is a list of
-- { hash, vector }. Ties go to the film earlier in the list, so a rank is the
-- same every time.
function M.rank(vector, films)
  local scored = {}
  for i, film in ipairs(films) do
    scored[i] = { hash = film.hash, score = M.cosine(vector, film.vector), order = i }
  end
  table.sort(scored, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.order < b.order
  end)
  return scored
end
-- }}}

-- {{{ function M.choose()
-- The rules alone, with no files and no models, which is what the test runs.
--
--   keys     list of message keys, in page order, filmed messages only
--   stored   table: key -> film fingerprint, the choices already written
--   films    list of { hash, vector }, every film that can be chosen
--   vectors  table: key -> list of numbers, for every key not in `stored`
--   reach    how many messages either side count as neighbours
--
-- Returns two things: the film for every position, a list in page order; and
-- the new choices alone, as a list of { key, hash } in the order they were
-- made, ready to be added to the file.
--
-- A stored choice is never changed, even if it now sits beside its twin; the
-- new messages around it step aside instead.
function M.choose(keys, stored, films, vectors, reach)
  if #films <= 2 * reach then
    error(string.format("%d films cannot keep %d neighbours on each side different",
      #films, reach))
  end
  local chosen = {}
  local made = {}
  local fresh = {}

  -- Stored choices first, so a new message can see a stored neighbour that
  -- comes after it.
  for i, key in ipairs(keys) do
    if stored[key] then chosen[i] = stored[key] end
  end

  for i, key in ipairs(keys) do
    if not chosen[i] then
      if made[key] then
        -- The same key twice in one batch cannot happen, because keys are
        -- numbered apart; this would mean the numbering broke.
        error("message key " .. key .. " came up twice")
      end
      local vector = vectors[key]
      if not vector then error("no numbers for message " .. key) end
      local nearby = {}
      for j = math.max(1, i - reach), math.min(#keys, i + reach) do
        if j ~= i and chosen[j] then nearby[chosen[j]] = true end
      end
      for _, candidate in ipairs(M.rank(vector, films)) do
        if not nearby[candidate.hash] then
          chosen[i] = candidate.hash
          break
        end
      end
      made[key] = true
      fresh[#fresh + 1] = { key = key, hash = chosen[i] }
    end
  end
  return chosen, fresh
end
-- }}}

-- {{{ function M.message_keys()
-- One key per exchange of a conversation, in order: a string for a filmed
-- turn, false for a recap. `scratch` is a folder in RAM; each message is
-- written there as a file and the whole set is fingerprinted by one call to
-- sha256sum, which is far quicker than one call per message.
function M.message_keys(conversation, scratch)
  local folder = scratch .. "/message-keys"
  os.execute("rm -rf '" .. folder .. "' && mkdir -p '" .. folder .. "'")
  local any = false
  for i, exchange in ipairs(conversation.exchanges) do
    if FILMED[exchange.kind] == nil then
      error("no rule for whether a " .. tostring(exchange.kind) .. " turn gets a film")
    end
    if FILMED[exchange.kind] then
      local file = assert(io.open(string.format("%s/%06d", folder, i), "wb"))
      file:write(exchange.kind, "\n", exchange.body)
      file:close()
      any = true
    end
  end

  local hashes = {}
  if any then
    for hash, index in shell("sha256sum '" .. folder .. "'/*"):gmatch("(%x+)  [^\n]-/(%d+)\n") do
      hashes[tonumber(index)] = hash
    end
  end

  local keys = {}
  local seen = {}
  for i, exchange in ipairs(conversation.exchanges) do
    if FILMED[exchange.kind] then
      local hash = hashes[i]
      if not hash then error("message " .. i .. " was not fingerprinted") end
      seen[hash] = (seen[hash] or 0) + 1
      keys[i] = seen[hash] == 1 and hash or (hash .. ":" .. seen[hash])
    else
      keys[i] = false
    end
  end
  return keys
end
-- }}}

-- {{{ function M.read_choices()
-- A choices file as a table: key -> film fingerprint. A missing file is a
-- conversation nobody has matched yet, and is empty; a malformed line is an
-- error.
function M.read_choices(path)
  local found = {}
  local file = io.open(path, "r")
  if not file then return found end
  local number = 0
  for line in file:lines() do
    number = number + 1
    if line ~= "" then
      local key, hash = line:match("^([%x:%d]+)\t(%x+)$")
      if not key then
        file:close()
        error(string.format("%s line %d is not a message key and a film", path, number))
      end
      found[key] = hash
    end
  end
  file:close()
  return found
end
-- }}}

-- {{{ function M.add_choices()
-- Adds new choices to the end of a choices file, making it if need be. Never
-- rewrites what is there.
function M.add_choices(path, fresh)
  if #fresh == 0 then return end
  os.execute("mkdir -p '" .. path:match("^(.*)/") .. "'")
  local file = assert(io.open(path, "a"))
  for _, choice in ipairs(fresh) do
    file:write(choice.key, "\t", choice.hash, "\n")
  end
  file:close()
end
-- }}}

-- {{{ function M.read_centre()
-- The kept middle of the messages, a list of numbers, or nil when it has not
-- been measured yet -- which is the one case the caller handles by measuring.
-- A file that exists but holds something other than numbers is an error.
function M.read_centre(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local out = {}
  for line in file:lines() do
    local n = tonumber(line)
    if not n then
      file:close()
      error(path .. " holds a line that is not a number: " .. line)
    end
    out[#out + 1] = n
  end
  file:close()
  if #out == 0 then error(path .. " is empty; delete it to measure again") end
  return out
end
-- }}}

-- {{{ function M.write_centre()
-- Keeps the middle, one number per line, written in full so reading it back
-- gives the same numbers.
function M.write_centre(path, centre)
  os.execute("mkdir -p '" .. path:match("^(.*)/") .. "'")
  local file = assert(io.open(path, "w"))
  for _, n in ipairs(centre) do file:write(string.format("%.17g\n", n)) end
  file:close()
end
-- }}}

-- {{{ function M.choices_path()
-- Where one transcript's choices live: the choices folder, the transcript's
-- name with .tsv in place of .md.
function M.choices_path(settings, transcript_name)
  return settings.choices_folder .. "/" .. transcript_name:gsub("%.md$", "") .. ".tsv"
end
-- }}}

-- {{{ function M.films_for_page()
-- What the page needs: for each exchange of a conversation, the film's file
-- name, or false for a turn with no film (a recap, or a message not matched
-- yet). `names` is fingerprint -> file name, from the descriptions file.
-- Returns the list, and how many filmed messages had no choice yet.
function M.films_for_page(conversation, keys, choices, names)
  local list = {}
  local unmatched = 0
  for i, key in ipairs(keys) do
    if key then
      local hash = choices[key]
      if hash then
        local name = names[hash]
        if not name then
          error("a message was given film " .. hash .. ", which has no description; " ..
                "was it removed from the film folder?")
        end
        list[i] = name
      else
        list[i] = false
        unmatched = unmatched + 1
      end
    else
      list[i] = false
    end
  end
  return list, unmatched
end
-- }}}

-- {{{ function M.run()
-- The whole job: describe any new film, then match every message that has
-- no film yet. Prints what it did.
--
--   settings       a project's films table, paths absolute
--   conversations  list of { name = <transcript file name, string>,
--                  conversation = <table from the transcript reader> },
--                  every transcript the project has, read by the caller
--   scratch        a folder in RAM for working files
function M.run(settings, conversations, scratch)
  local server = dofile(HERE .. "model-server.lua")
  local describer = dofile(HERE .. "film-describer.lua")
  os.execute("mkdir -p '" .. scratch .. "'")

  local client = server.new(settings.server, scratch)
  if not server.alive(client) then
    error("the model server is not running at " .. settings.server ..
          "; start it with the library's start-the-film-models")
  end

  print("Looking at the films.")
  local films, described = describer.describe_new(settings, client, scratch)
  print(string.format("  %d films, %d newly described", #films, described))

  -- Every transcript's new messages, gathered first, so the films' numbers
  -- are only worked out when there is something to match.
  local work = {}
  local wanted = 0
  -- Every filmed message's text, for measuring the messages' middle the
  -- first time; not used once that is kept.
  local every_text = {}
  for _, entry in ipairs(conversations) do
    local name, conversation = entry.name, entry.conversation
    do
      local keys = M.message_keys(conversation, scratch)
      local path = M.choices_path(settings, name)
      local stored = M.read_choices(path)
      local order, texts = {}, {}
      for i, key in ipairs(keys) do
        if key then
          order[#order + 1] = key
          every_text[#every_text + 1] = conversation.exchanges[i].body:sub(1, settings.message_characters)
          if not stored[key] then
            texts[key] = conversation.exchanges[i].body:sub(1, settings.message_characters)
            wanted = wanted + 1
          end
        end
      end
      work[#work + 1] = { name = name, path = path, order = order, stored = stored, texts = texts }
    end
  end

  if wanted == 0 then
    print("Every message already has its film.")
    return
  end

  print(string.format("Matching %d new messages.", wanted))
  local descriptions = describer.read_descriptions(settings.descriptions_file)
  local film_texts = {}
  for i, film in ipairs(films) do film_texts[i] = descriptions[film.hash].text end
  local film_vectors = server.embed(client, settings.embedding_model, film_texts)
  local film_middle = M.average(film_vectors)
  local candidates = {}
  for i, film in ipairs(films) do
    candidates[i] = { hash = film.hash, vector = M.minus(film_vectors[i], film_middle) }
  end

  -- Messages are sent in batches of 32: one request for everything at once
  -- can be large enough to time out on a first run of thousands.
  local function embed_all(texts)
    local out = {}
    for first = 1, #texts, 32 do
      local batch = {}
      for i = first, math.min(#texts, first + 31) do batch[#batch + 1] = texts[i] end
      local got = server.embed(client, settings.embedding_model, batch)
      for i = 1, #batch do out[first + i - 1] = got[i] end
    end
    return out
  end

  local message_middle = M.read_centre(settings.message_centre_file)
  if not message_middle then
    print(string.format("Measuring the middle of all %d messages, once.", #every_text))
    message_middle = M.average(embed_all(every_text))
    M.write_centre(settings.message_centre_file, message_middle)
  end

  for _, job in ipairs(work) do
    local keys, texts = {}, {}
    for key, text in pairs(job.texts) do keys[#keys + 1] = key; texts[#texts + 1] = text end
    if #keys > 0 then
      local vectors = {}
      for i, got in ipairs(embed_all(texts)) do
        vectors[keys[i]] = M.minus(got, message_middle)
      end
      local _, fresh = M.choose(job.order, job.stored, candidates, vectors, settings.neighbour_reach)
      M.add_choices(job.path, fresh)
      print(string.format("  %s: %d new", job.name, #fresh))
    end
  end
end
-- }}}

return M
