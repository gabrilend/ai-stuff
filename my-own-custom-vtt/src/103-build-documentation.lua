--[[
103-build-documentation.lua -- turns the project's Markdown into a linked site.

WHAT THIS IS, for somebody who has not opened it: this project's thinking lives
in about a hundred and thirty Markdown files spread over six directories -- the
design, the vision it came from, every issue that built it, and a companion file
for every piece of source. Read one at a time in an editor they are a pile. This
turns them into a directory of HTML pages with a table of contents down the left
of every one, where every mention of an issue, a document or a source file is a
link to it.

WHY A TOOL AND NOT A HUNDRED AND THIRTY HAND-WRITTEN PAGES: because they would
stop matching their sources in the first week. Nothing in docs/HTML/ is ever
edited. It is regenerated, and it is not committed, for the same reason no other
generated file in this project is -- a generated file in a repository is a file
somebody eventually edits and then wonders why the tool disagrees with it.

WHY LUA: it is this project's preferred language, LuaJIT is already a dependency
because the rules layer needs it, and this is string handling with no determinism
requirement and no place in the simulation. Writing it in C would be choosing the
language least suited to the job for no benefit.

IT REPORTS WHAT IT COULD NOT RESOLVE. A link to a document that does not exist, a
mention of a source file with no companion, a page nothing links to. A dead link
found by the tool is a documentation bug found for free, and a tool that silently
emits dead links is a tool that manufactures them.

Usage:
    ./build-docs                 -- build the site
    ./build-docs /path/to/prj    -- from a checkout somewhere else
]]

-- The project root. Hard-coded so the script works from any directory, and
-- overridable as the first argument so a checkout elsewhere still works.
local DIR = "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt"

if arg and arg[1] and arg[1] ~= "" then
    DIR = arg[1]
end

local OUT = DIR .. "/docs/HTML"

-- {{{ local function shell_lines
local function shell_lines(command)
    local out = {}
    local pipe = io.popen(command)

    if pipe == nil then
        return out
    end

    for line in pipe:lines() do
        out[#out + 1] = line
    end

    pipe:close()
    return out
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local handle = io.open(path, "r")

    if handle == nil then
        return nil
    end

    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ local function write_file
local function write_file(path, text)
    local handle = io.open(path, "w")

    if handle == nil then
        return false
    end

    handle:write(text)
    handle:close()
    return true
end
-- }}}

--[[
The sections, in the order they appear down the side.

DATA RATHER THAN CODE, because the ordering is the interesting decision and a
list you can read top to bottom is how somebody argues with it. The order is the
order a person would want to meet the project in: what it is, then how it was
built, then what each piece does.
]]
local SECTIONS = {
    { title = "the vision",     dir = "notes",            depth = 1 },
    { title = "the design",     dir = "docs",             depth = 1 },
    { title = "in progress",    dir = "issues",           depth = 1 },
    { title = "how it was built", dir = "issues/completed", depth = 1 },
    { title = "each piece",     dir = "src",              depth = 1, only = "%.info%.md$" },
    -- The source itself, highlighted. The companion files say what each piece
    -- does; this is for the moment somebody wants to see how, without leaving
    -- the site to go and find a checkout.
    { title = "the source",     dir = "src",              depth = 1, kind = "source" },
    { title = "the edges",      dir = "input",            depth = 2 },
    { title = "the edges",      dir = "output",           depth = 1 },
    { title = "the edges",      dir = "desire",           depth = 1 },
    { title = "the edges",      dir = "faith",            depth = 1 },
    { title = "the edges",      dir = "strategems",       depth = 1 },
    --[[
    The scripts at the project root. They are the project's front doors -- build
    it, run a phase demo, share a record log, make this site, mend the links --
    and each carries a header explaining itself to somebody who has never opened
    it, which makes them documents as much as programs.
    ]]
    { title = "the front doors", files = {
        "build", "run-phase-demo", "share-engraving", "build-docs", "mend-links"
      }, kind = "source" },
}

-- {{{ local function page_name_for
local function page_name_for(relative)
    -- One flat directory of pages, named after the path they came from. Flat
    -- because every page links to every other and a flat directory means one
    -- relative path rule instead of a calculation per pair.
    local flat = relative:gsub("/", "-"):gsub("%.md$", ""):gsub("%.", "-")

    return flat .. ".html"
end
-- }}}

-- {{{ local function title_for
local function title_for(relative, text)
    -- The first heading if there is one, because a document's own first line is
    -- what it calls itself. The filename otherwise, which is what a file with no
    -- heading -- like the vision, or the goodbye -- is called.
    local heading = text:match("^#%s+([^\n]+)")

    if heading == nil then
        heading = text:match("\n#%s+([^\n]+)")
    end

    if heading ~= nil then
        return (heading:gsub("%s+$", ""))
    end

    local base = relative:match("([^/]+)$") or relative

    return (base:gsub("%.md$", ""))
end
-- }}}

-- ---------------------------------------------------------------------------
-- Gathering
-- ---------------------------------------------------------------------------

local pages = {}          -- relative path -> { name, title, text, section }
local by_page_name = {}   -- page name -> relative path
local order = {}          -- section title -> list of relative paths
local section_order = {}

-- {{{ local function gather
local function gather()
    for _, section in ipairs(SECTIONS) do
        local pattern = "-name '*.md'"

        if section.kind == "source" then
            pattern = "\\( -name '*.c' -o -name '*.h' -o -name '*.lua' " ..
                      "-o -name '*.js' -o -name '*.html' \\)"
        end

        local found = {}

        if section.files ~= nil then
            for _, name in ipairs(section.files) do
                found[#found + 1] = DIR .. "/" .. name
            end
        else
            found = shell_lines(
                string.format("find '%s/%s' -maxdepth %d -type f %s 2>/dev/null | sort",
                              DIR, section.dir, section.depth, pattern))
        end

        -- The edge directories hold files with no extension at all -- the
        -- goodbye, the vision, what to start with. They are documents too.
        -- The edge directories hold files with no extension at all -- the
        -- goodbye, the vision, what to start with. They are documents too.
        if section.kind ~= "source" and section.files == nil then
            local plain = shell_lines(
                string.format("find '%s/%s' -maxdepth %d -type f ! -name '*.*' 2>/dev/null | sort",
                              DIR, section.dir, section.depth))

            for _, path in ipairs(plain) do
                found[#found + 1] = path
            end
        end

        for _, path in ipairs(found) do
            local relative = path:sub(#DIR + 2)

            if section.only == nil or relative:match(section.only) then
                -- issues/ is scanned at depth 1 so completed/ does not appear
                -- twice, but find still descends; skip anything already taken.
                if pages[relative] == nil then
                    local text = read_file(path)

                    if text ~= nil then
                        local name = page_name_for(relative)

                        pages[relative] = {
                            name = name,
                            title = (section.kind == "source")
                                    and (relative:match("([^/]+)$") or relative)
                                    or title_for(relative, text),
                            text = text,
                            kind = section.kind,
                            section = section.title,
                            relative = relative
                        }
                        by_page_name[name] = relative

                        if order[section.title] == nil then
                            order[section.title] = {}
                            section_order[#section_order + 1] = section.title
                        end

                        local list = order[section.title]
                        list[#list + 1] = relative
                    end
                end
            end
        end
    end
end
-- }}}

-- ---------------------------------------------------------------------------
-- Markdown, enough of it
-- ---------------------------------------------------------------------------

-- {{{ local function escape
local function escape(text)
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

--[[
Syntax highlighting, inline, for the three languages this project writes in.

INLINE AND NOT FETCHED. A page that reaches out to load a highlighter is a page
that breaks when the network does, and the whole point of the artifact is that it
is a directory you can open.
]]
local C_KEYWORDS = {
    ["if"]=1,["else"]=1,["for"]=1,["while"]=1,["do"]=1,["return"]=1,["struct"]=1,
    ["static"]=1,["const"]=1,["void"]=1,["int"]=1,["char"]=1,["unsigned"]=1,
    ["uint8_t"]=1,["uint16_t"]=1,["uint32_t"]=1,["uint64_t"]=1,["int8_t"]=1,
    ["int32_t"]=1,["int64_t"]=1,["size_t"]=1,["switch"]=1,["case"]=1,["break"]=1,
    ["continue"]=1,["typedef"]=1,["sizeof"]=1,["goto"]=1,["enum"]=1,["union"]=1,
    ["local"]=1,["function"]=1,["end"]=1,["then"]=1,["nil"]=1,["true"]=1,
    ["false"]=1,["and"]=1,["or"]=1,["not"]=1,["elseif"]=1,["repeat"]=1,
    ["until"]=1,["in"]=1,["fi"]=1,["esac"]=1,["echo"]=1,["exit"]=1,["wcoord"]=1,
    ["wangle"]=1
}

-- {{{ local function highlight
local function highlight(code)
    local out = {}
    local i = 1
    local n = #code

    while i <= n do
        local rest = code:sub(i)

        -- A comment, in any of the three languages.
        local comment = rest:match("^/%*.-%*/") or rest:match("^//[^\n]*")
                        or rest:match("^%-%-[^\n]*") or rest:match("^#[^\n]*")

        if comment ~= nil then
            out[#out + 1] = '<span class="c">' .. escape(comment) .. "</span>"
            i = i + #comment
        else
            local text = rest:match('^"[^"\n]*"') or rest:match("^'[^'\n]*'")

            if text ~= nil then
                out[#out + 1] = '<span class="s">' .. escape(text) .. "</span>"
                i = i + #text
            else
                local word = rest:match("^[%a_][%w_]*")

                if word ~= nil then
                    if C_KEYWORDS[word] then
                        out[#out + 1] = '<span class="k">' .. word .. "</span>"
                    else
                        out[#out + 1] = escape(word)
                    end
                    i = i + #word
                else
                    local number = rest:match("^%d[%w%.]*")

                    if number ~= nil then
                        out[#out + 1] = '<span class="n">' .. escape(number) .. "</span>"
                        i = i + #number
                    else
                        out[#out + 1] = escape(code:sub(i, i))
                        i = i + 1
                    end
                end
            end
        end
    end

    return table.concat(out)
end
-- }}}

-- What could not be resolved, collected rather than printed as it happens, so
-- the report is one list somebody can work through.
local unresolved = {}
local linked_to = {}

-- {{{ local function note_unresolved
local function note_unresolved(from, what)
    unresolved[#unresolved + 1] = { from = from, what = what }
end
-- }}}

-- {{{ local function resolve_relative
local function resolve_relative(from_relative, target)
    -- A link written as a relative path in the source tree, turned into the flat
    -- page name. The source's own directory is where "../" counts from.
    local base = from_relative:match("^(.*)/[^/]*$") or ""
    local parts = {}

    for piece in base:gmatch("[^/]+") do
        parts[#parts + 1] = piece
    end

    for piece in target:gmatch("[^/]+") do
        if piece == ".." then
            parts[#parts] = nil
        elseif piece ~= "." then
            parts[#parts + 1] = piece
        end
    end

    return table.concat(parts, "/")
end
-- }}}

local issue_pages = {}    -- "901" -> page name
local source_pages = {}   -- "082-sprite" -> its companion page
local file_pages = {}     -- "082-sprite.c" -> its source page

-- {{{ local function index_shortcuts
local function index_shortcuts()
    for relative, page in pairs(pages) do
        local number = relative:match("issues/[^/]*/?(%d+)%-")

        if number ~= nil then
            issue_pages[number] = page.name
        end

        local companion = relative:match("src/([%w%-]+)%.info%.md$")

        if companion ~= nil then
            source_pages[companion] = { page = page.name, relative = relative }
        end

        local file = relative:match("src/([%w%-%.]+)$")

        if file ~= nil and page.kind == "source" then
            file_pages[file] = { page = page.name, relative = relative }
        end

        -- The root scripts, by their bare names, so "./build-docs" written
        -- anywhere in the prose becomes a link to the script itself.
        if page.kind == "source" and relative:match("^[%w%-]+$") then
            file_pages[relative] = { page = page.name, relative = relative }
        end
    end
end
-- }}}

-- {{{ local function anchor_for
local function anchor_for(heading)
    -- Open questions are numbered, and the numbers are how everything else in
    -- the project refers to them, so they get anchors that match.
    local number = heading:match("^(%d+%.%d+)")

    if number ~= nil then
        return "q-" .. number:gsub("%.", "-")
    end

    return nil
end
-- }}}

--[[
Inline conversion, in a fixed order that matters:

    code spans are lifted out first, so nothing below touches their contents --
      an issue number inside `some_code` is not a reference;
    then explicit links, which are what the author actually wrote;
    then emphasis;
    then AUTOMATIC links, which are the guesses, and which must never be made
      inside something that is already a link.
]]
-- {{{ local function inline
local function inline(text, from_relative)
    local held = {}

    --[[
    Code spans, held aside so nothing below rewrites their contents -- an issue
    number inside `some_code` is not a reference to an issue.

    WITH ONE EXCEPTION, and it is the one that carries most of the site's
    crossing: a code span whose whole content is a module's name IS a reference.
    That is how every document in this project writes one. Treating it as opaque
    left a hundred mentions of `082-sprite` as dead ends.
    ]]
    text = text:gsub("`([^`]*)`", function(code)
        local found = source_pages[code] or file_pages[code]
                      or file_pages[code .. ".c"] or file_pages[code .. ".lua"]

        if found ~= nil then
            linked_to[found.relative] = true
            held[#held + 1] = '<a href="' .. found.page .. '"><code>'
                              .. escape(code) .. "</code></a>"
        else
            held[#held + 1] = "<code>" .. escape(code) .. "</code>"
        end

        return "\1" .. #held .. "\2"
    end)

    text = escape(text)

    -- Explicit links.
    text = text:gsub("%[([^%]]*)%]%(([^%)]*)%)", function(label, target)
        local href

        if target:match("^https?://") then
            href = target
        elseif target:match("^#") then
            href = target
        else
            local anchor = ""
            local path = target

            local hash = target:find("#", 1, true)
            if hash ~= nil then
                path = target:sub(1, hash - 1)
                anchor = target:sub(hash)
            end

            local resolved = resolve_relative(from_relative, path)
            local page = pages[resolved]

            if page ~= nil then
                href = page.name .. anchor
                linked_to[resolved] = true
            else
                note_unresolved(from_relative, "link to " .. target)
                href = nil
            end
        end

        if href == nil then
            -- Marked rather than dropped, so a dead link is visible on the page
            -- as well as in the report. A link that quietly becomes plain text
            -- is a link nobody ever fixes.
            held[#held + 1] = '<span class="dead" title="this went nowhere">'
                              .. label .. "</span>"
        else
            held[#held + 1] = '<a href="' .. href .. '">' .. label .. "</a>"
        end

        return "\1" .. #held .. "\2"
    end)

    text = text:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
    text = text:gsub("%*([^%*\n]+)%*", "<em>%1</em>")

    -- Automatic links. Guesses, made only on text that survived everything
    -- above -- so never inside a code span and never inside a link.
    text = text:gsub("(issues?%s+)(%d%d%d+)", function(word, number)
        local page = issue_pages[number]

        if page == nil then
            return word .. number
        end

        for r, p in pairs(pages) do
            if p.name == page then linked_to[r] = true end
        end

        return word .. '<a href="' .. page .. '">' .. number .. "</a>"
    end)

    --[[
    A module named in prose becomes a link to what it is for.

    This is where most of the site's crossing comes from: the design refers to
    modules constantly, the companion files refer to each other constantly, and
    every one of those mentions was previously a dead end that a reader had to
    resolve by going and finding a checkout.

    A bare name goes to the companion -- what it is for -- rather than to the
    source, because that is nearly always the question. A name with an extension
    on it goes to the file.
    ]]
    text = text:gsub("%f[%w](%d%d%d%-[%a][%w%-]*%.%a+)%f[%W]", function(named)
        local found = file_pages[named]

        if found == nil then
            return named
        end

        linked_to[found.relative] = true

        return '<a href="' .. found.page .. '">' .. named .. "</a>"
    end)

    text = text:gsub("%f[%w](%d%d%d%-[%a][%w%-]*)%f[%W]", function(named)
        local found = source_pages[named] or file_pages[named .. ".c"]
                      or file_pages[named .. ".lua"]

        if found == nil then
            return named
        end

        linked_to[found.relative] = true

        return '<a href="' .. found.page .. '">' .. named .. "</a>"
    end)

    text = text:gsub("(open question%s+)(%d+%.%d+)", function(word, number)
        local target = page_name_for("docs/016-open-questions.md")

        if by_page_name[target] == nil then
            return word .. number
        end

        linked_to["docs/016-open-questions.md"] = true

        return word .. '<a href="' .. target .. "#q-"
               .. number:gsub("%.", "-") .. '">' .. number .. "</a>"
    end)

    -- Put the held pieces back.
    text = text:gsub("\1(%d+)\2", function(which)
        return held[tonumber(which)]
    end)

    return text
end
-- }}}

-- {{{ local function convert
local function convert(page)
    local out = {}
    local lines = {}

    --[[
    A companion gets a line pointing at the code it describes, and the code gets
    one pointing back.

    Added by the tool rather than typed into every companion file, because a
    hundred and forty hand-written cross-references are a hundred and forty
    chances to write the wrong one -- and because the relationship is mechanical:
    a companion is named after its file.
    ]]
    local sisters = ""

    if page.relative:match("%.info%.md$") then
        local stem = page.relative:gsub("%.info%.md$", "")
        local links = {}

        for _, suffix in ipairs({ ".h", ".c", ".lua", ".js", ".html" }) do
            local sister = pages[stem .. suffix]

            if sister ~= nil then
                links[#links + 1] = '<a href="' .. sister.name .. '">'
                                    .. escape(sister.title) .. "</a>"
                linked_to[stem .. suffix] = true
            end
        end

        --[[
        And the test, and the program, found by NAME rather than by index.

        The index is the reading order and the name is the subject, so
        023-blocks, 024-test-blocks and any 0NN-blocks-main belong together
        while sitting at three different places in the sequence. Matching on the
        name is what notices that.
        ]]
        local subject = stem:match("^src/%d+%-(.+)$")

        if subject ~= nil then
            -- A dash is a quantifier in a Lua pattern, so a module called
            -- "fixed-point" matched nothing until this line existed. The symptom
            -- was two orphaned files and no error anywhere.
            subject = subject:gsub("%-", "%%-")
            for relative, other in pairs(pages) do
                if other.kind == "source" then
                    local base = relative:match("([^/]+)$")
                    local is_test = base:match("^%d+%-test%-" .. subject .. "%.c$")
                    local is_main = base:match("^%d+%-" .. subject .. "%-main%.c$")

                    if is_test ~= nil or is_main ~= nil then
                        links[#links + 1] = '<a href="' .. other.name .. '">'
                                            .. escape(other.title) .. "</a>"
                        linked_to[relative] = true
                    end
                end
            end
        end

        if #links > 0 then
            sisters = "<p>The code: " .. table.concat(links, " &middot; ") .. "</p>"
        end
    end

    if page.kind == "source" then
        -- No Markdown here. The whole file, highlighted, and a line at the top
        -- pointing at what it is for -- because reading source without its
        -- companion is reading how without why.
        local companion = page.relative:gsub("%.%w+$", ".info.md")
        local pointer = ""

        if pages[companion] ~= nil then
            pointer = '<p>What it is for, and why: <a href="'
                      .. pages[companion].name .. '">'
                      .. escape(pages[companion].title) .. "</a>.</p>"
            linked_to[companion] = true
        end

        return "<h1>" .. escape(page.title) .. "</h1>" .. pointer
               .. '<pre class="code"><code>' .. highlight(page.text)
               .. "</code></pre>"
    end

    for line in (page.text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end

    local i = 1
    local n = #lines

    while i <= n do
        local line = lines[i]

        -- A fenced code block.
        local fence, language = line:match("^(```+)%s*(%w*)")

        if fence ~= nil then
            local body = {}
            i = i + 1

            while i <= n and not lines[i]:match("^```") do
                body[#body + 1] = lines[i]
                i = i + 1
            end
            i = i + 1

            out[#out + 1] = '<pre class="code"><code>'
                            .. highlight(table.concat(body, "\n"))
                            .. "</code></pre>"
            if language ~= "" then
                -- Recorded but not used for anything yet; the highlighter reads
                -- all three languages at once because their comment and string
                -- shapes do not collide.
            end

        elseif line:match("^#+%s") then
            local hashes, heading = line:match("^(#+)%s+(.*)$")
            local level = #hashes
            local anchor = anchor_for(heading)

            out[#out + 1] = string.format("<h%d%s>%s</h%d>", level,
                            anchor and (' id="' .. anchor .. '"') or "",
                            inline(heading, page.relative), level)
            i = i + 1

        elseif line:match("^|") then
            -- A table. Rows until something is not a row.
            local rows = {}

            while i <= n and lines[i]:match("^|") do
                rows[#rows + 1] = lines[i]
                i = i + 1
            end

            local html = { "<table>" }

            for row_number, row in ipairs(rows) do
                -- The second row of a Markdown table is the alignment rule, and
                -- it is not data.
                if not row:match("^|[%s%-:|]+|?%s*$") then
                    local cells = {}

                    for cell in row:gmatch("|([^|]*)") do
                        cells[#cells + 1] = cell
                    end

                    -- The trailing empty piece after the last pipe.
                    if #cells > 0 and cells[#cells]:match("^%s*$") then
                        cells[#cells] = nil
                    end

                    local tag = (row_number == 1) and "th" or "td"

                    html[#html + 1] = "<tr>"
                    for _, cell in ipairs(cells) do
                        html[#html + 1] = "<" .. tag .. ">"
                                          .. inline(cell:gsub("^%s+", ""):gsub("%s+$", ""),
                                                    page.relative)
                                          .. "</" .. tag .. ">"
                    end
                    html[#html + 1] = "</tr>"
                end
            end

            html[#html + 1] = "</table>"
            out[#out + 1] = table.concat(html)

        elseif line:match("^%s*[%-%*]%s") or line:match("^%s*%d+%.%s") then
            local ordered = line:match("^%s*%d+%.%s") ~= nil
            local items = {}

            while i <= n and (lines[i]:match("^%s*[%-%*]%s") or lines[i]:match("^%s*%d+%.%s")
                              or (lines[i]:match("^%s%s+%S") and #items > 0)) do
                local item = lines[i]:match("^%s*[%-%*]%s+(.*)$")
                             or lines[i]:match("^%s*%d+%.%s+(.*)$")

                if item ~= nil then
                    items[#items + 1] = item
                elseif #items > 0 then
                    -- A wrapped line belongs to the item above it.
                    items[#items] = items[#items] .. " " .. lines[i]:gsub("^%s+", "")
                end

                i = i + 1
            end

            local tag = ordered and "ol" or "ul"
            local html = { "<" .. tag .. ">" }

            for _, item in ipairs(items) do
                html[#html + 1] = "<li>" .. inline(item, page.relative) .. "</li>"
            end

            html[#html + 1] = "</" .. tag .. ">"
            out[#out + 1] = table.concat(html)

        elseif line:match("^>%s?") then
            local body = {}

            while i <= n and lines[i]:match("^>%s?") do
                body[#body + 1] = lines[i]:gsub("^>%s?", "")
                i = i + 1
            end

            out[#out + 1] = "<blockquote>"
                            .. inline(table.concat(body, " "), page.relative)
                            .. "</blockquote>"

        elseif line:match("^%-%-%-+%s*$") then
            out[#out + 1] = "<hr>"
            i = i + 1

        elseif line:match("^%s*$") then
            i = i + 1

        else
            -- A paragraph: lines until a blank one or something structural.
            local body = {}

            while i <= n and not lines[i]:match("^%s*$")
                  and not lines[i]:match("^#+%s") and not lines[i]:match("^|")
                  and not lines[i]:match("^```") and not lines[i]:match("^>")
                  and not lines[i]:match("^%s*[%-%*]%s")
                  and not lines[i]:match("^%-%-%-+%s*$") do
                body[#body + 1] = lines[i]
                i = i + 1
            end

            if #body > 0 then
                out[#out + 1] = "<p>" .. inline(table.concat(body, " "), page.relative)
                                .. "</p>"
            end
        end
    end

    if sisters ~= "" then
        -- After the first heading, where a reader looking for the code is
        -- already looking.
        table.insert(out, 2, sisters)
    end

    return table.concat(out, "\n")
end
-- }}}

-- ---------------------------------------------------------------------------
-- The page around it
-- ---------------------------------------------------------------------------

--[[
The look is the project's own: dark, monospaced, unhurried, the same palette the
browser view uses. A documentation site in somebody else's style is a
documentation site that reads like it belongs to somebody else.
]]
local STYLE = [[
:root {
  --ink: #b8b0a4; --bright: #e4dccc; --dim: #6f685e;
  --ground: #0b0b0d; --panel: #131316; --line: #26262b;
  --link: #c8a878; --warn: #b06a5a;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: var(--ground); color: var(--ink);
  font: 14px/1.65 ui-monospace, "DejaVu Sans Mono", Menlo, monospace; }
#frame { display: flex; min-height: 100vh; }
#contents { width: 22rem; flex: 0 0 22rem; background: var(--panel);
  border-right: 1px solid var(--line); padding: 1.4rem 1rem 4rem;
  overflow-y: auto; height: 100vh; position: sticky; top: 0; }
#contents h1 { font-size: 13px; color: var(--bright); margin: 0 0 1rem; }
#contents h2 { font-size: 11px; color: var(--dim); margin: 1.4rem 0 .3rem;
  text-transform: uppercase; letter-spacing: .09em; font-weight: 400; }
#contents a { display: block; color: var(--ink); text-decoration: none;
  padding: 1px 6px; border-radius: 3px; font-size: 12px;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
#contents a:hover { background: #1c1c21; color: var(--bright); }
#contents a.here { background: #24242b; color: var(--bright); }
main { flex: 1 1 auto; padding: 2.4rem 3rem 8rem; max-width: 62rem; }
h1, h2, h3, h4 { color: var(--bright); font-weight: 600; line-height: 1.3; }
h1 { font-size: 22px; margin: 0 0 1.4rem; }
h2 { font-size: 17px; margin: 2.4rem 0 .7rem; border-top: 1px solid var(--line);
  padding-top: 1.2rem; }
h3 { font-size: 14px; margin: 1.8rem 0 .4rem; }
h4 { font-size: 13px; margin: 1.4rem 0 .3rem; color: var(--ink); }
p { margin: .8rem 0; }
a { color: var(--link); }
a:hover { color: var(--bright); }
.dead { color: var(--warn); text-decoration: underline wavy var(--warn); }
code { background: #17171b; padding: 1px 5px; border-radius: 3px;
  color: var(--bright); font-size: 13px; }
pre.code { background: #17171b; border: 1px solid var(--line); border-radius: 4px;
  padding: 12px 14px; overflow-x: auto; font-size: 13px; line-height: 1.5; }
pre.code code { background: none; padding: 0; }
pre.code .k { color: #b48ead; }
pre.code .s { color: #a3be8c; }
pre.code .c { color: #6f685e; font-style: italic; }
pre.code .n { color: #d08770; }
table { border-collapse: collapse; margin: 1rem 0; width: 100%; font-size: 13px; }
th, td { border: 1px solid var(--line); padding: 6px 10px; text-align: left;
  vertical-align: top; }
th { background: #17171b; color: var(--bright); font-weight: 600; }
blockquote { border-left: 3px solid var(--line); margin: 1rem 0; padding: .2rem 1rem;
  color: var(--dim); font-style: italic; }
hr { border: 0; border-top: 1px solid var(--line); margin: 2rem 0; }
ul, ol { margin: .8rem 0; padding-left: 1.4rem; }
li { margin: .25rem 0; }
strong { color: var(--bright); }
#trail { color: var(--dim); font-size: 11px; margin-bottom: 1.6rem;
  text-transform: uppercase; letter-spacing: .08em; }
@media (max-width: 900px) {
  #frame { flex-direction: column; }
  #contents { width: auto; flex: none; height: auto; position: static; }
  main { padding: 1.4rem; }
}
]]

-- {{{ local function contents_html
local function contents_html(current)
    local out = { '<nav id="contents"><h1>my own custom vtt</h1>' }
    local seen = {}

    for _, title in ipairs(section_order) do
        if not seen[title] then
            seen[title] = true
            out[#out + 1] = "<h2>" .. title .. "</h2>"

            for _, other_title in ipairs(section_order) do
                if other_title == title then
                    for _, relative in ipairs(order[title]) do
                        local page = pages[relative]
                        local class = (relative == current) and ' class="here"' or ""

                        out[#out + 1] = string.format('<a href="%s"%s>%s</a>',
                                        page.name, class, escape(page.title))
                    end
                end
            end
        end
    end

    out[#out + 1] = "</nav>"
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function wrap
local function wrap(page, body)
    return table.concat({
        "<!doctype html>",
        '<html lang="en"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        "<title>" .. escape(page.title) .. "</title>",
        "<style>" .. STYLE .. "</style>",
        "</head><body><div id=\"frame\">",
        contents_html(page.relative),
        "<main>",
        '<div id="trail">' .. escape(page.relative) .. "</div>",
        body,
        "</main></div></body></html>"
    }, "\n")
end
-- }}}

-- ---------------------------------------------------------------------------
-- Doing it
-- ---------------------------------------------------------------------------

gather()
index_shortcuts()

os.execute("mkdir -p '" .. OUT .. "'")

local written = 0

for relative, page in pairs(pages) do
    local body = convert(page)

    if write_file(OUT .. "/" .. page.name, wrap(page, body)) then
        written = written + 1
    end
end

-- The front door is the first document of the design, copied under a name a
-- browser opens by default.
do
    local front = pages["docs/001-what-this-is.md"] or pages["notes/vision"]

    if front ~= nil then
        write_file(OUT .. "/index.html", wrap(front, convert(front)))
    end
end

print(string.format("  wrote %d pages to %s", written, OUT))

-- ---------------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------------

if #unresolved > 0 then
    print("")
    print(string.format("  %d references went nowhere:", #unresolved))

    local shown = 0

    for _, one in ipairs(unresolved) do
        if shown < 40 then
            print(string.format("    %-52s %s", one.from, one.what))
            shown = shown + 1
        end
    end

    if #unresolved > shown then
        print(string.format("    ... and %d more", #unresolved - shown))
    end
else
    print("  every reference resolved")
end

do
    local orphans = {}

    for relative, _ in pairs(pages) do
        if not linked_to[relative] then
            orphans[#orphans + 1] = relative
        end
    end

    table.sort(orphans)

    print("")

    if #orphans == 0 then
        print("  every page is linked to from somewhere")
    else
        print(string.format("  %d pages nothing links to:", #orphans))

        local shown = 0

        for _, relative in ipairs(orphans) do
            if shown < 30 then
                print("    " .. relative)
                shown = shown + 1
            end
        end

        if #orphans > shown then
            print(string.format("    ... and %d more", #orphans - shown))
        end

        print("")
        print("  An orphan is usually a document that stopped being referenced")
        print("  when something was renamed. The contents list still reaches")
        print("  them, so they are readable -- but nothing in the prose points")
        print("  at them, which is how a document stops being read.")
    end
end

print("")
print("  open " .. OUT .. "/index.html")
