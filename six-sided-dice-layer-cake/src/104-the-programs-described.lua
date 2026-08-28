-- 104-the-programs-described.lua
--
-- Writes a companion page beside every program, the way 096 does beside every
-- blueprint.
--
-- For a general reader: this project's rule is that any file worth reading has
-- a short page beside it saying what it offers, so that somebody can find out
-- what a file does without opening it. The eighty-four blueprints all have one,
-- generated from the declarations inside them. The dozen programs did not,
-- because a program has no declarations -- Lua does not make a module state what
-- it exports, and finding out normally means either running the file or parsing
-- the language, and neither is wanted for a documentation tool.
--
-- What makes it possible anyway is a habit this project adopted for an unrelated
-- reason. Every function here is wrapped in a fold that opens with a comment
-- carrying the function's name, followed by prose about it, followed by the
-- definition with its arguments:
--
--     -- {{{ function M.load()
--     -- Load every blueprint under src/, resolve every symbol in dependency
--     -- order, and report what would not resolve.
--     function M.load(dir)
--
-- That is a name, a description and a signature, in a fixed shape, on three
-- consecutive lines. The convention was adopted so that a long file collapses
-- neatly in an editor, and it turns out to be a machine-readable statement of
-- what a module offers. This reads it.
--
-- Because the whole method rests on the convention holding, this is also where
-- the convention is enforced: a public function outside a fold is reported
-- rather than skipped, and so is a fold whose name disagrees with the definition
-- under it.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local M = {}

-- ---------------------------------------------------------------------------
-- Reading a program
-- ---------------------------------------------------------------------------

-- {{{ local function read_lines()
-- A file as a list of lines, or nothing if it will not open. Everything here
-- works line by line rather than on one string, because every shape it looks
-- for is anchored to the start of a line and a line number is what a report has
-- to give back.
local function read_lines(path)
  local fh = io.open(path, "r")
  if not fh then return nil end
  local lines = {}
  for line in fh:lines() do lines[#lines + 1] = line end
  fh:close()
  return lines
end
-- }}}

-- {{{ local function signature()
-- Pull a name and argument list out of a definition line. Five shapes appear in
-- this project and no others, which is worth relying on rather than writing a
-- parser for a language that has many more.
--
--   function M.name(a, b)        public, defined in place
--   local function name(a, b)    private
--   BLOCK.name = function(a, b)  an entry in a dispatch table
--   local name = function(a, b)  private, the same thing spelled differently
--   M.name = something           an export; what it points at is resolved later
local function signature(line)
  local name, args = line:match("^function%s+(M%.[%w_]+)%s*%(([^)]*)%)")
  if name then return name, args, true end
  name, args = line:match("^local%s+function%s+([%w_]+)%s*%(([^)]*)%)")
  if name then return name, args, false end
  name, args = line:match("^([%w_]+%.[%w_]+)%s*=%s*function%s*%(([^)]*)%)")
  if name then return name, args, name:match("^M%.") ~= nil end
  name, args = line:match("^local%s+([%w_]+)%s*=%s*function%s*%(([^)]*)%)")
  if name then return name, args, false end
  return nil
end
-- }}}

-- {{{ local function exports()
-- What a module actually offers the outside world.
--
-- Lua modules here publish in two ways and the difference is invisible to a
-- reader of the export line. Some define a function as public where it sits;
-- others define it privately, in a fold with its description attached to the
-- private name, and assign it to the module table at the bottom of the file.
-- The second kind is far more common and the first attempt at this generator
-- reported every one of them as an undocumented function, which was the
-- generator being naive rather than the source being thin.
--
-- So an export is resolved: a name assigned from something the folds already
-- describe carries that description, and says which private name it came from.
-- Only an export pointing at nothing the folds know about is a real gap.
local function exports(lines, byname)
  local out, seen = {}, {}

  -- A constant is not a function and does not get a fold, so its description is
  -- whatever comment block sits directly above it. The first version of this
  -- reported every public constant in the project as having nothing said about
  -- it, which was true only in the sense that it was not looking.
  local function comment_above(n)
    local prose, i = {}, n - 1
    while i >= 1 and lines[i]:match("^%-%-") and not lines[i]:match("{{{") do
      table.insert(prose, 1, lines[i]:match("^%-%-%s?(.*)$"))
      i = i - 1
    end
    while #prose > 0 and prose[#prose]:match("^%s*$") do prose[#prose] = nil end
    return prose
  end

  local function add(public_name, target, line)
    if seen[public_name] then return end
    seen[public_name] = true
    local fold = target and byname[target] or byname[public_name]
    local prose = fold and fold.prose or {}
    -- A fold that exists but says nothing, or no fold at all: look upward
    -- before concluding the source is silent.
    if #prose == 0 then prose = comment_above(line) end
    out[#out + 1] = {
      name = public_name, from = target, line = line,
      args = fold and fold.args, prose = prose,
      described = fold ~= nil or #prose > 0,
    }
  end

  for n, line in ipairs(lines) do
    -- A public function defined where it stands.
    local name, args, public = signature(line)
    if name and public then add(name, nil, n) end

    -- One or more exports assigned from names defined earlier. Several on one
    -- line is normal Lua and this project writes it that way, so the two sides
    -- are split and matched up in order.
    local lhs, rhs = line:match("^(M%.[%w_ ,%.]-)%s*=%s*([^=]+)$")
    if lhs and not line:match("=%s*function") then
      local names, targets = {}, {}
      for w in lhs:gmatch("M%.([%w_]+)") do names[#names + 1] = "M." .. w end
      -- Only a bare name on the right is another name for something defined
      -- above. A table literal or a call is a value in its own right, and
      -- reading either as an alias produced two wrong pages: the ten dimension
      -- slots claimed to be published from a function called `m`, and the
      -- dimensionless constant claimed to take an argument.
      for piece in (rhs .. ","):gmatch("([^,]*),") do
        targets[#targets + 1] = piece:match("^%s*([%w_]+)%s*$")
      end
      for i, nm in ipairs(names) do add(nm, targets[i], n) end
    end
  end

  return out
end
-- }}}

-- {{{ local function header()
-- The file's own opening comment, which every program in this project has and
-- which is already written for somebody who has never seen it. Taken verbatim
-- rather than summarised: it is the one piece of a program that was written to
-- be read on its own, and rewriting it here would make two copies that drift.
local function header(lines)
  local out = {}
  for i = 2, #lines do
    local text = lines[i]:match("^%-%-%s?(.*)$")
    if not text then break end
    out[#out + 1] = text
  end
  -- Trailing blanks are an artefact of the comment block's own spacing and
  -- would come out as stray paragraph breaks on the page.
  while #out > 0 and out[#out]:match("^%s*$") do out[#out] = nil end
  return out
end
-- }}}

-- {{{ local function entries()
-- Walk a program and pull out one record per fold: what it is called, what it
-- takes, whether anybody outside can call it, and the prose between the fold
-- marker and the definition.
--
-- It also reports two ways the convention can be broken, because the whole
-- method rests on it holding and this is the only thing that would ever look: a
-- fold with no definition under it, and a fold whose name disagrees with the
-- definition it opens. What a module offers the outside world is a separate
-- question and exports() answers it.
local function entries(lines)
  local found, byname, problems = {}, {}, {}

  local i = 1
  while i <= #lines do
    local declared = lines[i]:match("^%-%-%s*{{{%s*(.-)%s*$")
    if declared then
      -- Everything between the fold marker and the first line that is not a
      -- comment is this function's description.
      local prose, j = {}, i + 1
      while j <= #lines and lines[j]:match("^%-%-") do
        prose[#prose + 1] = lines[j]:match("^%-%-%s?(.*)$")
        j = j + 1
      end
      while #prose > 0 and prose[#prose]:match("^%s*$") do prose[#prose] = nil end

      -- Blank lines between the prose and the definition are allowed, because
      -- some folds separate a long explanation from the code it explains.
      while j <= #lines and lines[j]:match("^%s*$") do j = j + 1 end

      local name, args, public = signature(lines[j] or "")
      if not name then
        problems[#problems + 1] = {
          kind = "no definition", line = i, what = declared,
        }
      else
        -- The fold says what the function is called and so does the definition,
        -- and they can disagree -- somebody renames one and not the other, and
        -- from then on the fold is describing a function that does not exist.
        local claimed = declared:match("([%w_%.]+)%s*%(%s*%)%s*$")
                     or declared:match("([%w_%.]+)%s*$")
        local bare = name:gsub("^M%.", "")
        if claimed and claimed ~= name and claimed ~= bare
           and claimed:gsub("^M%.", "") ~= bare then
          problems[#problems + 1] = {
            kind = "fold and definition disagree", line = i,
            what = ("fold says %s, definition says %s"):format(claimed, name),
          }
        end
        local rec = { name = name, args = args, public = public,
                      prose = prose, line = j }
        found[#found + 1] = rec
        byname[name] = rec
      end
      i = j + 1
    else
      i = i + 1
    end
  end

  return found, byname, problems
end
-- }}}

-- {{{ local function reads()
-- Which other programs this one loads. Every instrument here reaches for its
-- dependencies with dofile against the project root rather than with require,
-- because there is no package path to configure and a hard-coded root is the
-- project's own convention for scripts.
local function reads(lines)
  local out, seen = {}, {}
  for _, line in ipairs(lines) do
    local dep = line:match('dofile%(DIR %.%. "/src/(%d+)%-')
    if dep and not seen[dep] then seen[dep] = true; out[#out + 1] = dep end
  end
  return out
end
-- }}}

-- {{{ local function runnable()
-- Every program here is a module something else can load. Some are also
-- programs a person can run, and they say so by checking whether they are the
-- file that was invoked. The page should tell a reader which it is looking at,
-- because the two are used completely differently.
local function runnable(lines, base)
  for _, line in ipairs(lines) do
    if line:match("if arg and arg%[0%]") then return true end
  end
  return false
end
-- }}}

-- ---------------------------------------------------------------------------
-- Writing a page
-- ---------------------------------------------------------------------------

-- {{{ local function para()
-- Comment lines back into paragraphs. A comment block is written as prose with
-- blank comment lines between paragraphs, and markdown wants the same thing
-- without the leading dashes.
local function para(prose)
  local out, buf = {}, {}
  local function flush()
    if #buf > 0 then out[#out + 1] = table.concat(buf, "\n"); buf = {} end
  end
  for _, line in ipairs(prose) do
    if line:match("^%s*$") then flush() else buf[#buf + 1] = line end
  end
  flush()
  return out
end
-- }}}

-- {{{ local function one_line()
-- The first sentence of a description, for a table cell. A table is an index
-- and not the documentation; somebody who wants the rest reads the section
-- under it.
local function one_line(prose)
  if #prose == 0 then return "*(no description in the source)*" end
  local text = table.concat(prose, " "):gsub("%s+", " ")
  local stop = text:find("%. ")
  local first = stop and text:sub(1, stop) or text
  if #first > 150 then first = first:sub(1, 147) .. "..." end
  return first
end
-- }}}

-- {{{ local function render()
-- One companion page. Everything on it comes out of the program itself, so the
-- page cannot disagree with the program for longer than it takes to run this.
local function render(base, lines)
  local folds, byname, problems = entries(lines)
  local ex = exports(lines, byname)
  local head = header(lines)
  local out = {}
  local function say(fmt, ...)
    out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  say("# %s — info", base)
  say("")
  say("*Generated by `104` from the folds in `%s.lua`. Do not edit this page;", base)
  say("edit the program and run the sweep again.*")
  say("")
  say("**An instrument** — phase 14. Not part of the machine, and it does not ship")
  say("to whoever builds one.")
  say("")

  say("## What it is")
  say("")
  for _, p in ipairs(para(head)) do say(p); say("") end

  say("## What it offers")
  say("")
  if #ex == 0 then
    say("Nothing. This file is run rather than loaded, so it publishes no names.")
    say("")
  else
    say("| call | takes | what it does |")
    say("|---|---|---|")
    for _, e in ipairs(ex) do
      say("| `%s` | %s | %s |", e.name,
          e.args and (e.args == "" and "nothing" or ("`" .. e.args .. "`")) or "—",
          one_line(e.prose):gsub("|", "\\|"))
    end
    say("")
    -- The long form, for the ones that have one. A table cell is an index; this
    -- is where the author's actual explanation lives.
    local any = false
    for _, e in ipairs(ex) do if #e.prose > 1 then any = true end end
    if any then
      say("### In the author's words")
      say("")
      for _, e in ipairs(ex) do
        if #e.prose > 1 then
          say("**`%s`**%s", e.name,
              e.from and (" — published from `" .. e.from .. "`") or "")
          say("")
          for _, p in ipairs(para(e.prose)) do say(p); say("") end
        end
      end
    end
  end

  local private = {}
  for _, f in ipairs(folds) do
    if not byname[f.name] or not f.public then
      local exported = false
      for _, e in ipairs(ex) do if e.from == f.name or e.name == f.name then exported = true end end
      if not exported then private[#private + 1] = f end
    end
  end
  if #private > 0 then
    say("## How it works inside")
    say("")
    say("Nothing outside this file can call these. They are listed so a reader")
    say("knows what is in it, not how — a companion page treats a function as a")
    say("box with a label on it.")
    say("")
    say("| function | takes | what it is for |")
    say("|---|---|---|")
    for _, f in ipairs(private) do
      say("| `%s` | %s | %s |", f.name,
          f.args and (f.args == "" and "nothing" or ("`" .. f.args .. "`")) or "—",
          one_line(f.prose):gsub("|", "\\|"))
    end
    say("")
  end

  local dep = reads(lines)
  say("## What it reads")
  say("")
  if #dep == 0 then
    say("Nothing. It stands alone, which for an instrument means it can be run")
    say("against a project that does not load.")
  else
    local refs = {}
    for _, d in ipairs(dep) do refs[#refs + 1] = "`" .. d .. "`" end
    say("%s. Every instrument here reaches for its dependencies with `dofile`", table.concat(refs, ", "))
    say("against a hard-coded project root rather than with `require`, because")
    say("there is no package path to configure and a root that can be overridden")
    say("by an argument is this project's convention for anything runnable.")
  end
  say("")

  say("## Running it")
  say("")
  if runnable(lines) then
    say("Both. Something else can load it, and a person can run it:")
    say("")
    say("    luajit src/%s.lua [project-directory]", base)
  else
    say("It is a module. Something else loads it; there is nothing to run.")
  end
  say("")

  if #problems > 0 then
    say("## What this page could not see")
    say("")
    say("The method here reads the fold each function is wrapped in. These broke")
    say("that, and are defects in the program rather than in the page.")
    say("")
    for _, p in ipairs(problems) do
      say("- line %d: %s — %s", p.line, p.kind, p.what)
    end
    say("")
  end

  say("---")
  say("")
  say("*Every function in this project is wrapped in a vimfold that opens with a")
  say("comment carrying its name, followed by prose, followed by the definition.")
  say("That was adopted so a long file collapses neatly in an editor. It is also,")
  say("by accident, a machine-readable statement of what a module offers, and it")
  say("is the only reason this page can exist — Lua itself says nothing about what")
  say("a file exports.*")

  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.run()
-- Every program in src/, described. Deterministic: no timestamps and no run
-- identifiers, entries in source order, so that two runs produce identical
-- bytes and a change to a page means a change to a program.
function M.run(dir, opts)
  dir = dir or DIR
  opts = opts or {}
  local R = { written = {}, silent = {}, unfolded = {}, broken = {} }

  local pipe = io.popen(("ls %s/src/*.lua 2>/dev/null"):format(dir))
  if not pipe then return R end
  local paths = {}
  for line in pipe:lines() do paths[#paths + 1] = line end
  pipe:close()

  for _, path in ipairs(paths) do
    local base = path:match("([^/]+)%.lua$")
    local lines = read_lines(path)
    if lines then
      local _, byname, problems = entries(lines)
      for _, e in ipairs(exports(lines, byname)) do
        -- A public name with nothing said about it anywhere. This is the gap
        -- the sweep exists to find, and it is far more common than a broken
        -- fold: a function gets a fold because the editor wants one, and the
        -- prose is what gets left out.
        if not e.described then
          R.unfolded[#R.unfolded + 1] = { file = base, name = e.name }
        elseif #e.prose == 0 then
          R.silent[#R.silent + 1] = { file = base, name = e.name }
        end
      end
      for _, p in ipairs(problems) do
        R.broken[#R.broken + 1] = { file = base, kind = p.kind, what = p.what, line = p.line }
      end

      local body = render(base, lines)
      if not opts.dry then
        local fh = io.open(("%s/src/%s.info.md"):format(dir, base), "w")
        if fh then fh:write(body); fh:close() end
      end
      R.written[#R.written + 1] = base
    end
  end
  return R
end
-- }}}

-- {{{ function M.report()
-- How many pages were written, and the three ways the source can leave this
-- with nothing to say: a fold that is broken, a public name with no fold at
-- all, and a fold with no prose in it. The third is by far the commonest and
-- is the one worth acting on.
function M.report(R, out)
  out = out or io.stdout
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end
  say("")
  say("  the programs, described")
  say("")
  say("    %d companion pages written", #R.written)
  say("")
  if #R.broken > 0 then
    say("  BROKEN FOLDS -- the convention this method reads is not holding")
    for _, b in ipairs(R.broken) do
      say("    %-34s line %-5d %s: %s", b.file, b.line, b.kind, b.what)
    end
    say("")
  end
  if #R.unfolded > 0 then
    say("  NOT IN A FOLD -- %d public names with nothing to describe them", #R.unfolded)
    say("  Usually a constant. A constant in a module's interface wants a")
    say("  sentence as much as a function does.")
    for _, u in ipairs(R.unfolded) do say("    %-34s %s", u.file, u.name) end
    say("")
  end
  if #R.silent > 0 then
    say("  UNDESCRIBED -- %d public names whose fold says nothing", #R.silent)
    say("  The fold is there because the editor wants one; the sentence saying")
    say("  what the function is for was never written. These are the pages worth")
    say("  improving, and improving them means editing the program.")
    for _, s in ipairs(R.silent) do say("    %-34s %s", s.file, s.name) end
    say("")
  end
  return 0
end
-- }}}

M.read_lines = read_lines
M.signature  = signature
M.header     = header
M.exports    = exports
M.entries    = entries
M.reads      = reads
M.runnable   = runnable
M.render     = render

if arg and arg[0] and arg[0]:match("104%-the%-programs%-described%.lua$") then
  os.exit(M.report(M.run(DIR)))
end

return M
