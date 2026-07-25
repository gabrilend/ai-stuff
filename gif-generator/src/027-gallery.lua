-- 027-gallery.lua — the viewing side: documentation and rendered
-- gifs as one linked, dark, glowing set of HTML pages.
--
-- What this is, generally: a generator, like everything here — run
-- it and the whole docs/HTML/ tree is rebuilt from sources; never
-- edit an HTML file by hand, because regeneration is the truth and
-- would erase it. It reads markdown from docs/ and notes/, issue
-- files open and completed, gifs and reports from output/ and the
-- phase demos — and emits pages that all reach each other through
-- one navigation pane. Reading artifacts is its only contact with
-- the pipeline; it could run on a machine that never rendered.
--
-- Design notes worth knowing more than once:
--   * every issue number mentioned anywhere becomes a link to that
--     issue's page (skipping code blocks, where numbers are code).
--   * gif pages reference ../../output and ../demos by relative
--     path rather than copying — the gallery shows what IS, and a
--     stale copy would show what WAS.
--   * the markdown dialect is this project's honest subset:
--     headings, fenced code, lists, paragraphs, bold, emphasis,
--     inline code, links. Nothing here parses the whole world.

local DEFAULT_DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[0] and arg[0]:find("027%-gallery") then
    package.path = (arg[1] or DEFAULT_DIR) .. "/src/?.lua;"
                   .. package.path
end

local gallery = {}

-- {{{ local function escape()
local function escape(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function listing()
-- read-only directory listing, sorted for stable page order
local function listing(path)
    local names = {}
    local ls = io.popen("ls -1 '" .. path .. "'")
    if ls then
        for entry in ls:lines() do names[#names + 1] = entry end
        ls:close()
    end
    table.sort(names)
    return names
end
-- }}}

-- {{{ local function inline_markup()
-- inline spans on one escaped line: code first (protected from the
-- other rules by placeholder), then bold, then emphasis, then links
local function inline_markup(line, linkify)
    local stash = {}
    line = line:gsub("`([^`]+)`", function(code)
        stash[#stash + 1] = "<code>" .. code .. "</code>"
        return "\1" .. #stash .. "\1"
    end)
    if linkify then line = linkify(line) end
    line = line:gsub("%*%*([^*]+)%*%*", "<strong>%1</strong>")
    line = line:gsub("%*([^*%s][^*]-)%*", "<em>%1</em>")
    line = line:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')
    line = line:gsub("\1(%d+)\1", function(n)
        return stash[tonumber(n)]
    end)
    return line
end
-- }}}

-- {{{ function gallery.markdown()
-- the honest subset, line by line: fences, headings, lists,
-- paragraphs. linkify (optional) runs on prose lines only — inside
-- a fence, numbers are code, not mentions.
function gallery.markdown(text, linkify)
    local out = {}
    local in_fence, in_list, para = false, false, {}
    -- {{{ local function close_para()
    local function close_para()
        if #para > 0 then
            out[#out + 1] = "<p>" .. table.concat(para, "\n") .. "</p>"
            para = {}
        end
    end
    -- }}}
    -- {{{ local function close_list()
    local function close_list()
        if in_list then
            out[#out + 1] = "</ul>"
            in_list = false
        end
    end
    -- }}}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if in_fence then
            if line:match("^```") then
                out[#out + 1] = "</code></pre>"
                in_fence = false
            else
                out[#out + 1] = escape(line)
            end
        elseif line:match("^```") then
            close_para()
            close_list()
            out[#out + 1] = '<pre><code>'
            in_fence = true
        elseif line:match("^#+%s") then
            close_para()
            close_list()
            local hashes, title = line:match("^(#+)%s+(.*)$")
            local n = math.min(#hashes, 4)
            out[#out + 1] = "<h" .. n .. ">"
                            .. inline_markup(escape(title), linkify)
                            .. "</h" .. n .. ">"
        elseif line:match("^%s*[-*]%s+") then
            close_para()
            if not in_list then
                out[#out + 1] = "<ul>"
                in_list = true
            end
            local item = line:match("^%s*[-*]%s+(.*)$")
            out[#out + 1] = "<li>"
                            .. inline_markup(escape(item), linkify)
                            .. "</li>"
        elseif line:match("^%s*$") then
            close_para()
            close_list()
        else
            para[#para + 1] = inline_markup(escape(line), linkify)
        end
    end
    close_para()
    close_list()
    return table.concat(out, "\n")
end
-- }}}

local STYLE = [[
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; background: #050505; color: #d8d2c8;
       font: 15px/1.55 Georgia, 'Times New Roman', serif; }
a { color: #a273ff; text-decoration: none; }
a:hover { color: #c9a8ff; text-shadow: 0 0 8px #7a4dff66; }
nav { position: fixed; top: 0; left: 0; bottom: 0; width: 230px;
      overflow-y: auto; background: #0a0a0a; padding: 18px 16px;
      border-right: 1px solid #221c14; font-size: 13px; }
nav h2 { font-size: 11px; letter-spacing: 0.18em;
         text-transform: uppercase; color: #7a6a50; margin: 18px 0 6px; }
nav a { display: block; padding: 2px 0; color: #b8ae9c;
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
nav a:hover { color: #ffb15e; }
main { margin-left: 230px; padding: 34px 44px; max-width: 860px; }
h1, h2, h3, h4 { color: #ffb15e; font-weight: normal;
                 text-shadow: 0 0 18px #ff831f33; }
h1 { font-size: 26px; border-bottom: 1px solid #2a2118;
     padding-bottom: 10px; }
pre { background: #0d0c0a; border: 1px solid #221c14; padding: 12px;
      overflow-x: auto; border-radius: 4px; }
code { font: 13px/1.5 'DejaVu Sans Mono', monospace; color: #9fd8c0; }
figure { margin: 0 0 34px; }
figure img { max-width: 100%; image-rendering: auto; display: block;
             border: 1px solid #221c14; border-radius: 4px;
             background: black; filter: brightness(var(--glow, 1)); }
figcaption { font-size: 13px; color: #8f8674; margin-top: 8px; }
.meter { height: 4px; background: #1b1710; border-radius: 2px;
         margin-top: 6px; overflow: hidden; }
.meter div { height: 100%;
             background: linear-gradient(90deg, #ff831f, #a273ff); }
.glowbox { margin: 10px 0 26px; font-size: 13px; color: #8f8674; }
.grid { display: grid; grid-template-columns: repeat(auto-fill,
        minmax(280px, 1fr)); gap: 26px; }
]]

-- {{{ local function nav_html()
local function nav_html(pages)
    local groups, order = {}, {}
    for _, p in ipairs(pages) do
        if not groups[p.group] then
            groups[p.group] = {}
            order[#order + 1] = p.group
        end
        local g = groups[p.group]
        g[#g + 1] = '<a href="' .. p.file .. '">' .. escape(p.title)
                    .. "</a>"
    end
    local parts = { '<nav><h2>gif-generator</h2>' }
    for _, name in ipairs(order) do
        parts[#parts + 1] = "<h2>" .. escape(name) .. "</h2>"
        parts[#parts + 1] = table.concat(groups[name], "\n")
    end
    parts[#parts + 1] = "</nav>"
    return table.concat(parts, "\n")
end
-- }}}

-- {{{ local function page_html()
local function page_html(title, nav, body)
    return "<!doctype html>\n<html><head><meta charset='utf-8'>"
           .. "<title>" .. escape(title) .. "</title>"
           .. '<link rel="stylesheet" href="style.css">'
           .. "</head><body>\n" .. nav
           .. "\n<main>\n" .. body .. "\n</main></body></html>\n"
end
-- }}}

-- {{{ local function report_facts()
-- a report file's data lines, back as a table
local function report_facts(path)
    local text = slurp(path)
    if not text then return nil end
    local facts = {}
    for k, v in text:gmatch("([%w_]+):%s*([^\n]+)") do
        facts[k] = v
    end
    return facts
end
-- }}}

-- {{{ function gallery.build()
-- The whole tree, rebuilt: collect pages, build the shared nav,
-- write every page plus the gallery index and the stylesheet.
function gallery.build(dir)
    local pages = {}
    -- {{{ local function add_page()
    local function add_page(group, file, title, source, kind)
        pages[#pages + 1] = { group = group, file = file,
                              title = title, source = source,
                              kind = kind }
    end
    -- }}}

    add_page("gallery", "index.html", "the moving pictures")

    for _, entry in ipairs(listing(dir .. "/docs")) do
        local name = entry:match("^(.+)%.md$")
        if name then
            add_page("docs", "docs-" .. name .. ".html", name,
                     dir .. "/docs/" .. entry)
        end
    end
    add_page("notes", "notes-vision.html", "vision",
             dir .. "/notes/vision", "plain")
    for _, entry in ipairs(listing(dir .. "/issues")) do
        local name = entry:match("^(.+)%.md$")
        if name then
            add_page("issues, open", "issue-" .. name .. ".html",
                     name, dir .. "/issues/" .. entry)
        end
    end
    for _, entry in ipairs(listing(dir .. "/issues/completed")) do
        local name = entry:match("^(.+)%.md$")
        if name then
            add_page("issues, completed", "issue-" .. name .. ".html",
                     name, dir .. "/issues/completed/" .. entry)
        end
    end

    -- issue numbers → their pages, for linkifying mentions
    local issue_pages = {}
    for _, p in ipairs(pages) do
        local num = p.title:match("^(%d%d%d%a?)%-")
        if num then issue_pages[num] = p.file end
    end
    -- {{{ local function linkify()
    -- standalone issue numbers in prose become links; the frontier
    -- patterns keep 105 in "1050" or "x105" unlinked
    local function linkify(line)
        return (line:gsub("%f[%w](%d%d%d%a?)%f[%W]", function(num)
            local target = issue_pages[num]
            if target then
                return '<a href="' .. target .. '">' .. num .. "</a>"
            end
            return num
        end))
    end
    -- }}}

    local nav = nav_html(pages)
    local out_dir = dir .. "/docs/HTML"

    -- {{{ local function write_file()
    -- docs/HTML ships with the repository (executing directory
    -- commands from inside programs is banned in this house) — if
    -- it is gone, say whose job it is to exist, and stop
    local function write_file(name, text)
        local f, err = io.open(out_dir .. "/" .. name, "w")
        if not f then
            error("gallery: cannot write into " .. out_dir .. " ("
                  .. tostring(err) .. ") — that directory ships with "
                  .. "the repository; restore it rather than working "
                  .. "around it")
        end
        f:write(text)
        f:close()
    end
    -- }}}

    write_file("style.css", STYLE)

    local built = 0
    for _, p in ipairs(pages) do
        if p.source then
            local text = slurp(p.source)
            if text then
                local body
                if p.kind == "plain" then
                    body = "<h1>" .. escape(p.title) .. "</h1><pre><code>"
                           .. escape(text) .. "</code></pre>"
                else
                    body = gallery.markdown(text, linkify)
                end
                write_file(p.file, page_html(p.title, nav, body))
                built = built + 1
            end
        end
    end

    -- the gallery itself: output/ first, then the phase demos
    local figures = {}
    -- {{{ local function add_figure()
    local function add_figure(src, caption, facts)
        local cap = escape(caption)
        if facts then
            cap = cap .. " — " .. facts.frames .. " frames, "
                  .. facts.bytes .. " bytes, peak "
                  .. facts.peak_particles .. " particles"
        end
        local meter = ""
        if facts and facts.palette_seats_lit then
            local pct = math.floor(tonumber(facts.palette_seats_lit)
                                   / 256 * 100)
            meter = '<div class="meter" title="palette seats lit: '
                    .. facts.palette_seats_lit .. ' of 256">'
                    .. '<div style="width:' .. pct .. '%"></div></div>'
        end
        figures[#figures + 1] = "<figure><img src=\"" .. src
            .. "\" loading=\"lazy\"><figcaption>" .. cap
            .. "</figcaption>" .. meter .. "</figure>"
    end
    -- }}}
    for _, entry in ipairs(listing(dir .. "/output")) do
        local name = entry:match("^(.+)%.gif$")
        if name then
            add_figure("../../output/" .. entry, name,
                       report_facts(dir .. "/output/" .. name
                                    .. ".report"))
        end
    end
    for _, phase in ipairs(listing(dir .. "/issues/completed/demos")) do
        local demo_dir = dir .. "/issues/completed/demos/" .. phase
        for _, entry in ipairs(listing(demo_dir)) do
            if entry:match("%.gif$") then
                add_figure("../../issues/completed/demos/" .. phase
                           .. "/" .. entry,
                           phase .. " / " .. entry:gsub("%.gif$", ""))
            end
        end
    end

    local index_body = "<h1>the moving pictures</h1>"
        .. '<div class="glowbox">glow '
        .. '<input type="range" min="0.4" max="2.2" step="0.05" '
        .. 'value="1" style="vertical-align:middle;width:180px" '
        .. "oninput=\"document.querySelectorAll('img').forEach("
        .. "i=>i.style.setProperty('--glow',this.value))\">'"
        .. " — everything below is a real render; captions are "
        .. "measured facts from the reports beside each file.</div>"
        .. '<div class="grid">' .. table.concat(figures, "\n")
        .. "</div>"
    write_file("index.html", page_html("the moving pictures", nav,
                                       index_body))
    return built + 1, #figures
end
-- }}}

if arg and arg[0] and arg[0]:find("027%-gallery") then
    local dir = arg[1] or DEFAULT_DIR
    local built, gifs = gallery.build(dir)
    print("gallery: " .. built .. " pages, " .. gifs
          .. " moving pictures → " .. dir .. "/docs/HTML/index.html")
end

return gallery
