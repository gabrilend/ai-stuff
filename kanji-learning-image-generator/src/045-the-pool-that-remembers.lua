-- 045-the-pool-that-remembers.lua
--
-- Every picture this project has ever made, kept, with everything true about it
-- in a file beside it.
--
-- For a general: there is no database here and no index. A picture and its
-- description are two files with the same name in the same folder, and that is
-- the whole store. The convention already exists for source -- every source
-- file has a companion page you read instead of opening the code -- and this is
-- the same idea pointed at what the project produces.
--
--     pool/shrine/06642-時-20f3a9.png
--     pool/shrine/06642-時-20f3a9.info.md
--
-- Three things follow from it and each is the reason for it.
--
--   Asking "which of the forest ones are good" reads small text files. It never
--   opens a picture.
--
--   Nothing can be separated from its meaning. Copy the pair anywhere and the
--   tier, the seed and the origin come with it. A record in a central store
--   drifts from what it describes the first time somebody archives one without
--   the other.
--
--   Ratings are appended and never overwritten, so a machine's guess stays
--   visible underneath the correction a person later made -- which is the only
--   reason the agreement between them can be measured at all.
--
-- NOTHING IS EVER DELETED. Not the bad ones. A low tier records what missed and
-- by how much; re-rating later can promote something scored in a hurry; and a
-- pool that has been pruned cannot answer why the output drifted. Storage is
-- cheap and judgement is expensive, and this trades the cheap thing away
-- deliberately.
--
--   luajit src/045-the-pool-that-remembers.lua --counts
--   luajit src/045-the-pool-that-remembers.lua --list --category forest --floor 4

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ TIERS -- one scale, five steps, used by everyone and everything
--
-- A person and a machine write the same field using the same steps. That is
-- what makes the two comparable, and comparing them is the only check there is
-- on whether the machine's taste is anything like a person's.
M.TIERS = {
  [5] = "love it. reach for this first",
  [4] = "good. use freely",
  [3] = "okay. fine among others, not on its own",
  [2] = "weak. kept, not reached for",
  [1] = "no. kept as the record of what missed",
}
-- }}}

-- {{{ M.root(settings)
function M.root(settings)
  local where = (settings.pool and settings.pool.dir) or "tmp/shared-memory/pool"
  if where:sub(1, 1) == "/" then return where end
  return project.path(where)
end
-- }}}

-- {{{ M.stem(record, scene, seed)
-- What one rendering is called, without an extension.
--
-- The number first so a folder sorts in a stable order, the character next so a
-- person can read the listing, and the seed last because the same character can
-- be rendered more than once and those are different pictures.
function M.stem(record, seed)
  return string.format("%08X-%s-%06x", record.codepoint, record.character,
                       seed % 0x1000000)
end
-- }}}

-- {{{ M.place(settings, record, scene, seed)
-- The two paths one rendering occupies.
--
-- Arranged by category, because quality is never discussed globally -- it is
-- always *these* that are looking bad, and the unit somebody says that about
-- here is the world.
function M.place(settings, record, scene, seed)
  local folder = M.root(settings) .. "/" .. scene.biome.name
  local stem = M.stem(record, seed)
  return folder .. "/" .. stem .. ".png",
         folder .. "/" .. stem .. ".info.md",
         folder
end
-- }}}

-- {{{ M.render_companion(entry)
-- Everything true about one rendering, as the text of its companion.
--
-- Markdown, because it has to be readable by a person and greppable by a
-- program, and this project already reads and writes that shape everywhere.
function M.render_companion(entry)
  local out = {}
  local function say(line) out[#out + 1] = line or "" end

  -- The default is settled here, once, and then written into the table like
  -- everything else -- rather than being supplied at the moment of printing,
  -- which would put a line in the file that reading it back cannot find.
  local what = entry.what or "A rendering."

  say("# " .. entry.character .. " — " .. (entry.means or ""))
  say()
  say(what)
  say()
  say("| | |")
  say("|---|---|")
  local function field(name, value)
    if value ~= nil and value ~= "" then
      say("| " .. name .. " | " .. tostring(value) .. " |")
    end
  end
  -- In the table as well as in the heading and the opening line above.
  --
  -- WHY BOTH. A companion is rewritten every time somebody rates it, from
  -- whatever reading it back produced -- and reading it back only ever looked
  -- at this table. So the heading and the opening line, which were written once
  -- and never parsed, were erased by the first rating. The file looked fine
  -- and had quietly lost what it was of.
  --
  -- Anything that has to survive a rating lives in the table. The heading is
  -- made from it, not the other way round.
  field("means", entry.means)
  field("what", what)
  field("kind", entry.kind)
  field("category", entry.category)
  field("character", entry.character)
  field("codepoint", entry.codepoint)
  field("seed", entry.seed)
  field("paintbrush", entry.paintbrush)
  field("reading", entry.reading)
  field("argued", entry.argued)
  field("recipe", entry.recipe)
  field("source", entry.source)
  field("made", entry.made)
  say()

  -- The brief this answered, kept beside the result. Without it a low tier
  -- reads as bad work when it may have been an impossible request.
  say("## The canvas it answered")
  say()
  say(entry.canvas or "")
  say()

  say("## Ratings")
  say()
  say("Newest last. Never rewritten — a tier is added, and the last one wins.")
  say()
  for _, rating in ipairs(entry.ratings or {}) do
    say(string.format("- %d · %s · %s", rating.tier, rating.who, rating.when))
  end
  say()

  say("## Elaborations")
  say()
  if #(entry.elaborations or {}) == 0 then
    say("None yet.")
  else
    for _, one in ipairs(entry.elaborations) do
      say(string.format("- %s · %s · %s", one.file, one.what, one.when))
    end
  end
  say()

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.read_companion(path)
-- One companion, back as a table.
--
-- By pattern over a file this project wrote itself, in a shape chosen to be
-- read this way. There is no parser here because there is no format here --
-- there is a table with two columns and a list of lines beginning with a dash.
function M.read_companion(path)
  local text = project.read_file(path)
  if not text then return nil end

  local entry = { ratings = {}, elaborations = {}, path = path }
  for name, value in text:gmatch("\n| ([%w_]+) | ([^|\n]-) |") do
    entry[name] = value
  end
  entry.codepoint = tonumber(entry.codepoint)
  entry.seed = tonumber(entry.seed)

  -- Line by line, rather than one pattern swept over the whole section.
  --
  -- WHY. A pattern that anchors on the newline before each entry consumes that
  -- newline when it matches -- so the next entry has no newline left to anchor
  -- on and is never seen. Every companion read back with only its *first*
  -- rating, and the rating that counts is the last one. Every correction a
  -- person had made was invisible, silently, while the file itself was
  -- perfectly correct.
  local ratings = text:match("## Ratings\n(.-)\n## ") or ""
  for line in ratings:gmatch("[^\n]+") do
    local tier, who, when = line:match("^%- (%d) · (.-) · (.+)$")
    if tier then
      entry.ratings[#entry.ratings + 1] =
        { tier = tonumber(tier), who = who, when = when }
    end
  end

  local elaborations = text:match("## Elaborations\n(.*)$") or ""
  for line in elaborations:gmatch("[^\n]+") do
    local file, what, when = line:match("^%- (.-) · (.-) · (.+)$")
    if file then
      entry.elaborations[#entry.elaborations + 1] =
        { file = file, what = what, when = when }
    end
  end

  entry.canvas = text:match("## The canvas it answered\n\n(.-)\n\n## ")
  entry.picture = path:gsub("%.info%.md$", ".png")
  -- A companion whose picture is not beside it is not broken. It is a judgement
  -- waiting for its picture to be made again -- which is the ordinary state of
  -- a fresh clone, because the opinions are in the record and the pictures are
  -- not (410). The seed and the description are right here, so the picture is a
  -- command away.
  entry.picture_is_here = project.exists(entry.picture)
  return entry
end
-- }}}

-- {{{ M.tier_of(entry)
-- The tier that counts, and who set it.
--
-- The last rating wins, which is how a person's correction overrides a
-- machine's guess without either being erased.
function M.tier_of(entry)
  local last = entry.ratings[#entry.ratings]
  if not last then return nil, nil end
  return last.tier, last.who
end
-- }}}

-- {{{ M.tier_by_a_person(entry)
-- The last tier a person set, if a person ever set one.
--
-- Separate from the tier that counts, because "tier 4 or better" and "tier 4 or
-- better as judged by a person" are different requests and the second is
-- smaller and more trustworthy. Confidence and quality are not the same axis.
function M.tier_by_a_person(entry)
  for index = #entry.ratings, 1, -1 do
    local rating = entry.ratings[index]
    if not rating.who:find("machine", 1, true) then
      return rating.tier
    end
  end
  return nil
end
-- }}}

-- {{{ M.add(settings, entry, picture_bytes)
-- One rendering, into the pool.
--
-- The picture is written first and the companion second, so that a run
-- interrupted between them leaves a picture with no description rather than a
-- description of a picture that is not there. The first is visible and
-- recoverable; the second is a lie.
function M.add(settings, entry, picture_bytes)
  local picture_path, companion_path, folder =
    M.place(settings, entry.record, entry.scene, entry.seed)
  project.ensure_directory(folder)

  local handle = assert(io.open(picture_path .. ".partial", "wb"))
  handle:write(picture_bytes)
  handle:close()
  os.rename(picture_path .. ".partial", picture_path)

  entry.made = entry.made or os.date("%Y-%m-%d %H:%M:%S")
  project.write_file(companion_path, M.render_companion(entry))
  return picture_path, companion_path
end
-- }}}

-- {{{ M.rate(companion_path, tier, who)
-- One more rating, appended.
--
-- The whole companion is rewritten because that is how a text file gains a
-- line, and no rating that was already in it is touched. The history is the
-- point: a machine's guess has to stay visible under a person's correction, or
-- the agreement between them cannot be measured.
function M.rate(companion_path, tier, who)
  if type(tier) ~= "number" or tier < 1 or tier > 5 or tier % 1 ~= 0 then
    error("a tier is a whole number from 1 to 5, not " .. tostring(tier) ..
          "\n  " .. table.concat({
            "5 " .. M.TIERS[5], "4 " .. M.TIERS[4], "3 " .. M.TIERS[3],
            "2 " .. M.TIERS[2], "1 " .. M.TIERS[1] }, "\n  "))
  end
  local entry = M.read_companion(companion_path)
  if not entry then
    error("there is nothing to rate at " .. companion_path)
  end
  entry.ratings[#entry.ratings + 1] = {
    tier = tier, who = who or "person",
    when = os.date("%Y-%m-%d %H:%M:%S"),
  }
  project.write_file(companion_path, M.render_companion(entry))
  return entry
end
-- }}}

-- {{{ M.elaborate(companion_path, file, what)
-- A note that a rendering earned some extra work, and got it.
function M.elaborate(companion_path, file, what)
  local entry = M.read_companion(companion_path)
  if not entry then error("there is nothing at " .. companion_path) end
  entry.elaborations[#entry.elaborations + 1] = {
    file = file, what = what, when = os.date("%Y-%m-%d %H:%M:%S"),
  }
  project.write_file(companion_path, M.render_companion(entry))
  return entry
end
-- }}}

-- {{{ M.walk(settings, filter)
-- Every rendering that matches, as entries.
--
-- The whole query layer. It reads companions and never opens a picture, which
-- keeps filtering cheap and, more importantly, keeps it simple: the thing that
-- answers "what is available" is text processing rather than a media pipeline.
--
-- filter.category    only this world
-- filter.kind        "character" or "phrase"
-- filter.floor       this tier or better
-- filter.by_a_person the floor must have been set by a person
-- filter.character   only this character
function M.walk(settings, filter)
  filter = filter or {}
  local root = M.root(settings)
  local found = {}

  local listing = io.popen('find "' .. root .. '" -name "*.info.md" 2>/dev/null')
  if not listing then return found end
  local paths = {}
  for line in listing:lines() do paths[#paths + 1] = line end
  listing:close()
  -- sorted, so two runs over the same pool see it in the same order and a
  -- report can be compared with the one before it
  table.sort(paths)

  for _, path in ipairs(paths) do
    local entry = M.read_companion(path)
    if entry then
      local keep = true
      if filter.category and entry.category ~= filter.category then keep = false end
      if filter.kind and entry.kind ~= filter.kind then keep = false end
      if filter.character and entry.character ~= filter.character then keep = false end
      if filter.floor then
        -- Written out rather than as `a and b or c`, which is the usual way to
        -- say this in Lua and is wrong exactly when b is nil: asking for a
        -- person's judgement on something no person had judged fell through to
        -- the machine's, so "tier 4 or better as judged by a person" quietly
        -- became "tier 4 or better as judged by anyone" -- which is the one
        -- distinction this filter exists to preserve.
        local tier
        if filter.by_a_person then
          tier = M.tier_by_a_person(entry)
        else
          tier = M.tier_of(entry)
        end
        if not tier or tier < filter.floor then keep = false end
      end
      if keep then found[#found + 1] = entry end
    end
  end
  return found
end
-- }}}

-- {{{ M.counts(settings)
-- How many of what, and how often the machine agrees with a person.
--
-- A utility rather than a number written into a document. A number typed into
-- documentation was true once; this is true when asked.
function M.counts(settings)
  local all = M.walk(settings, {})
  local report = {
    total = #all, by_category = {}, by_tier = {}, by_kind = {},
    rated_by_a_person = 0, rated_by_a_machine = 0, unrated = 0,
    agreed = 0, compared = 0, elaborations = 0, owed = 0,
    awaiting_their_picture = {},
  }

  for _, entry in ipairs(all) do
    if not entry.picture_is_here then
      report.awaiting_their_picture[#report.awaiting_their_picture + 1] =
        entry.character
    end
    report.by_category[entry.category] = (report.by_category[entry.category] or 0) + 1
    report.by_kind[entry.kind or "?"] = (report.by_kind[entry.kind or "?"] or 0) + 1
    local tier = M.tier_of(entry)
    if tier then
      report.by_tier[tier] = (report.by_tier[tier] or 0) + 1
    else
      report.unrated = report.unrated + 1
    end

    local by_person = M.tier_by_a_person(entry)
    local by_machine = nil
    for _, rating in ipairs(entry.ratings) do
      if rating.who:find("machine", 1, true) then by_machine = rating.tier end
    end
    if by_person then report.rated_by_a_person = report.rated_by_a_person + 1 end
    if by_machine then report.rated_by_a_machine = report.rated_by_a_machine + 1 end

    -- Wherever both exist for one rendering, that is a free measurement of how
    -- often the machine agrees -- continuously, out of ordinary use, with no
    -- evaluation exercise ever being run.
    if by_person and by_machine then
      report.compared = report.compared + 1
      if by_person == by_machine then report.agreed = report.agreed + 1 end
    end

    report.elaborations = report.elaborations + #entry.elaborations
    -- Promotion creates work: a rendering somebody moved up now deserves
    -- elaboration it does not have.
    if tier and tier >= 4 and #entry.elaborations == 0 then
      report.owed = report.owed + 1
    end
  end
  return report
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("045-the-pool-that-remembers")

  if options.list then
    local found = M.walk(settings, {
      category = type(options.category) == "string" and options.category or nil,
      kind = type(options.kind) == "string" and options.kind or nil,
      floor = tonumber(options.floor),
      by_a_person = options.by_a_person and true or nil,
    })
    io.write(string.format("%d renderings\n", #found))
    for _, entry in ipairs(found) do
      local tier, who = M.tier_of(entry)
      io.write(string.format("  %s  %-9s %-9s %s  %s\n",
        entry.character, entry.category or "?", entry.kind or "?",
        tier and ("tier " .. tier .. " by " .. who) or "unrated",
        entry.path:gsub(".*/", "")))
    end
    project.goodbye("045-the-pool-that-remembers", { #found .. " renderings" })
    return
  end

  local report = M.counts(settings)
  io.write(string.format("%d renderings in %s\n\n", report.total,
                         M.root(settings)))
  if report.total == 0 then
    io.write("nothing has been made yet. The pool fills up when pictures are\n")
    io.write("generated -- see src/044-run-the-pictures.lua.\n")
    project.goodbye("045-the-pool-that-remembers", { "the pool is empty" })
    return
  end

  io.write("by tier:\n")
  for tier = 5, 1, -1 do
    io.write(string.format("  %d  %5d   %s\n", tier, report.by_tier[tier] or 0,
                           M.TIERS[tier]))
  end
  io.write(string.format("  -  %5d   never rated\n", report.unrated))

  io.write("\nby world:\n")
  local worlds = {}
  for name, count in pairs(report.by_category) do
    worlds[#worlds + 1] = { name = name, count = count }
  end
  table.sort(worlds, function(a, b) return a.count > b.count end)
  for _, row in ipairs(worlds) do
    io.write(string.format("  %-10s %5d\n", row.name, row.count))
  end

  io.write(string.format("\n%d rated by a person, %d by a machine\n",
           report.rated_by_a_person, report.rated_by_a_machine))
  if report.compared > 0 then
    io.write(string.format("they have both rated %d, and agreed on %d of them (%.0f%%)\n",
             report.compared, report.agreed,
             report.agreed / report.compared * 100))
  else
    io.write("nothing has been rated by both, so there is no way yet to tell\n" ..
             "whether the machine's taste is anything like a person's.\n")
  end
  io.write(string.format("\n%d elaborations made, %d owed\n",
           report.elaborations, report.owed))

  -- Said plainly, because a pool with judgements and no pictures is the
  -- ordinary state of a fresh clone and looks alarming if nothing explains it.
  if #report.awaiting_their_picture > 0 then
    io.write(string.format("\n%d have a rating and no picture beside them. " ..
             "That is a clone, or a\nmachine that was restarted -- the opinions " ..
             "are in the record and the pictures\nare not. Make them again:\n",
             #report.awaiting_their_picture))
    local wanted = {}
    local seen = {}
    for _, character in ipairs(report.awaiting_their_picture) do
      if not seen[character] then
        seen[character] = true
        wanted[#wanted + 1] = character
      end
    end
    io.write("  luajit src/044-run-the-pictures.lua --chars ",
             table.concat(wanted, "", 1, math.min(24, #wanted)), "\n")
  end

  project.goodbye("045-the-pool-that-remembers",
                  { report.total .. " renderings" })
end
-- }}}

if arg and arg[0] and arg[0]:find("045%-the%-pool%-that%-remembers") then
  main(arg)
end

return M
