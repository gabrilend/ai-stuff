-- 044-run-the-pictures.lua
--
-- Hands a recipe to a running ComfyUI and puts what comes back into the pool.
--
-- For a general: this is the only part of this project that talks to another
-- program. Everything up to here decided what a picture should be; this asks
-- for it and files the answer. It is an HTTP client and nothing else, and it
-- must not become anything else -- every decision about *what* to render was
-- made before it ran.
--
-- It also finds out whatever this project has been wrong about since the third
-- phase, all at once, because a workflow this project calls correct has never
-- been opened by the program it was written for.
--
--   luajit src/044-run-the-pictures.lua --chars 木火水
--   luajit src/044-run-the-pictures.lua --grade 1 --limit 20
--   luajit src/044-run-the-pictures.lua --phrases
--   luajit src/044-run-the-pictures.lua --chars 時語 --style photographic
--   luajit src/044-run-the-pictures.lua --chars 木 --resolution 1536
--   luajit src/044-run-the-pictures.lua --chars 休 --kitchen across

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local json = project.load("018-write-the-numbers")
local records = project.load("019-the-kanji-record")
local phrases = project.load("019a-a-phrase-is-a-record-too")
local one = project.load("030-make-one-kanji")
local workflow = project.load("029-the-workflow-for-one-kanji")
local paintbrush = project.load("024a-the-paintbrush")
local words = project.load("025-the-words-the-machine-reads")
local pool = project.load("045-the-pool-that-remembers")
local grader = project.load("046-two-ways-of-saying-it-is-good")
local heat = project.load("031a-when-the-machine-runs-hot")

local M = {}

-- {{{ quote(text)
local function quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ unescape(text)
-- A string out of the far end's reply, with its escapes turned back.
--
-- The far end writes JSON, and JSON may spell any character as \uXXXX -- which
-- it does for every character this project cares about, since they are all
-- kanji. Pulled out by pattern and used as-is, the filename for 木 comes back
-- as the eleven characters \u6728_00001_.png and no such file exists.
--
-- This is not a JSON reader and does not want to be. It is the unescaping of
-- one string, which is the only part of the reply this project reads.
local xml = project.load("011-scan-xml")
local function unescape(text)
  if not text then return nil end
  text = text:gsub("\\u(%x%x%x%x)", function(digits)
    return xml.utf8(tonumber(digits, 16))
  end)
  return (text:gsub("\\(.)", function(character)
    if character == "n" then return "\n" end
    if character == "t" then return "\t" end
    if character == "r" then return "\r" end
    return character
  end))
end
-- }}}

-- {{{ M.for_kitchen(settings, name)
-- The settings as they are for one of the other kitchens (`415`).
--
-- Each kitchen in `settings.kitchens` is a set of changes laid over the
-- sections of the settings -- kitchen, workflow, field -- and only what it
-- writes differs. A copy, never written into the shared table, because half
-- this project reads that table.
--
-- No name means the settings unchanged: the local kitchen. A name that is not
-- there is an error naming the ones that are, rather than a quiet return to
-- the local one -- a run aimed at another machine that silently ran here would
-- look exactly like it had worked.
function M.for_kitchen(settings, name)
  if not name then return settings end
  local changes = settings.kitchens and settings.kitchens[name]
  if not changes then
    local names = {}
    for known in pairs(settings.kitchens or {}) do names[#names + 1] = known end
    table.sort(names)
    error("there is no kitchen called '" .. tostring(name) .. "'. There is: " ..
          (#names > 0 and table.concat(names, ", ") or "none") ..
          " -- and, with no --kitchen, the local one.")
  end
  local copy = {}
  for key, value in pairs(settings) do copy[key] = value end
  for section, overrides in pairs(changes) do
    local merged = {}
    for key, value in pairs(settings[section] or {}) do merged[key] = value end
    for key, value in pairs(overrides) do merged[key] = value end
    copy[section] = merged
  end
  copy.kitchen_name = name
  return copy
end
-- }}}

-- {{{ M.system_stats(settings)
-- What the far end says about its own card, through its own /system_stats.
--
-- For a kitchen on another machine nvidia-smi answers about the wrong card --
-- this one -- so the far end is asked instead. Returns the same shape as
-- `M.card`, or nil if it would not say.
function M.system_stats(settings)
  local pipe = io.popen("curl --silent --show-error --max-time 6 " ..
                        quote(M.where(settings) .. "/system_stats") .. " 2>&1")
  local said = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  local total = tonumber(said:match('"vram_total"%s*:%s*(%d+)'))
  local free = tonumber(said:match('"vram_free"%s*:%s*(%d+)'))
  if not total or not free then return nil end
  local gigabyte = 1024 * 1024 * 1024
  return { total = total / gigabyte, free = free / gigabyte,
           used = (total - free) / gigabyte, far = true }
end
-- }}}

-- {{{ M.card(settings)
-- What the graphics card says about itself, or nil if it will not say.
--
-- Total memory, how much is in use, and how much is free -- in gigabytes.
-- The card asked is the kitchen's: this machine's through nvidia-smi, or the
-- far end's through its own report when the kitchen is elsewhere.
function M.card(settings)
  if settings and settings.kitchen and settings.kitchen.here == false then
    return M.system_stats(settings)
  end
  local pipe = io.popen("nvidia-smi --query-gpu=memory.total,memory.used," ..
                        "memory.free --format=csv,noheader,nounits 2>/dev/null")
  local line = pipe and pipe:read("*l") or nil
  if pipe then pipe:close() end
  if not line then return nil end
  local total, used, free = line:match("(%d+),%s*(%d+),%s*(%d+)")
  if not total then return nil end
  return { total = tonumber(total) / 1024, used = tonumber(used) / 1024,
           free = tonumber(free) / 1024 }
end
-- }}}

-- {{{ M.is_the_display_card(card, settings)
-- Whether the card that would draw the pictures is also drawing the screen.
--
-- WHY THIS IS ASKED AT ALL, and it is the whole of `409`. This project reasoned
-- carefully about the processor getting hot and never asked the same question
-- about the card -- on the grounds that generating is the card's work rather
-- than the processor's, so the processor's governor did not apply. True, and it
-- answered the wrong question. On a machine with one graphics card, that card
-- is drawing somebody's desktop; take its memory and the desktop stops
-- responding, which from outside is not a slow computer but a frozen one.
--
-- A card with a desktop on it is never at zero before anything of ours has run.
-- That is the tell, and it is asked rather than assumed.
--
-- Except on a card in another machine, where the tell does not work: the far
-- end's own program is already holding memory, so the card is never at zero
-- whether or not a screen is on it. That kitchen says in the settings what is
-- known (`shares_a_screen`), and says it is assumed when nobody knows.
function M.is_the_display_card(card, settings)
  local declared = settings and settings.kitchen and
                   settings.kitchen.shares_a_screen
  if declared ~= nil then return declared end
  if not card then return false end
  return card.used > 0.05
end
-- }}}

-- {{{ M.room_to_work(settings)
-- Whether there is enough of the card free to start a picture.
--
-- Asked before submitting rather than discovered by submitting. A run that
-- wedged the display cannot tell anybody anything; one that stopped early can.
function M.room_to_work(settings)
  local card = M.card(settings)
  if not card then return true, nil end
  local least = (settings.kitchen and settings.kitchen.least_free_vram) or 0
  if card.free >= least then return true, card end
  return false, card
end
-- }}}

-- {{{ M.where(settings)
-- The address the picture program is listening on.
function M.where(settings)
  local kitchen = settings.kitchen or {}
  return kitchen.url or "http://127.0.0.1:8188"
end
-- }}}

-- {{{ M.upload(settings, path, name)
-- One input picture, handed to the picture program over HTTP.
--
-- It names its inputs by filename and looks in its own folder -- it does not
-- take a path. This used to be met by copying the pictures into that folder,
-- which only works when the folder is on this machine. Posted to its upload
-- address instead, the picture lands in the same folder whichever house the
-- program lives in, so there is one route rather than two (`415`).
--
-- `name` is what the workflow calls it, "kanji/00006728-field.png": the folder
-- part goes as the subfolder, the rest as the filename. Overwrite is on, so a
-- character made again replaces its own input rather than being filed under a
-- new name the workflow does not know. The reply's filename is checked against
-- the one asked for, because a workflow naming one file while the far end
-- filed another finds nothing and fails three steps later.
function M.upload(settings, path, name)
  local subfolder, filename = name:match("^(.*)/([^/]+)$")
  if not filename then subfolder, filename = "", name end
  local pipe = io.popen("curl --silent --show-error --max-time 30 " ..
                        "-F " .. quote("image=@" .. path .. ";filename=" .. filename) ..
                        " -F " .. quote("subfolder=" .. subfolder) ..
                        " -F overwrite=true " ..
                        quote(M.where(settings) .. "/upload/image") .. " 2>&1")
  local said = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  local filed = unescape(said:match('"name"%s*:%s*"([^"]+)"'))
  if filed ~= filename then
    return nil, "the picture program did not file " .. name .. " as asked:\n  " ..
                said:sub(1, 400):gsub("\n", "\n  ")
  end
  return name
end
-- }}}

-- {{{ M.wanted_by(graph_text)
-- What a workflow needs the far end to have: its box types and its models.
--
-- Read out of the workflow's own text, so the list cannot drift from what is
-- actually posted.
function M.wanted_by(graph_text)
  local boxes, models = {}, {}
  local seen = {}
  for kind in graph_text:gmatch('"class_type"%s*:%s*"([^"]+)"') do
    if not seen[kind] then seen[kind] = true; boxes[#boxes + 1] = kind end
  end
  -- Which folder each model is looked for in, by the name of the input that
  -- carries it.
  local FOLDERS = { ckpt_name = "checkpoints", control_net_name = "controlnet" }
  for input, folder in pairs(FOLDERS) do
    for file in graph_text:gmatch('"' .. input .. '"%s*:%s*"([^"]+)"') do
      models[#models + 1] = { folder = folder, file = unescape(file) }
    end
  end
  return boxes, models
end
-- }}}

-- {{{ M.inventory(settings, graph_text)
-- Everything a workflow needs that the far end does not have, all at once.
--
-- Asked before posting, of the program itself. A kitchen this project did not
-- install cannot be reasoned about -- what it holds is a fact about that
-- machine -- and the refusal it would give names only the first missing piece.
-- This names every one, so one look at the list says what to ask the owner
-- for. An empty list means everything is there.
function M.inventory(settings, graph_text)
  local boxes, models = M.wanted_by(graph_text)
  local missing = {}

  local pipe = io.popen("curl --silent --show-error --max-time 20 " ..
                        quote(M.where(settings) .. "/object_info") .. " 2>&1")
  local catalogue = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  if not catalogue:find('"LoadImage"', 1, true) then
    return { "the picture program would not list what it can do (/object_info)" }
  end
  for _, kind in ipairs(boxes) do
    if not catalogue:find('"' .. kind .. '": {', 1, true) then
      missing[#missing + 1] = "a box of type " .. kind
    end
  end

  local listed = {}
  for _, model in ipairs(models) do
    if not listed[model.folder] then
      local ask = io.popen("curl --silent --show-error --max-time 10 " ..
                           quote(M.where(settings) .. "/models/" .. model.folder) ..
                           " 2>&1")
      listed[model.folder] = ask and ask:read("*a") or ""
      if ask then ask:close() end
    end
    if not listed[model.folder]:find('"' .. model.file .. '"', 1, true) then
      missing[#missing + 1] = model.file .. " in models/" .. model.folder
    end
  end
  return missing
end
-- }}}

-- {{{ M.listening(settings)
-- Whether there is anything there, and what it says about itself.
--
-- Nothing listening is the normal state of this repository, so it is answered
-- plainly and with the command that starts one rather than by failing somewhere
-- obscure two steps later.
function M.listening(settings)
  local url = M.where(settings)
  local pipe = io.popen("curl --silent --show-error --max-time 4 " ..
                        quote(url .. "/system_stats") .. " 2>&1")
  local said = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end
  if said:find('"system"', 1, true) or said:find("comfyui_version", 1, true)
     or said:find('"devices"', 1, true) then
    -- The card's name, from inside the list of devices -- not the first "name"
    -- in the whole reply, which is a package the far end happens to mention
    -- first and is not a graphics card.
    local devices = said:match('"devices"%s*:%s*%[(.-)%]') or said
    local device = devices:match('"name"%s*:%s*"([^"]+)"')
    return true, device
  end
  return false, nil
end
-- }}}

-- {{{ explain_silence(settings)
local function explain_silence(settings)
  -- A kitchen in another house is started by whoever lives there. Telling the
  -- person here how to start the local one would be advice about the wrong
  -- machine.
  if settings.kitchen and settings.kitchen.here == false then
    return "there is nothing listening at " .. M.where(settings) .. ".\n" ..
           "  That picture program runs on another machine and is started by " ..
           "its owner."
  end
  local kitchen = project.path("libs", "kitchen")
  return "there is nothing listening at " .. M.where(settings) .. ".\n" ..
         "  start it with:\n" ..
         "    " .. kitchen .. "/venv/bin/python \\\n" ..
         "      " .. kitchen .. "/ComfyUI/main.py --listen 127.0.0.1 --port 8188 \\\n" ..
         "      --reserve-vram 1.5\n" ..
         "  that last part holds memory back for your desktop, and on a machine\n" ..
         "  whose only card is also drawing the screen it is what stops the\n" ..
         "  desktop freezing. See issues/409.\n" ..
         "  or install it first with:\n" ..
         "    bash src/043-install-the-kitchen.sh"
end
M.explain_silence = explain_silence
-- }}}

-- {{{ M.submit(settings, graph_text)
-- One workflow, posted. Returns the identifier the far end gave it.
function M.submit(settings, graph_text)
  local body = project.scratch("submit.json")
  project.write_file(body, '{"prompt":' .. graph_text .. '}')
  local pipe = io.popen("curl --silent --show-error --max-time 30 " ..
                        "-X POST -H " .. quote("Content-Type: application/json") ..
                        " --data-binary @" .. quote(body) .. " " ..
                        quote(M.where(settings) .. "/prompt") .. " 2>&1")
  local said = pipe and pipe:read("*a") or ""
  if pipe then pipe:close() end

  local identifier = said:match('"prompt_id"%s*:%s*"([^"]+)"')
  if identifier then return identifier end

  -- An error from the far end is the answer to a question nothing on this side
  -- could ask -- whether the model names are right, whether the node types
  -- exist in that installation -- so it is reported whole rather than
  -- summarised into something tidier and less useful.
  return nil, "the picture program refused this workflow:\n  " ..
              said:gsub("\n", "\n  ")
end
-- }}}

-- {{{ M.wait_for(settings, identifier, patience)
-- Poll until the picture is made, or give up.
--
-- Returns the filename and subfolder it was saved under.
function M.wait_for(settings, identifier, patience)
  local waited = 0
  patience = patience or 300
  while waited < patience do
    local pipe = io.popen("curl --silent --show-error --max-time 10 " ..
                          quote(M.where(settings) .. "/history/" .. identifier) ..
                          " 2>&1")
    local said = pipe and pipe:read("*a") or ""
    if pipe then pipe:close() end

    if said:find('"status"', 1, true) then
      local filename = unescape(said:match('"filename"%s*:%s*"([^"]+)"'))
      local subfolder = unescape(said:match('"subfolder"%s*:%s*"([^"]*)"'))
      if filename then return filename, subfolder or "" end
      -- The far end records a failure in the same place it records a success,
      -- so a run that ended badly is found here rather than by waiting out the
      -- whole patience.
      if said:find('"status_str"%s*:%s*"error"', 1, true) then
        return nil, "the picture program reported an error:\n  " ..
                    said:sub(1, 900):gsub("\n", "\n  ")
      end
    end

    heat.rest(1.0)
    waited = waited + 1
  end
  return nil, "the picture program did not finish within " .. patience ..
              " seconds. It may still be working; nothing was lost."
end
-- }}}

-- {{{ M.collect(settings, filename, subfolder)
-- The finished picture, fetched.
function M.collect(settings, filename, subfolder)
  local target = project.scratch("collected.png")
  local url = M.where(settings) .. "/view?filename=" ..
              filename:gsub("[^%w%.%-_]", function(character)
                return string.format("%%%02X", character:byte())
              end) ..
              "&subfolder=" .. (subfolder or "") .. "&type=output"
  local ok = os.execute("curl --silent --show-error --fail --max-time 60 " ..
                        "--output " .. quote(target) .. " " .. quote(url))
  if not (ok == true or ok == 0) then
    return nil, "could not fetch the finished picture from " .. url
  end
  return target
end
-- }}}

-- {{{ M.make_one(settings, record, store, options)
-- One character, all the way from a recipe to a rated picture in the pool.
function M.make_one(settings, record, store, options)
  options = options or {}

  -- The recipe is written by `030` and *only* by `030`, and whatever it decided
  -- is what gets posted.
  --
  -- WHY THIS IS SAID SO FIRMLY. This used to work out the prompt here as well,
  -- and then post the workflow `030` had written -- so the style asked for on
  -- the command line went into the pool as the picture's description while the
  -- picture itself was made from a different prompt entirely, with a different
  -- seed. Asking for a style appeared to do nothing, and the pool recorded a
  -- brief the picture had never answered.
  local recipe_dir = options.recipes or project.scratch("recipes")
  local made, made_why = one.make(record, store, settings,
                                  { out = recipe_dir, style = options.style })
  if not made then return nil, made_why end
  local built = made.prompt
  local scene = built.scene

  for _, input in ipairs(made.inputs) do
    local filed, upload_why = M.upload(settings, input.path, input.name)
    if not filed then return nil, upload_why end
  end

  -- Every route this kitchen runs, one picture each, into the pool side by
  -- side. A route that fails does not stop the others: the two are answers to
  -- the same question and one is worth having without the other.
  local results, failures = {}, {}
  for _, recipe in ipairs(made.workflows) do
    local done, why = M.draw_one_route(settings, record, made, recipe, options)
    if done then results[#results + 1] = done
    else failures[#failures + 1] = recipe.route .. ": " .. tostring(why) end
  end
  if #results == 0 then return nil, table.concat(failures, "\n  ") end
  return { character = record.character, world = scene.biome.name,
           routes = results, failures = failures }
end
-- }}}

-- {{{ M.checked -- which routes' recipes have been checked against the kitchen
-- Asked once per route per run, not once per picture: what a kitchen holds
-- does not change between one character and the next, and /object_info is a
-- large reply.
M.checked = {}
-- }}}

-- {{{ M.draw_one_route(settings, record, made, recipe, options)
-- One route's recipe, posted, drawn, collected, filed and -- where it means
-- anything -- graded.
function M.draw_one_route(settings, record, made, recipe, options)
  local built = made.prompt
  local scene = built.scene
  local graph_text = project.read_file(recipe.path)

  if not M.checked[recipe.route] then
    local missing = M.inventory(settings, graph_text)
    if #missing > 0 then
      return nil, "the picture program at " .. M.where(settings) ..
                  " does not have:\n    " .. table.concat(missing, "\n    ") ..
                  "\n  Nothing was installed or fetched; ask its owner."
    end
    M.checked[recipe.route] = true
  end

  local identifier, submit_why = M.submit(settings, graph_text)
  if not identifier then return nil, submit_why end

  local filename, subfolder = M.wait_for(settings, identifier,
                                         options.patience)
  if not filename then return nil, subfolder end

  local picture, collect_why = M.collect(settings, filename, subfolder)
  if not picture then return nil, collect_why end

  -- What makes this picture different from another of the same character:
  -- the route that drew it and the kitchen it was drawn in. Both go into its
  -- name, so neither replaces the other in a pool that never deletes (`405`).
  local variant = { route = recipe.route,
                    drawn_by = settings.kitchen and settings.kitchen.drawn_by }
  local canvas_text = (recipe.route == "inside")
    and ("inside the strokes: " .. built.parts.subjects ..
         " / outside: " .. built.parts.background)
    or (recipe.route == "outside") and built.parts.outside
    or built.positive

  local seed = made.seed
  local _, companion = pool.add(settings, {
    record = record, scene = scene, seed = seed,
    character = record.character,
    means = table.concat(record.meanings, ", "),
    what = "A picture drawn from this project's recipe for " ..
           record.character .. ".",
    kind = (record.cells and #record.cells > 1) and "phrase" or "character",
    category = scene.biome.name, codepoint = record.codepoint,
    paintbrush = scene.paintbrush_version, reading = scene.reading,
    -- A pool holding two styles with no way to tell them apart is a pool where
    -- every comparison between them is meaningless.
    style = built.style,
    route = recipe.route,
    drawn_by = variant.drawn_by,
    checkpoint = settings.workflow.checkpoint,
    resolution = settings.field.resolution,
    argued = scene.argument_path, canvas = canvas_text,
    source = filename,
    ratings = {},
  }, project.read_file(picture))

  -- THE OUTSIDE ROUTE IS NEVER GRADED BY THE MACHINE. Its picture has the
  -- character painted into it, so it matches the field nearly perfectly by
  -- construction, and the score would say nothing except that -- while sitting
  -- at the top of every ranking the quality dial learns from (`docs/007`, Q13).
  -- A person rates it, or nobody does.
  if not grader.grades(recipe.route) then
    return { route = recipe.route, companion = companion, graded = false }
  end

  -- Rated the moment it exists, so that a floor works from the first day. If
  -- only what somebody looked at were rated, the pool would be overwhelmingly
  -- unrated and "tier four or better" would exclude nearly all of it.
  local tier, agreement = grader.rate_on_arrival(settings, companion,
    pool.place(settings, record, scene, seed, built.style,
               settings.field.resolution, variant),
    made.folder .. "/field.png")

  return { route = recipe.route, tier = tier, agreement = agreement,
           companion = companion, graded = true }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("044-run-the-pictures")
  -- Another kitchen first, because it may change the resolution, and a
  -- resolution asked for on the command line should win over both.
  settings = M.for_kitchen(settings,
                           type(options.kitchen) == "string" and options.kitchen
                           or nil)
  if settings.kitchen_name then
    io.write("cooking in '", settings.kitchen_name, "' at ", M.where(settings),
             " with ", settings.workflow.checkpoint, "; routes: ",
             table.concat(settings.workflow.routes or { "illusion" }, ", "), "\n")
  end
  local store = records.store()

  -- A resolution asked for on the command line replaces the one in the
  -- settings, and every length that was written at the reference resolution is
  -- scaled to match it (`413`). Copied rather than written into the shared
  -- settings table, because half this project reads that table.
  local wanted_resolution = tonumber(options.resolution)
  if wanted_resolution then
    local field = {}
    for key, value in pairs(settings.field) do field[key] = value end
    field.resolution = wanted_resolution
    local copy = {}
    for key, value in pairs(settings) do copy[key] = value end
    copy.field = field
    settings = copy
    io.write(string.format("drawing at %d instead of %d; every length scales " ..
             "with it\n", wanted_resolution, field.reference))
    -- The model these recipes are written for was trained at 512 and is already
    -- being pushed at 768. Well past that it repeats its subject -- two trees,
    -- two figures -- because it has never seen a picture that size. Worth
    -- trying and worth being told.
    if wanted_resolution > 1024 then
      io.write("NOTE: this is well past what the model was trained at. Expect " ..
               "it to repeat\n      its subject -- two trees where there " ..
               "should be one -- and take about\n      four times as long " ..
               "per picture.\n")
    end
  end

  local listening, device = M.listening(settings)
  if not listening then
    io.write(explain_silence(settings), "\n")
    os.exit(1)
  end
  io.write("the picture program is there", device and (", drawing on " .. device)
           or "", "\n")

  -- Said before the first picture rather than in a document nobody opened. A
  -- person who does not want their machine used this way needs to know before
  -- it is.
  local card = M.card(settings)
  local shared = M.is_the_display_card(card, settings)
  if settings.kitchen.shares_a_screen ~= nil then
    io.write("whether that card draws a screen cannot be asked from here; " ..
             "the settings say to treat it as ",
             shared and "if it does" or "if it does not", "\n")
  end
  local rest = (settings.kitchen and settings.kitchen.rest) or 1.0
  if card then
    io.write(string.format("the card has %.1f GB, %.1f free\n",
             card.total, card.free))
    if shared then
      rest = (settings.kitchen and settings.kitchen.rest_on_the_display_card)
             or rest
      io.write(string.format(
        "it is also drawing your screen, so this will rest %.0f seconds between\n" ..
        "pictures instead of %.0f and stop rather than take the last %.1f GB.\n",
        rest, (settings.kitchen and settings.kitchen.rest) or 1.0,
        (settings.kitchen and settings.kitchen.least_free_vram) or 0))
      if not (settings.kitchen and settings.kitchen.reserve_vram) then
        io.write("NOTE: nothing is reserved for the desktop. Start the picture\n" ..
                 "      program with --reserve-vram to hold some back.\n")
      end
    end
  end

  local chosen = phrases.select(store, options) or records.select(store, options)
  if not chosen then
    io.write("say which characters. --chars, --grade, --jlpt, --frequent, " ..
             "--all, --phrase, --phrases\n")
    os.exit(1)
  end

  local limit = tonumber(options.limit)
  if limit and #chosen > limit then
    local trimmed = {}
    for index = 1, limit do trimmed[index] = chosen[index] end
    io.write(string.format("%d selected; taking the first %d\n", #chosen, limit))
    chosen = trimmed
  end

  -- One at a time, and how long between them depends on whether this card is
  -- also the screen (`409`).
  local made, failed = 0, {}
  local started = os.time()

  for index, record in ipairs(chosen) do
    -- Room checked before submitting, not discovered by submitting. Waiting is
    -- tried first, because the picture program frees what it held between runs
    -- and a moment is usually all it needs.
    local room, seen = M.room_to_work(settings)
    local waited = 0
    while not room and waited < 60 do
      heat.rest(5)
      waited = waited + 5
      room, seen = M.room_to_work(settings)
    end
    if not room then
      io.write(string.format(
        "\nstopping: the card has only %.1f GB free and this run will not take\n" ..
        "the last %.1f GB, because it is drawing your screen. %d made so far.\n",
        seen.free, (settings.kitchen and settings.kitchen.least_free_vram) or 0,
        made))
      break
    end

    io.write(string.format("  [%d/%d] %s ... ", index, #chosen, record.character))
    io.flush()
    local done, why = M.make_one(settings, record, store, {
      recipes = options.recipes, patience = options.patience,
      style = type(options.style) == "string" and options.style or nil,
    })
    if done then
      made = made + #done.routes
      local said = {}
      for _, one in ipairs(done.routes) do
        said[#said + 1] = one.graded
          and string.format("%s tier %d (%.2f)", one.route, one.tier or 0,
                            one.agreement or 0)
          or (one.route .. " for a person to rate")
      end
      io.write(done.world, ": ", table.concat(said, ", "), "\n")
      for _, note in ipairs(done.failures) do
        failed[#failed + 1] = record.character .. " " .. note
      end
    else
      failed[#failed + 1] = record.character .. ": " .. tostring(why)
      io.write("could not\n")
    end
    if index < #chosen then heat.rest(rest) end
  end

  io.write(string.format("\n%d made, %d could not be, in %d seconds\n",
           made, #failed, os.difftime(os.time(), started)))
  for _, note in ipairs(failed) do io.write("  ", note, "\n") end
  if made > 0 then
    io.write("\n  luajit src/032-a-gallery-you-can-page.lua --pool\n")
  end
  project.goodbye("044-run-the-pictures", { made .. " pictures made" })
end
-- }}}

if arg and arg[0] and arg[0]:find("044%-run%-the%-pictures") then
  main(arg)
end

return M
