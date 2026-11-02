-- table-of-contents.lua
--
-- Knows which documents a project keeps under docs/ and which of them its
-- docs/table-of-contents.md reaches. The house rule is that every new
-- document is added to that file; this is the reading half that lets a tool
-- check the rule and keep it (update-toc is the writing half).
--
-- How it works, in general terms: it lists every markdown file under docs/,
-- reads each one's first top-level heading as its title, and collects every
-- link the table of contents makes, resolved the way a markdown viewer would
-- resolve it. A document no link reaches is unlisted; a link that reaches no
-- file is dead. It writes nothing.
--
-- WHY IT DOES NOT REGENERATE THE TABLE OF CONTENTS
--
-- The tables on disk are written by hand: grouped under headings that mean
-- something to their project, each entry with a sentence saying what the
-- document is for, some with status marks. A generator that rebuilt them from
-- the file tree would throw all of that away. So this library only finds the
-- gaps, and the one block it builds -- the list of documents not yet filed --
-- lives between two markers that nothing else writes inside. A full tree is
-- built only for a project that has no table of contents at all.
--
-- Load with dofile(SCRIPTS_DIR .. "/libs/table-of-contents.lua").

local M = {}

-- {{{ markers
-- The two lines that fence off the block this library owns inside a
-- hand-written table of contents. Everything outside them is the owner's.
M.START_MARKER = "<!-- update-toc: unfiled documents start -->"
M.END_MARKER   = "<!-- update-toc: unfiled documents end -->"
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end
-- }}}

-- {{{ local function shell_quote
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function M.normalize
-- Collapse "." and ".." out of a slash-separated path. A path that climbs
-- above its start keeps its leading "..", so a link out of the project stays
-- recognisably outside it rather than being folded onto something inside.
function M.normalize(path)
    local absolute = path:sub(1, 1) == "/"
    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                parts[#parts] = nil
            elseif not absolute then
                parts[#parts + 1] = ".."
            end
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return (absolute and "/" or "") .. table.concat(parts, "/")
end
-- }}}

-- {{{ function M.title_of
-- The document's first "# " heading outside a code block, or nil. A heading
-- inside a fence is an example, not the document's name.
function M.title_of(content)
    local in_fence = false
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^%s*```") or line:match("^%s*~~~") then
            in_fence = not in_fence
        elseif not in_fence then
            local title = line:match("^#%s+(.-)%s*#*%s*$")
            if title and title ~= "" then
                return title
            end
        end
    end
    return nil
end
-- }}}

-- {{{ function M.scan_docs
-- Every markdown file under <project>/docs, as a sorted list of
--   { rel = "docs/formats/mpq.md", title = "MPQ Archive Format" or nil }
-- The table of contents itself is left out, and so is anything whose path
-- (relative to the project) matches one of the Lua patterns in ignore.
-- Hidden files and folders are left out: they are nobody's documentation.
-- Symbolic links to files are documents like any other (the house links one
-- guide into every project); a link to nothing is not a document, and is
-- left for whoever reads the folder to notice.
function M.scan_docs(project_dir, ignore)
    ignore = ignore or {}
    local docs_dir = project_dir .. "/docs"
    local docs = {}
    local cmd = "find " .. shell_quote(docs_dir)
        .. " -name '.*' -prune -o \\( -type f -o -xtype f \\) -name '*.md' -print 2>/dev/null"
    local pipe = io.popen(cmd)
    for path in pipe:lines() do
        local rel = path:sub(#project_dir + 2)
        local skip = (rel == M.toc_rel)
        for _, pattern in ipairs(ignore) do
            if rel:match(pattern) then skip = true end
        end
        if not skip then
            local content = read_file(path)
            docs[#docs + 1] = { rel = rel, title = content and M.title_of(content) }
        end
    end
    pipe:close()
    table.sort(docs, function(a, b) return a.rel < b.rel end)
    return docs
end
-- }}}

-- The table of contents' place in a project. One place, house-wide.
M.toc_rel = "docs/table-of-contents.md"

-- {{{ function M.links_in
-- Every link a markdown text makes, outside code, as a list of
--   { target = "formats/mpq.md", line = 12 }
-- with any "#anchor" and any quoted title taken off. Inline links
-- [text](target), angle-bracketed targets [text](<a b.md>), and reference
-- definitions "[name]: target" are read. Links to other sites, mail
-- addresses and bare anchors are not files and are left out.
function M.links_in(content)
    local links = {}
    local in_fence = false
    local n = 0
    -- {{{ local function keep
    local function keep(target)
        target = target:match("^<(.-)>$") or target:match("^(%S+)") or ""
        target = target:gsub("#.*$", "")
        target = target:gsub("%%20", " ")
        if target ~= "" and not target:match("^%a[%w+.-]*:") then
            links[#links + 1] = { target = target, line = n }
        end
    end
    -- }}}
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        if line:match("^%s*```") or line:match("^%s*~~~") then
            in_fence = not in_fence
        elseif not in_fence then
            -- inline code spans are text, not links
            local text = line:gsub("`[^`]*`", "")
            for target in text:gmatch("%]%(%s*(<[^>]*>)") do keep(target) end
            for target in text:gmatch("%]%(%s*([^<)][^)]*)%)") do keep(target) end
            local ref = text:match("^%s*%[[^%]]+%]:%s*(%S+)")
            if ref then keep(ref) end
        end
    end
    return links
end
-- }}}

-- {{{ local function exists
local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    -- a folder is a fine thing to link to, and a broken one is asked the
    -- shell; os.execute answers 0 under LuaJIT and true under Lua 5.4
    local status = os.execute("test -e " .. shell_quote(path))
    return status == 0 or status == true
end
-- }}}

-- {{{ function M.check
-- Compares a project's documents with its table of contents. Returns
--   {
--     toc_exists = true/false,
--     docs       = the list from scan_docs,
--     unlisted   = docs no link in the table reaches,
--     dead       = { target, line } links that reach no file,
--   }
-- A link is resolved against the table's own folder, the way a viewer
-- follows it; one starting with "/" is read from the project's root, which is
-- how the house rule itself writes the path ("/docs/table-of-contents.md").
-- A document listed only inside the unfiled block counts as listed: the table
-- reaches it, which is what the rule asks.
function M.check(project_dir, ignore)
    local content = read_file(project_dir .. "/" .. M.toc_rel)
    local result = M.check_text(project_dir, content or "", ignore)
    result.toc_exists = content ~= nil
    return result
end
-- }}}

-- {{{ function M.check_text
-- The same comparison against a table of contents given as text rather than
-- read from disk -- what update-toc uses to ask which documents the table
-- reaches once its own unfiled block is taken out. toc_exists is left unset.
function M.check_text(project_dir, content, ignore)
    local result = { docs = M.scan_docs(project_dir, ignore), unlisted = {}, dead = {} }

    local toc_folder = M.toc_rel:match("^(.*)/") or ""
    local reached = {}
    for _, link in ipairs(M.links_in(content)) do
        local rel
        if link.target:sub(1, 1) == "/" then
            rel = M.normalize(link.target:sub(2))
        else
            rel = M.normalize(toc_folder .. "/" .. link.target)
        end
        reached[rel] = true
        if not exists(project_dir .. "/" .. rel) then
            result.dead[#result.dead + 1] = { target = link.target, line = link.line }
        end
    end

    for _, doc in ipairs(result.docs) do
        if not reached[doc.rel] then
            result.unlisted[#result.unlisted + 1] = doc
        end
    end
    return result
end
-- }}}

-- {{{ local function link_text
-- How a document is named in a list: its title, or its file name without the
-- extension when it has none. Square brackets would end the link text early.
local function link_text(doc)
    local text = doc.title or doc.rel:match("([^/]+)%.md$")
    return (text:gsub("[%[%]]", "\\%0"))
end
-- }}}

-- {{{ local function href
-- A document's path as the table of contents links to it: relative to
-- docs/, with spaces written as %20 so the link survives every viewer.
local function href(doc)
    return (doc.rel:gsub("^docs/", ""):gsub(" ", "%%20"))
end
-- }}}

-- {{{ function M.unfiled_block
-- The block this library owns inside a hand-written table of contents: the
-- documents nothing links to yet, one line each, between the two markers.
-- An empty list gives an empty string -- once everything is filed, the
-- block disappears instead of announcing that nothing is in it.
function M.unfiled_block(unlisted)
    if #unlisted == 0 then return "" end
    local lines = {
        M.START_MARKER,
        "## Not Yet Filed",
        "",
        "Documents the entries above do not link to yet, listed by `update-toc`.",
        "Move a line into its place above and it leaves this list on the next run.",
        "",
    }
    for _, doc in ipairs(unlisted) do
        lines[#lines + 1] = "- [" .. link_text(doc) .. "](" .. href(doc) .. ")"
    end
    lines[#lines + 1] = M.END_MARKER
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.with_unfiled_block
-- The table of contents with its unfiled block replaced by a new one: in the
-- old block's place when there is one, otherwise appended at the end after a
-- blank line. Nothing outside the markers changes. A start marker with no end
-- marker is an error rather than a guess, because guessing where the block
-- ends could swallow the owner's text.
function M.with_unfiled_block(content, block)
    local s = content:find(M.START_MARKER, 1, true)
    local e = content:find(M.END_MARKER, 1, true)
    if s and not e or e and not s or (s and e and e < s) then
        error("the unfiled-documents markers in the table of contents are not a matched pair")
    end
    if s then
        local before = content:sub(1, s - 1)
        local after = content:sub(e + #M.END_MARKER)
        if block == "" then
            -- take the blank line that set the block apart with it
            before = before:gsub("\n\n$", "\n")
            after = after:gsub("^\n", "")
            return before .. after
        end
        return before .. block .. after
    end
    if block == "" then return content end
    if content ~= "" and not content:match("\n$") then content = content .. "\n" end
    return content .. (content ~= "" and "\n" or "") .. block .. "\n"
end
-- }}}

-- {{{ function M.tree
-- A whole table of contents for a project that has none: every document as a
-- nested list following the folders under docs/, folders first, each named
-- in bold with a trailing slash. A nested list rather than a box-drawn tree
-- in a code block, because a link inside a code block is not a link.
-- Carries no date: a stamp of when a tool ran is not a fact about the
-- documents, and would make an unchanged table differ every time.
function M.tree(project_name, docs)
    -- {{{ build the folder tree
    local root = { folders = {}, order = {}, files = {} }
    for _, doc in ipairs(docs) do
        local node = root
        local inner = doc.rel:gsub("^docs/", "")
        local folders = {}
        for part in inner:gmatch("([^/]+)/") do folders[#folders + 1] = part end
        for _, part in ipairs(folders) do
            if not node.folders[part] then
                node.folders[part] = { folders = {}, order = {}, files = {} }
                node.order[#node.order + 1] = part
            end
            node = node.folders[part]
        end
        node.files[#node.files + 1] = doc
    end
    -- }}}

    local lines = {
        "# " .. project_name .. " Documentation",
        "",
        "Every document under `docs/`, by folder. Written by `update-toc`;",
        "edit it freely -- later runs only add documents it does not link to.",
        "",
    }
    -- {{{ local function walk
    local function walk(node, depth)
        local indent = string.rep("  ", depth)
        table.sort(node.order)
        for _, name in ipairs(node.order) do
            lines[#lines + 1] = indent .. "- **" .. name .. "/**"
            walk(node.folders[name], depth + 1)
        end
        table.sort(node.files, function(a, b)
            return link_text(a):lower() < link_text(b):lower()
        end)
        for _, doc in ipairs(node.files) do
            lines[#lines + 1] = indent .. "- [" .. link_text(doc) .. "](" .. href(doc) .. ")"
        end
    end
    -- }}}
    walk(root, 0)
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

return M
