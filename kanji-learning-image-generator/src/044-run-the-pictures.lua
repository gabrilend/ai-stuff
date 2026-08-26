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

-- {{{ M.card()
-- What the graphics card says about itself, or nil if it will not say.
--
-- Total memory, how much is in use, and how much is free -- in gigabytes.
function M.card()
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

-- {{{ M.is_the_display_card(card)
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
function M.is_the_display_card(card)
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
  local card = M.card()
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

-- {{{ M.input_folder(settings)
-- The folder that program reads its inputs from.
--
-- It names its inputs by filename and looks in its own folder -- it does not
-- take a path. So the workflow carries a name and the pictures have to be put
-- where it will look. Getting this backwards produces a workflow that is
-- correct and cannot find its own pictures, which `302` already warns about.
function M.input_folder(settings)
  local kitchen = settings.kitchen or {}
  if kitchen.input then return kitchen.input end
  return project.path("libs", "kitchen", "ComfyUI", "input")
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

-- {{{ M.explain_silence(settings)
local function explain_silence(settings)
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
  local built, why = words.prompts(record, store, settings)
  if not built then return nil, why end
  local scene = built.scene

  -- The recipe is written out first, exactly as `030` would, because the
  -- pictures it names have to exist somewhere before they can be copied to
  -- where the far end looks.
  local recipe_dir = options.recipes or project.scratch("recipes")
  local made, made_why = one.make(record, store, settings, { out = recipe_dir })
  if not made then return nil, made_why end

  local field_name = string.format("%05X-field.png", record.codepoint)
  local arrows_name = string.format("%05X-arrows.png", record.codepoint)
  local into = M.input_folder(settings) .. "/kanji"
  project.ensure_directory(into)
  os.execute("cp " .. quote(made.folder .. "/field.png") .. " " ..
             quote(into .. "/" .. field_name))
  os.execute("cp " .. quote(made.folder .. "/arrows.png") .. " " ..
             quote(into .. "/" .. arrows_name))

  local graph_text = project.read_file(made.folder .. "/workflow.api.json")
  local identifier, submit_why = M.submit(settings, graph_text)
  if not identifier then return nil, submit_why end

  local filename, subfolder = M.wait_for(settings, identifier,
                                         options.patience)
  if not filename then return nil, subfolder end

  local picture, collect_why = M.collect(settings, filename, subfolder)
  if not picture then return nil, collect_why end

  local seed = workflow.seed_for(record)
  local _, companion = pool.add(settings, {
    record = record, scene = scene, seed = seed,
    character = record.character,
    means = table.concat(record.meanings, ", "),
    what = "A picture drawn from this project's recipe for " ..
           record.character .. ".",
    kind = (record.cells and #record.cells > 1) and "phrase" or "character",
    category = scene.biome.name, codepoint = record.codepoint,
    paintbrush = scene.paintbrush_version, reading = scene.reading,
    argued = scene.argument_path, canvas = built.positive,
    source = filename,
    ratings = {},
  }, project.read_file(picture))

  -- Rated the moment it exists, so that a floor works from the first day. If
  -- only what somebody looked at were rated, the pool would be overwhelmingly
  -- unrated and "tier four or better" would exclude nearly all of it.
  local tier, agreement = grader.rate_on_arrival(settings, companion,
    pool.place(settings, record, scene, seed),
    made.folder .. "/field.png")

  return { character = record.character, world = scene.biome.name,
           tier = tier, agreement = agreement, companion = companion }
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("044-run-the-pictures")
  local store = records.store()

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
  local card = M.card()
  local shared = M.is_the_display_card(card)
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
    local done, why = M.make_one(settings, record, store, options)
    if done then
      made = made + 1
      io.write(string.format("%s, tier %d (%.2f)\n", done.world, done.tier or 0,
               done.agreement or 0))
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
