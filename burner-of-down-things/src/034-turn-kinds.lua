-- 034-turn-kinds.lua
--
-- What a turn is on disk, and the table of turn kinds (docs/005). A turn is
-- one run of a model aimed at one job; the machine prepares a folder for it
-- holding what it is asked (prompt.md), the paths it may read and write
-- (confinement.lua), and later its standing instructions, its output and its
-- verdict.
--
-- The clean room is a property of this table: only `outline` and `describe`
-- list the source among their reads. Build and repair turns cannot see it,
-- and tests/040 holds that.
--
-- Paths in a kind's `reads` and `writes` are names resolved against the case:
--   "source"              the case's source folder
--   "survey/", "blueprint/", "design/"   folders inside the case; the slash
--                                        matters: a folder named without one
--                                        would be reached through its parent,
--                                        which is the whole case
--   "blueprint/outline.tsv"              a single file
--   "blueprint/issues/{{about}}-"        a prefix: files whose names start so
--   "turn"                               the turn's own folder
--   "request"                            the request file, input/{{request}}
-- A write entry is a path prefix: a change is inside it when the changed
-- path starts with it (a folder entry ends with "/").

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")

local kinds = {}

-- {{{ local function lines
local function lines(...)
    return table.concat({ ... }, "\n")
end
-- }}}

kinds.TABLE = {
    outline = {
        reads = { "source", "survey/" },
        writes = { "blueprint/outline.tsv" },
        crafts = { "issue-lifecycle" },
        template = lines(
            "turn: outline {{about}}",
            "",
            "Plan a blueprint of the software in the source folder, as ONE table.",
            "",
            "The blueprint is a set of issue files in the house format (the issue-lifecycle",
            "craft in your instructions). Each issue describes one piece of the software",
            "completely enough that someone who never sees the source could build it. You",
            "are only planning here: which issues, in which phases, built on which, covering",
            "which source files. Another turn writes each issue.",
            "",
            "Rules for the plan:",
            "- Phases are clusters of functionality, not steps in time. Foundations get low",
            "  numbers because others build on them.",
            "- An id is the phase digit then two digits: 101, 102, 201. Unique.",
            "- A name is lower-case words joined by dashes.",
            "- blocked_by lists ids this issue builds on (space-separated), or -. No cycles.",
            "- covers lists source paths (relative, space-separated) this issue describes.",
            "  Every code and build file in the survey must be covered by some issue.",
            "- Prefer issues a person could build in one sitting; split large files across",
            "  several issues if they hold several mechanisms.",
            "",
            "Write the table to {{outline_path}} exactly in this form: a header line, then",
            "one line per issue, fields separated by single TAB characters:",
            "",
            "#id\tname\tblocked_by\tcovers",
            "101\tthe-first-piece\t-\tsrc/a.lua src/b.lua",
            "",
            "The survey summary:",
            "{{survey_summary}}",
            "",
            "Every surveyed file (path, language, role, lines, bytes):",
            "{{file_table}}",
            "",
            "Findings from an earlier attempt that must be fixed:",
            "{{findings}}"
        ),
    },
    describe = {
        reads = { "source", "survey/", "blueprint/outline.tsv" },
        writes = { "blueprint/issues/{{about}}-" },
        crafts = { "issue-lifecycle" },
        template = lines(
            "turn: describe {{about}}",
            "",
            "Write issue {{about}} of the blueprint: one issue file describing one piece of",
            "the software in the source folder, in the house format (the issue-lifecycle",
            "craft in your instructions).",
            "",
            "Its row in the outline:  id {{about}}, name {{name}}, blocked by {{blocked_by}}",
            "It covers these source files:",
            "{{covered_files}}",
            "",
            "Read those files. Describe what the piece does, its data (fields and their",
            "types, down to strings and numbers), and its decisions (what each branch",
            "leads to), precisely enough that a builder who never sees the source can",
            "build it. Name functions and structures in words; do not paste code.",
            "",
            "Write the file {{issue_path}} with exactly these sections, as `## ` headings:",
            "- the title line `# {{about}} — <the name in words>`",
            "- ## Current Behavior      (in a blueprint: \"Nothing is built yet.\")",
            "- ## Intended Behavior",
            "- ## Suggested Implementation Steps   (numbered; each with its test)",
            "- ## Acceptance            (a ```sh fenced block: one shell command per line,",
            "                            run from the design folder; each must exit 0 when",
            "                            this piece is built. At least one.)",
            "- ## Blocked by            (the ids {{blocked_by}}, one per line as `- 101`, or None)",
            "- ## Covers                (the covered source paths, one per line)",
            "",
            "The whole outline, so you can refer to neighbouring issues by id:",
            "{{outline_text}}",
            "",
            "Findings from an earlier attempt that must be fixed:",
            "{{findings}}"
        ),
    },
    build = {
        reads = { "blueprint/", "design/" },
        writes = { "design/" },
        crafts = {},
        template = lines(
            "turn: build {{about}}",
            "",
            "Build issue {{about}} of the blueprint into the design folder (your working",
            "folder). The original source does not exist for you and must not be asked",
            "for: everything you need is in the blueprint.",
            "",
            "What the design should be: {{target}}",
            "",
            "Write code under src/ and tests under tests/. Make every command in the",
            "issue's Acceptance section pass when run from the design folder; the",
            "machine will run exactly those commands after you finish. Keep what earlier",
            "issues built working: their acceptance is re-run too.",
            "",
            "The issue:",
            "{{issue_text}}",
            "",
            "The issues it is built on (already built in the design folder):",
            "{{blocker_texts}}"
        ),
    },
    repair = {
        reads = { "blueprint/", "design/" },
        writes = { "design/" },
        crafts = {},
        template = lines(
            "turn: repair {{about}}",
            "",
            "Issue {{about}} was built into the design folder (your working folder), but",
            "an acceptance command failed. Fix the design so it passes. The original",
            "source does not exist for you: work from the blueprint.",
            "",
            "What the design should be: {{target}}",
            "",
            "The failing command:  {{command}}",
            "Its output (last lines):",
            "{{output}}",
            "",
            "The issue:",
            "{{issue_text}}",
            "",
            "The issues it is built on:",
            "{{blocker_texts}}"
        ),
    },
    -- The referee sees the blueprint and nothing else: not the source (it
    -- checks behaviour, not a copy), not the design (a referee that shares
    -- anything with what it grades grades nothing). It writes outside the
    -- design folder, where no build or repair turn may write (issue 506).
    referee = {
        reads = { "blueprint/" },
        writes = { "workflows/" },
        crafts = {},
        template = lines(
            "turn: referee {{about}}",
            "",
            "Write end-to-end workflows that check a design built from this blueprint the",
            "way a person using it would: with the same kinds of input a person gives it",
            "(the commands they type, the files they hand it) and checking only what a",
            "person could see (what it prints, the files it writes, how it exits).",
            "Protocols, not procedures: never call its internal functions by name, never",
            "read its source. You have not seen the design and must not assume anything",
            "about it beyond what the blueprint says.",
            "",
            "What the design is meant to be: {{target}}",
            "",
            "Write each workflow as a shell script in your working folder named",
            "NN-<words-with-dashes>.sh (NN two digits). Each is run with bash from the",
            "design's folder and must exit 0 exactly when the behaviour holds. Its second",
            "line must be a comment naming the issues whose behaviour it exercises:",
            "# covers: 201 301",
            "Use temporary files for anything the design stores; leave nothing behind.",
            "Every workflow will first be run against an empty folder and must FAIL",
            "there — a workflow that passes with nothing built checks nothing.",
            "Write as many as it takes to exercise every issue's behaviour at least once.",
            "",
            "The blueprint, every issue whole:",
            "{{blueprint_text}}",
            "",
            "Findings from an earlier attempt that must be fixed:",
            "{{findings}}"
        ),
    },
    -- Dynamic re-abstraction (issue 507): when a workflow fails, an audit
    -- looks at one issue's part and fixes it only if the fault is there; an
    -- inspection looks at a group of issues, writes no code, and names the
    -- one part that needs the fix.
    audit = {
        reads = { "blueprint/", "design/" },
        writes = { "design/" },
        crafts = {},
        template = lines(
            "turn: audit {{about}}",
            "",
            "An end-to-end workflow fails on the design (your working folder). Audit the",
            "part of the design that issue {{about}} describes: does it do what the issue",
            "says? If the fault is in this part, fix it here and nowhere else. If this part",
            "is right, CHANGE NOTHING: an unchanged design is how you say the fault is",
            "elsewhere. The original source does not exist for you.",
            "",
            "What the design should be: {{target}}",
            "",
            "The failing workflow: {{workflow}}",
            "What it printed (last lines):",
            "{{output}}",
            "",
            "A wider look found: {{finding}}",
            "",
            "The issue:",
            "{{issue_text}}"
        ),
    },
    inspect = {
        reads = { "blueprint/", "design/" },
        writes = { "turn" },
        crafts = {},
        template = lines(
            "turn: inspect {{about}}",
            "",
            "An end-to-end workflow fails on the design, and auditing each of these issues'",
            "parts alone found nothing. Look at them together — how they meet, what one",
            "assumes of another — and name the ONE issue whose part needs the fix. Do not",
            "write the fix and do not change the design.",
            "",
            "The failing workflow: {{workflow}}",
            "What it printed (last lines):",
            "{{output}}",
            "",
            "Write the file {{finding_path}}: its first line is the issue id (one of",
            "{{group}}) or the word none; the lines after it say why, for the audit that",
            "will fix it.",
            "",
            "The issues, whole:",
            "{{group_texts}}"
        ),
    },
    locate = {
        reads = { "request", "blueprint/" },
        writes = { "turn" },
        crafts = {},
        template = lines(
            "turn: locate {{about}}",
            "",
            "A person asked for a change to the software this blueprint describes. Decide",
            "which issues of the blueprint the change touches: the issues whose intended",
            "behavior must be edited for the change to be true.",
            "",
            "The request ({{about}}):",
            "{{request_text}}",
            "",
            "The issues (id, name, intended behavior):",
            "{{issue_list}}",
            "",
            "Write the file {{touched_path}}: one line per touched issue, just its id.",
            "If the change needs a piece that no issue describes, add a line `new <phase>`",
            "naming the phase digit it belongs in. Touch as few issues as make the change",
            "true.",
            "",
            "Findings from an earlier attempt that must be fixed:",
            "{{findings}}"
        ),
    },
    amend = {
        reads = { "request", "blueprint/" },
        writes = { "blueprint/issues/", "blueprint/outline.tsv" },
        crafts = { "issue-lifecycle" },
        template = lines(
            "turn: amend {{about}}",
            "",
            "Write a person's requested change into the blueprint. Edit the touched",
            "issues' Intended Behavior, Suggested Implementation Steps and Acceptance so",
            "the change is true of them; keep every required section. If a new issue is",
            "needed, write it in the same format and add its row to the outline table",
            "(TAB-separated: id, name, blocked_by, covers — covers may be -).",
            "",
            "The request ({{about}}):",
            "{{request_text}}",
            "",
            "The touched issues, whole:",
            "{{touched_texts}}",
            "",
            "The outline:",
            "{{outline_text}}",
            "",
            "Findings from an earlier attempt that must be fixed:",
            "{{findings}}"
        ),
    },
}

-- {{{ function kinds.fill
-- Fills {{slot}} marks from `values`. A slot with no value refuses: a prompt
-- with a hole in it is never sent.
function kinds.fill(template, values)
    return (template:gsub("{{([%w_]+)}}", function(slot)
        local value = values[slot]
        if value == nil then
            error("turn kinds: the slot '" .. slot .. "' has no value")
        end
        return tostring(value)
    end))
end
-- }}}

-- {{{ local function resolve_path
-- A kind's path name, made absolute for one case and turn.
local function resolve_path(name, record, turn_folder, values)
    name = kinds.fill(name, values)
    if name == "source" then
        return record.source .. "/"
    end
    if name == "turn" then
        return turn_folder .. "/"
    end
    if name == "request" then
        return record.input .. "/" .. values.request
    end
    return record.folder .. "/" .. name
end
-- }}}

-- {{{ local function next_turn_number
-- One more than the highest four-digit number already in turns/.
local function next_turn_number(record)
    local highest = 0
    for _, name in ipairs(fs.list(record.turns)) do
        local n = tonumber(name:match("^(%d%d%d%d)%-"))
        if n and n > highest then
            highest = n
        end
    end
    return highest + 1
end
-- }}}

-- {{{ function kinds.make_turn
-- Prepares a turn folder. `values` fills the kind's template and path names;
-- `values.about` names what the turn is about. Returns a turn table:
--   id, kind, about (strings); folder (absolute path);
--   reads, writes (arrays of absolute paths; writes are prefixes);
--   crafts (array of skill names); prompt (string).
function kinds.make_turn(record, kind, values)
    local row = kinds.TABLE[kind]
    if not row then
        error("turn kinds: no kind named '" .. tostring(kind) .. "'")
    end
    local about = values.about or "-"
    local number = next_turn_number(record)
    local id = string.format("%04d-%s-%s", number, kind, (about:gsub("[^%w%-]", "_")))
    local folder = record.turns .. "/" .. id
    fs.make_folder(folder)
    local reads, writes = {}, {}
    for i, name in ipairs(row.reads) do
        reads[i] = resolve_path(name, record, folder, values)
    end
    for i, name in ipairs(row.writes) do
        writes[i] = resolve_path(name, record, folder, values)
    end
    local prompt = kinds.fill(row.template, values)
    local turn = {
        id = id, kind = kind, about = about, folder = folder, case_folder = record.folder,
        reads = reads, writes = writes, crafts = row.crafts, prompt = prompt,
    }
    fs.write(folder .. "/prompt.md", prompt .. "\n")
    text_tables.write_record(folder .. "/confinement.lua", {
        id = id, kind = kind, about = about, case_folder = record.folder,
        reads = reads, writes = writes,
    })
    return turn
end
-- }}}

-- {{{ function kinds.reads_source
-- Whether a kind may read the source (the clean-room rule).
function kinds.reads_source(kind)
    for _, name in ipairs(kinds.TABLE[kind].reads) do
        if name == "source" then
            return true
        end
    end
    return false
end
-- }}}

return kinds
