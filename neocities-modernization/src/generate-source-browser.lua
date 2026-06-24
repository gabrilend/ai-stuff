#!/usr/bin/env luajit

-- {{{ generate-source-browser.lua
-- Issue 10-052: Self-hosted, link-only source browser.
--
-- WHAT IT DOES (for a CEO): GitHub has no "visible only with the link" setting --
-- a repo is either public (anyone can find it) or private (invite-only). This
-- script instead turns the project's own code, issues, and docs into a small
-- website that lives next to the poetry pages already shared by link. Whoever
-- has that link can browse the source; the private monorepo never leaves your
-- machine. It is, in effect, a "git push that builds a webpage instead".
--
-- HOW: it asks git for the list of tracked files (so .gitignore is obeyed),
-- keeps only an ALLOWLIST of code/doc directories (never the private input/ or
-- transcripts), renders each text file as a syntax-highlighted, line-numbered
-- page with a collapsible file-tree sidebar, and writes an index. Images are
-- shown; other binaries are listed but not inlined.
--
-- Usage:
--   luajit src/generate-source-browser.lua [DIR]
-- Output:
--   output/source/index.html              -- the tree + welcome
--   output/source/<path>.html             -- one page per published file
-- }}}

-- {{{ setup_dir_path()
local function setup_dir_path(provided_dir)
    if provided_dir then return provided_dir end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- {{{ parse_args()
local function parse_args(args)
    for _, a in ipairs(args or {}) do
        if not a:match("^%-") then return a end
    end
    return nil
end
-- }}}

local DIR = setup_dir_path(parse_args(arg))
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
-- Issue 10-055: render Markdown (.md, .info.md, and extensionless prose like the
-- vision doc) as formatted HTML instead of flat text.
local markdown = require("markdown")

-- {{{ Configuration
-- ALLOWLIST: only files under these top-level directories are published. This
-- is a denylist's safer cousin -- we can only ever leak what we explicitly name,
-- so the private input/ corpus and llm-transcripts/ cannot slip in by accident.
-- Widen this list deliberately if you want more published.
local INCLUDE_DIRS = {
    src = true, libs = true, scripts = true, issues = true,
    docs = true, notes = true, demos = true,
}
-- Root-level files are published only if their extension is a code/doc type.
local ROOT_FILE_EXTS = {
    lua = true, sh = true, md = true, c = true, h = true,
    json = true, css = true, html = true, txt = true,
}
-- How each extension is treated.
local TEXT_EXTS = {
    lua = "lua", c = "c", h = "c", sh = "sh", md = "md", txt = "text",
    json = "json", css = "css", html = "html", js = "js",
    info = "md",  -- name.info.md tail handled by ext()
}
local IMAGE_EXTS = { png = true, jpg = true, jpeg = true, gif = true, webp = true, svg = true }

-- Token CSS classes (colors live in _style.css, derived from the project's own
-- palette: gold = literal text/poems, blue = structure, teal = annotations).
local TOK = { comment = "c-cm", string = "c-st", keyword = "c-kw", number = "c-nu" }
-- }}}

-- {{{ Per-language syntax (dispatch table by language id)
-- Each entry: line comment prefix, block comment open/close, string delimiters,
-- and a keyword set. A nil field simply disables that feature for the language.
local function set(words)
    local t = {}
    for w in words:gmatch("%S+") do t[w] = true end
    return t
end
local LANGS = {
    lua = {
        line = "--", block_open = "--[[", block_close = "]]",
        strings = { ['"'] = '"', ["'"] = "'" },
        keywords = set("and break do else elseif end false for function goto if in local nil not or repeat return then true until while self"),
    },
    c = {
        line = "//", block_open = "/*", block_close = "*/",
        strings = { ['"'] = '"', ["'"] = "'" },
        keywords = set("auto break case char const continue default do double else enum extern float for goto if inline int long register return short signed sizeof static struct switch typedef union unsigned void volatile while"),
    },
    sh = {
        line = "#", strings = { ['"'] = '"', ["'"] = "'" },
        keywords = set("if then else elif fi for while do done case esac function in return local export readonly echo exit"),
    },
    -- These render with line numbers but no token coloring.
    md = {}, json = {}, css = {}, html = {}, js = {}, text = {},
}
-- }}}

-- {{{ ext() -- extension/language of a path
-- "name.info.md" -> md, "x.lua" -> lua. Returns (ext, language_or_nil).
local function ext(path)
    local e = path:match("%.([%w]+)$") or ""
    e = e:lower()
    return e, TEXT_EXTS[e]
end
-- }}}

-- {{{ ensure_dir()
-- Create a directory tree. Unlike utils.ensure_directory (unquoted mkdir, which
-- breaks on the spaces in e.g. a saved-webpage folder), this single-quotes the
-- path so any name works. io.open below handles spaced paths natively; only the
-- shell mkdir needed the quoting. Single command, not chained.
local function ensure_dir(path)
    os.execute("mkdir -p '" .. path:gsub("'", "'\\''") .. "'")
end
-- }}}

-- {{{ escape_html()
local function escape_html(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
-- }}}

-- {{{ span() -- wrap escaped text in a token-class span
local function span(cls, text)
    return string.format('<span class="%s">%s</span>', cls, text)
end
-- }}}

-- {{{ highlight_line()
-- Tokenize ONE raw line for language `lang`, carrying block-comment state across
-- lines via `state` (a table with .in_block). Returns (html, state). We tokenize
-- the RAW text and escape each token as we emit it, so HTML entities never get
-- matched as code. Imperfect by design (no full grammar) but readable.
local function highlight_line(raw, lang, state)
    if not lang or not lang.keywords and not lang.line and not lang.block_open then
        return escape_html(raw), state
    end
    local out, i, n = {}, 1, #raw
    local function emit(color, text)
        out[#out + 1] = color and span(color, escape_html(text)) or escape_html(text)
    end
    while i <= n do
        if state.in_block then
            -- Inside a block comment: consume until the close delimiter.
            local close = lang.block_close
            local s, e = raw:find(close, i, true)
            if s then
                emit(TOK.comment, raw:sub(i, e)); i = e + 1; state.in_block = false
            else
                emit(TOK.comment, raw:sub(i)); i = n + 1
            end
        else
            local c = raw:sub(i, i)
            if lang.block_open and raw:sub(i, i + #lang.block_open - 1) == lang.block_open then
                state.in_block = true
                -- Re-loop; the block branch above will consume from here.
            elseif lang.line and raw:sub(i, i + #lang.line - 1) == lang.line then
                emit(TOK.comment, raw:sub(i)); i = n + 1
            elseif lang.strings and lang.strings[c] then
                -- Consume a string, honoring backslash escapes.
                local closer, j = lang.strings[c], i + 1
                while j <= n do
                    local cj = raw:sub(j, j)
                    if cj == "\\" then j = j + 2
                    elseif cj == closer then j = j + 1; break
                    else j = j + 1 end
                end
                emit(TOK.string, raw:sub(i, j - 1)); i = j
            elseif c:match("%d") and (i == 1 or not raw:sub(i - 1, i - 1):match("[%w_]")) then
                local j = i
                while j <= n and raw:sub(j, j):match("[%w%.xX]") do j = j + 1 end
                emit(TOK.number, raw:sub(i, j - 1)); i = j
            elseif c:match("[%a_]") then
                local j = i
                while j <= n and raw:sub(j, j):match("[%w_]") do j = j + 1 end
                local word = raw:sub(i, j - 1)
                emit(lang.keywords and lang.keywords[word] and TOK.keyword or nil, word)
                i = j
            else
                emit(nil, c); i = i + 1
            end
        end
    end
    return table.concat(out), state
end
-- }}}

-- {{{ list_published_files()
-- Ask git for tracked files (honors .gitignore), then keep only allowlisted
-- ones. Returns (kept_list, skipped_dir_counts). Read-only git, no chaining.
local function list_published_files()
    local pipe = io.popen(string.format("git -C %q ls-files", DIR))
    if not pipe then error("could not run git ls-files in " .. DIR) end
    local kept, skipped = {}, {}
    for line in pipe:lines() do
        local top = line:match("^([^/]+)/") or line  -- top-level dir, or root file
        local published
        if line:match("/") then
            published = INCLUDE_DIRS[top] == true
        else
            local e = ext(line)
            published = ROOT_FILE_EXTS[e] == true
        end
        if published then
            kept[#kept + 1] = line
        else
            skipped[top] = (skipped[top] or 0) + 1
        end
    end
    pipe:close()
    table.sort(kept)
    return kept, skipped
end
-- }}}

-- {{{ build_tree()
-- Turn the flat file list into a nested tree: node = {dirs={name->node}, files={{name,rel}}}.
local function build_tree(files)
    local root = { dirs = {}, files = {} }
    for _, rel in ipairs(files) do
        local node, acc = root, ""
        local parts = {}
        for p in rel:gmatch("[^/]+") do parts[#parts + 1] = p end
        for idx = 1, #parts - 1 do
            local d = parts[idx]
            node.dirs[d] = node.dirs[d] or { dirs = {}, files = {} }
            node = node.dirs[d]
        end
        node.files[#node.files + 1] = { name = parts[#parts], rel = rel }
    end
    return root
end
-- }}}

-- {{{ sorted_keys()
local function sorted_keys(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = key end
    table.sort(k)
    return k
end
-- }}}

-- {{{ render_sidebar()
-- Render the whole tree as nested <details> (collapsible, needs no JS). Dirs on
-- the path to `current_rel` are opened so the reader sees where they are.
-- link_prefix climbs back to output/source/ from the current page.
local function render_sidebar(node, current_rel, link_prefix, path_set, mirror_set)
    local out = {}
    for _, d in ipairs(sorted_keys(node.dirs)) do
        local open = path_set[d] and " open" or ""
        out[#out + 1] = string.format("<details%s><summary>%s/</summary>", open, escape_html(d))
        out[#out + 1] = render_sidebar(node.dirs[d], current_rel, link_prefix, path_set, mirror_set)
        out[#out + 1] = "</details>"
    end
    local files = node.files
    table.sort(files, function(a, b) return a.name < b.name end)
    for _, f in ipairs(files) do
        local here = (f.rel == current_rel)
        local label = escape_html(f.name)
        if here then
            out[#out + 1] = string.format('<div class="cur">%s</div>', label)
        else
            -- A mirrored saved page (Feature F) links to the page ITSELF (no .html
            -- source-view suffix); every other file links to its rendered page.
            local href = (mirror_set and mirror_set[f.rel])
                and (link_prefix .. f.rel)
                or (link_prefix .. f.rel .. ".html")
            out[#out + 1] = string.format('<a href="%s">%s</a>', href, label)
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ page_shell()
-- One page: a sticky left "table of contents" sidebar + the content pane. The
-- look lives in the shared _style.css (the "Machine Codex" theme); fonts come
-- from Google Fonts with serif/mono fallbacks for offline. %LINKPREFIX% is
-- substituted by the caller with the climb back to output/source/.
local function page_shell(title, sidebar, content)
    return string.format([[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght@0,9..144,500;0,9..144,600;1,9..144,400&family=JetBrains+Mono:ital,wght@0,400;0,500;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="%s_style.css">
</head>
<body>
<div id="wrap">
<nav id="side">
<a class="home" href="%sindex.html"><span class="brand">Machine&#160;Codex</span><span class="tagline">the source, read as a book</span></a>
<a class="site-link" href="%%LINKPREFIX%%../wordcloud.html">&#8617;&#160;back to the poetry site</a>
<div class="tree">%s</div>
<a class="output-link" href="%%LINKPREFIX%%../wordcloud.html#poem-index">output/&#160;&#8594;&#160;every generated page</a>
</nav>
<main id="main">%s</main>
</div>
</body>
</html>]], escape_html(title), "%LINKPREFIX%", "%LINKPREFIX%", sidebar, content)
end
-- }}}

-- {{{ relpath_prefix()
-- "../" repeated to climb from output/source/<rel>.html back to output/source/.
local function relpath_prefix(rel)
    local depth = select(2, rel:gsub("/", "/"))
    return string.rep("../", depth)
end
-- }}}

-- {{{ page_header()
-- The "<dir>name" title + rule shared by every content page. Split so the
-- directory dims and the filename stands out. `meta` is an optional subtitle
-- (e.g. "240 lines"); omit it for rendered prose where a line count is noise.
local function page_header(rel, meta)
    local dir, name = rel:match("^(.*/)([^/]+)$")
    if not name then dir, name = "", rel end
    local meta_html = meta and string.format('<p class="meta">%s</p>', meta) or ""
    return string.format('<h1><span class="dir">%s</span>%s</h1>%s<div class="rule"></div>',
        escape_html(dir), escape_html(name), meta_html)
end
-- }}}

-- {{{ fold_marker_kind()
-- Issue 10-055: the project brackets every function with vimfold markers
-- (`-- {{{ name` ... `-- }}}`, per CLAUDE.md). Those markers ARE the fold
-- boundaries. We only treat a line as a fold marker when the language has a
-- line-comment AND the marker sits in that comment, so a stray { in code can
-- never be mistaken for a fold. Returns "open", "close", or nil.
local function fold_marker_kind(line, lang)
    local cprefix = lang and lang.line
    if not cprefix then return nil end
    local p = "^%s*" .. cprefix:gsub("(%W)", "%%%1") .. "%s*"
    if line:match(p .. "{{{") then return "open" end
    if line:match(p .. "}}}") then return "close" end
    return nil
end
-- }}}

-- {{{ render_text_page()
-- A code/text file: numbered, highlighted lines (gutter line numbers double as
-- #L<n> anchors for deep links). Issue 10-055: vimfold regions become clickable
-- <details> blocks -- mouse-driven folds with no JavaScript, the same mechanism
-- the sidebar uses. Folds default OPEN so the page reads top-to-bottom (and so a
-- deep link to a line inside a fold still resolves) until the reader collapses
-- one. Unbalanced markers are closed defensively so the HTML never breaks.
local function render_text_page(rel, body, lang)
    local raw = {}
    for line in (body .. "\n"):gmatch("(.-)\n") do raw[#raw + 1] = line end

    -- Each line is its own block (a .cl div, or the <summary> for a fold-open
    -- line), so line breaks come from the elements -- not from newline characters
    -- fighting with the block-level fold <details>. white-space:pre on .cl keeps
    -- each line's own indentation. The marker line opens a <details>; its body
    -- lines are the collapsible content; the closing marker line ends it.
    local function cl(gutter, hl) return '<div class="cl">' .. gutter .. hl .. "</div>" end

    local state, parts, depth = { in_block = false }, {}, 0
    for n = 1, #raw do
        local line = raw[n]
        local hl; hl, state = highlight_line(line, lang, state)
        local gutter = string.format('<span class="ln" id="L%d">%d</span>', n, n)
        local kind = fold_marker_kind(line, lang)
        if kind == "open" then
            parts[#parts + 1] = '<details class="fold" open><summary class="cl">'
                .. gutter .. hl .. '</summary>'
            depth = depth + 1
        elseif kind == "close" and depth > 0 then
            parts[#parts + 1] = cl(gutter, hl) .. '</details>'
            depth = depth - 1
        else
            parts[#parts + 1] = cl(gutter, hl)
        end
    end
    while depth > 0 do parts[#parts + 1] = '</details>'; depth = depth - 1 end

    -- A <div>, not a <pre>: the fold regions are <details> (flow content), which
    -- is not valid inside <pre> (phrasing-only). Per-line .cl blocks reproduce the
    -- line layout while letting the folds nest validly.
    return page_header(rel, string.format("%d lines", #raw))
        .. '<div class="code">' .. table.concat(parts, "") .. "</div>"
end
-- }}}

-- {{{ render_markdown_page()
-- Issue 10-055: a Markdown file rendered as formatted HTML (headings, tables,
-- lists, code, links) rather than numbered plain text. Used for .md / .info.md
-- and for extensionless prose (the vision doc). The renderer escapes all text,
-- so untrusted markup cannot inject tags.
local function render_markdown_page(rel, body)
    return page_header(rel) .. '<div class="md">' .. markdown.render(body) .. "</div>"
end
-- }}}

-- {{{ render_image_page()
-- An image file: show it. The original lives at DIR/<rel>; from output/source/
-- <rel>.html that is up (depth+2) directories then <rel>.
local function render_image_page(rel)
    local depth = select(2, rel:gsub("/", "/"))
    local src = string.rep("../", depth + 2) .. rel
    -- Encode spaces etc. but keep the slashes.
    src = src:gsub("[^%w%-%._~/]", function(c) return string.format("%%%02X", string.byte(c)) end)
    local dir, name = rel:match("^(.*/)([^/]+)$")
    if not name then dir, name = "", rel end
    return string.format(
        '<h1><span class="dir">%s</span>%s</h1><div class="rule"></div><img src="%s" alt="%s">',
        escape_html(dir), escape_html(name), src, escape_html(rel))
end
-- }}}

-- {{{ write_style_file()
-- The "Machine Codex" theme: the source browser as an illuminated manuscript of
-- a machine. Deep ink, a warm upper-left glow + grain for atmosphere, a
-- characterful serif (Fraunces) for the human-facing chrome and crisp mono
-- (JetBrains Mono) for the machine's own text. Syntax colors are DERIVED from
-- the project's identity palette: gold = literal text (poems are gold on the
-- main site), blue = structure, teal = the "why" of comments. Written once and
-- linked by every page (small pages, one cohesive source of truth for the look).
local function write_style_file(out_root)
    local css = [[
/* Machine Codex -- source browser theme (Issue 10-052). */
:root{
  --ink:#0b0c10; --ink-2:#13151f; --panel:#0e1018;
  --paper:#e9e4d8; --paper-dim:#9b9484; --paper-faint:#6a6457;
  --gold:#d8b14a; --gold-soft:#c6b257; --blue:#74a0e6; --teal:#5f9c92; --coral:#e08363;
  --rule:#24262f; --rule-soft:#191b22;
}
*{box-sizing:border-box;}
html{scroll-behavior:smooth;}
body{
  margin:0; background:var(--ink); color:var(--paper);
  font-family:'JetBrains Mono',ui-monospace,'Hack',Consolas,monospace;
  font-size:13.5px; line-height:1.62; -webkit-font-smoothing:antialiased;
  background-image:
    radial-gradient(820px 460px at 8% -12%, rgba(216,177,74,.08), transparent 60%),
    radial-gradient(680px 480px at 104% -6%, rgba(95,156,146,.06), transparent 55%);
  background-attachment:fixed;
}
/* fine grain overlay for paper-like depth */
body::after{
  content:""; position:fixed; inset:0; pointer-events:none; z-index:9; opacity:.04;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
}
a{color:var(--blue); text-decoration:none; transition:color .14s ease;}
a:hover{color:var(--gold);}
#wrap{display:flex; align-items:flex-start; min-height:100vh;}

/* ---- sidebar: a book's table of contents ---- */
#side{
  width:308px; min-width:308px; height:100vh; position:sticky; top:0; overflow:auto;
  padding:1.6rem 1.25rem 3rem; border-right:1px solid var(--rule);
  background:linear-gradient(176deg, var(--ink-2), var(--ink) 70%);
  font-size:12.5px; animation:sideIn .55s cubic-bezier(.2,.8,.2,1) both;
}
#side .home{display:block; margin-bottom:1.1rem;}
#side .brand{
  display:block; font-family:'Fraunces',Georgia,serif; font-weight:600; font-size:1.5rem;
  color:var(--gold); letter-spacing:.005em; line-height:1.05;
}
#side .tagline{
  display:block; margin-top:.4rem; font-size:.62rem; letter-spacing:.22em;
  text-transform:uppercase; color:var(--paper-faint);
}
#side .home:hover .brand{color:var(--gold);}
#side .tree{border-top:1px solid var(--rule); padding-top:.9rem;}
#side details{margin:.05rem 0; border-left:1px solid var(--rule-soft); padding-left:.6rem;}
#side summary{
  cursor:pointer; list-style:none; padding:1.5px 0; color:var(--teal);
  font-family:'Fraunces',Georgia,serif; font-style:italic; font-size:.96rem;
}
#side summary::-webkit-details-marker{display:none;}
#side summary::before{content:"\203A\00a0"; color:var(--rule); font-style:normal;}
#side details[open]>summary::before{content:"\02C5\00a0"; color:var(--gold-soft);}
#side summary:hover{color:var(--gold);}
#side a{
  display:block; padding:1.5px 0 1.5px .35rem; color:var(--paper-dim);
  border-left:2px solid transparent; transition:color .12s ease, border-color .12s ease, padding .12s ease;
  white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
}
#side a:hover{color:var(--gold); border-left-color:var(--gold); padding-left:.65rem;}
#side .cur{
  display:block; padding:1.5px .4rem; margin-left:.1rem; color:var(--ink);
  background:linear-gradient(90deg,var(--gold),var(--gold-soft)); border-radius:3px; font-weight:700;
}
#side .cur::before{content:"\25A0\00a0"; opacity:.7;}

/* ---- main content ---- */
#main{flex:1; min-width:0; padding:2.3rem 2.9rem 7rem; overflow-x:auto; animation:mainIn .65s cubic-bezier(.2,.8,.2,1) both;}
#main h1{
  font-family:'JetBrains Mono',monospace; font-weight:700; font-size:1.05rem;
  color:var(--paper); margin:0 0 .15rem; word-break:break-all; letter-spacing:-.01em;
}
#main h1 .dir{color:var(--paper-faint); font-weight:400;}
#main .meta{color:var(--paper-dim); font-size:.74rem; letter-spacing:.12em; text-transform:uppercase; margin:.1rem 0 1rem;}
#main .rule{height:1px; background:linear-gradient(90deg,var(--gold) 0,var(--gold) 64px,var(--rule) 64px,transparent); margin:0 0 1.6rem;}

/* code */
/* a div, not a <pre>, so the fold <details> nest validly. Each line is a .cl
   block that carries white-space:pre to keep its own indentation. */
.code{margin:0; font-size:13px; tab-size:4; line-height:1.6; display:block; overflow-x:auto;}
.cl{white-space:pre; display:block;}
/* an issue number inside a comment, linked to its page (Issue 10-055, Feature D) */
.issue-ref{color:var(--gold-soft); border-bottom:1px dotted var(--gold-soft); font-style:normal;}
.issue-ref:hover{color:var(--gold); border-bottom-color:var(--gold);}
.ln{
  color:var(--rule); user-select:none; display:inline-block;
  min-width:3.4rem; padding-right:1.4rem; text-align:right; font-variant-numeric:tabular-nums;
}
.ln:target{color:var(--gold);}
.c-cm{color:var(--teal); font-style:italic;}
.c-st{color:var(--gold-soft);}
.c-kw{color:var(--blue);}
.c-nu{color:var(--coral);}
img{max-width:100%; height:auto; border:1px solid var(--rule); border-radius:2px;}

/* ---- back-to-site link (Issue 10-055) ---- */
#side .site-link{
  display:block; margin:-.4rem 0 1rem; padding:.2rem 0; color:var(--paper-dim);
  font-family:'Fraunces',Georgia,serif; font-style:italic; font-size:.92rem;
}
#side .site-link:hover{color:var(--gold);}
/* output/ is not a real tree branch (it is git-ignored, ~23k pages); it is a
   single deep link to the live site's poem index, where every page is reachable. */
#side .output-link{
  display:block; margin:.9rem 0 0; padding:.5rem .6rem; color:var(--paper-dim);
  border:1px dashed var(--rule); border-radius:3px; font-size:.82rem; letter-spacing:.02em;
}
#side .output-link:hover{color:var(--gold); border-color:var(--gold-soft);}

/* ---- code folds (Issue 10-055): vimfold regions as no-JS <details> ---- */
/* Inside the code <pre>: the marker line is the clickable summary; its body
   lines collapse under it. Default open so the page reads straight through. */
.fold{display:block;}
.fold>summary{cursor:pointer; list-style:none;}
.fold>summary::-webkit-details-marker{display:none;}
.fold>summary .ln{position:relative;}
/* a small triangle in the gutter margin so it reads as a fold handle */
.fold>summary::before{content:"\25BE"; color:var(--gold-soft); margin-right:.25rem;}
.fold:not([open])>summary::before{content:"\25B8"; color:var(--paper-faint);}
.fold:not([open])>summary{color:var(--paper-dim);}

/* ---- rendered markdown (Issue 10-055) ---- */
.md{max-width:80ch; line-height:1.72;}
.md h1,.md h2,.md h3,.md h4{font-family:'Fraunces',Georgia,serif; color:var(--gold); line-height:1.2; margin:1.7rem 0 .6rem;}
.md h1{font-size:1.9rem;} .md h2{font-size:1.45rem;} .md h3{font-size:1.18rem;} .md h4{font-size:1rem;}
.md p{margin:0 0 1rem;}
.md ul,.md ol{margin:0 0 1rem 1.5rem;}
.md li{margin:.25rem 0;}
.md code{font-family:'JetBrains Mono',monospace; background:var(--ink-2); padding:.1rem .32rem; border-radius:3px; color:var(--gold-soft); font-size:.92em;}
.md pre{background:var(--ink-2); padding:1rem 1.1rem; border-radius:4px; overflow-x:auto; margin:0 0 1rem; border:1px solid var(--rule);}
.md pre code{background:none; padding:0; color:var(--paper); font-size:13px;}
.md blockquote{border-left:3px solid var(--gold-soft); margin:0 0 1rem; padding:.2rem 0 .2rem 1rem; color:var(--paper-dim); font-style:italic;}
.md table{border-collapse:collapse; margin:0 0 1.2rem;}
.md th,.md td{border:1px solid var(--rule); padding:.4rem .85rem; text-align:left; vertical-align:top;}
.md th{background:var(--ink-2); color:var(--gold-soft); font-weight:600;}
.md hr{border:0; border-top:1px solid var(--rule); margin:1.7rem 0;}
.md a{color:var(--blue);} .md a:hover{color:var(--gold);}

/* welcome / index */
.welcome{max-width:62ch;}
.welcome h1{
  font-family:'Fraunces',Georgia,serif; font-weight:600; font-size:2.7rem;
  color:var(--gold); margin:.2rem 0 .2rem; line-height:1.04; letter-spacing:.005em;
}
.welcome .kicker{font-size:.66rem; letter-spacing:.28em; text-transform:uppercase; color:var(--paper-faint); margin:0 0 .4rem;}
.welcome p{font-family:'Fraunces',Georgia,serif; font-size:1.18rem; line-height:1.7; color:var(--paper); margin:0 0 1.1rem;}
.welcome .mono{font-family:'JetBrains Mono',monospace; font-size:.82rem; line-height:1.7; color:var(--paper-dim);}
.welcome .mono b{color:var(--gold-soft); font-weight:500;}
.welcome .div{height:1px; background:linear-gradient(90deg,var(--gold),transparent); margin:1.6rem 0;}

@keyframes sideIn{from{opacity:0; transform:translateX(-14px);} to{opacity:1; transform:none;}}
@keyframes mainIn{from{opacity:0; transform:translateY(16px);} to{opacity:1; transform:none;}}
@media(prefers-reduced-motion:reduce){*{animation:none !important;}}
@media(max-width:760px){
  #wrap{flex-direction:column;}
  #side{width:100%; min-width:0; height:auto; position:static; border-right:0; border-bottom:1px solid var(--rule);}
  #main{padding:1.6rem 1.15rem 4rem;}
  .welcome h1{font-size:2rem;}
}
]]
    return utils.write_file(out_root .. "/_style.css", css)
end
-- }}}

-- {{{ main()
-- {{{ strip_scripts()
-- Issue 10-055 (Feature F): remove every <script> from a mirrored page. Two
-- reasons: the platform is no-JS, and one of these scripts is google-analytics --
-- a static mirror should not phone a tracker. The article's text, CSS, and images
-- carry the content; only interactivity (a JS widget) degrades.
local function strip_scripts(html)
    html = html:gsub("<script.-</script>", "")   -- paired tags (. spans newlines)
    html = html:gsub("<script[^>]*/?>", "")       -- any stray/self-closing tag
    return html
end
-- }}}

-- {{{ copy_raw()
-- Byte-for-byte copy (binary-safe rb/wb), used to place a mirrored page's assets
-- (CSS, images) into the output. Pure Lua I/O on purpose: the project bans shell
-- exec for file targeting, and io handles the spaces in these paths natively.
local function copy_raw(src_abs, dst_abs)
    local src = io.open(src_abs, "rb")
    if not src then return false end
    local data = src:read("*all"); src:close()
    ensure_dir(dst_abs:match("^(.*)/[^/]+$"))
    local dst = io.open(dst_abs, "wb")
    if not dst then return false end
    dst:write(data); dst:close()
    return true
end
-- }}}

-- {{{ find_mirror_pages()
-- A saved webpage is an .html with a sibling "<name>_files/" directory of its
-- assets (how browsers "Save Page As"). Returns two lookups over the published
-- list: mirror_html[rel]=true for each such page, and a list of "<name>_files/"
-- prefixes so their asset files can be recognized and handled as assets (copied)
-- rather than rendered as source.
local function find_mirror_pages(all_files)
    local has_prefix = {}
    for _, rel in ipairs(all_files) do
        local dir = rel:match("^(.*/)[^/]+$")
        if dir then has_prefix[dir] = true end
    end
    local mirror_html, asset_prefixes = {}, {}
    for _, rel in ipairs(all_files) do
        local stem = rel:match("^(.*)%.html$")
        if stem and has_prefix[stem .. "_files/"] then
            mirror_html[rel] = true
            asset_prefixes[#asset_prefixes + 1] = stem .. "_files/"
        end
    end
    local function is_asset(rel)
        for _, p in ipairs(asset_prefixes) do
            if rel:sub(1, #p) == p then return true end
        end
        return false
    end
    return mirror_html, is_asset
end
-- }}}

-- {{{ classify_file()
-- Decide how a published path renders: "md" (formatted markdown), "code"
-- (numbered + highlighted source), "image", or "skip" (a binary -- listed
-- nowhere, so it can never become a dead link). Issue 10-055: extensionless
-- tracked files (e.g. notes/vision) used to fall through to "skip" while the
-- sidebar still linked them -> a guaranteed 404; now an extensionless TEXT file
-- renders as prose and only a genuine binary is skipped. Returns (kind, lang_id).
local function classify_file(rel)
    local e, lang_id = ext(rel)
    if lang_id == "md" or TEXT_EXTS[e] == "md" then
        return "md"
    elseif lang_id or TEXT_EXTS[e] then
        return "code", lang_id
    elseif IMAGE_EXTS[e] then
        return "image"
    elseif e == "" then
        -- No extension: prose unless the bytes say binary (a NUL is the giveaway).
        local body = utils.read_file(DIR .. "/" .. rel)
        if body and not body:find("\0", 1, true) then return "md" end
        return "skip"
    end
    return "skip"
end
-- }}}

-- {{{ build_issue_index()
-- Issue 10-055 (Feature D): map each published issue's NUMBER to its page path,
-- so a comment that mentions "Issue 10-036" can link to it. The number is the
-- filename's leading token (10-036, 9-005b, 002...). The file may live in
-- issues/ or issues/completed/ or a phase subdir, so it is looked up here, never
-- hard-coded.
local function build_issue_index(rels)
    local index = {}
    for _, rel in ipairs(rels) do
        if rel:match("^issues/") and rel:match("%.md$") then
            local base = rel:match("([^/]+)$")
            local num = base:match("^(%d+%-%d+%l?)") or base:match("^(%d+%l?)")
            if num then index[num] = rel end
        end
    end
    return index
end
-- }}}

-- {{{ linkify_issues()
-- Turn "Issue 10-036" mentions in already-rendered (escaped) comment HTML into
-- links to that issue's page. Only the number is linked, and only when it
-- resolves to a published issue -- an unknown number stays plain text, so we
-- never emit a dead link. `prefix` climbs from the current page to output/source/.
local function linkify_issues(html, index, prefix)
    return (html:gsub("(Issues?%s+)(%d+%-?%d*%l?)", function(lead, num)
        local rel = index[num]
        if not rel then return lead .. num end
        return string.format('%s<a class="issue-ref" href="%s%s.html">%s</a>',
            lead, prefix, rel, num)
    end))
end
-- }}}

local function main()
    local all_files, skipped = list_published_files()
    local out_root = DIR .. "/output/source"
    ensure_dir(out_root)
    write_style_file(out_root)

    -- Pass 1 -- classify. Build the renderable list (and therefore the tree) from
    -- ONLY files that will actually get a page, so the table of contents can never
    -- link a page we did not write (the old extensionless-file 404). Genuine
    -- binaries are counted for the report but kept out of the tree entirely.
    -- Feature F: saved webpages (an .html with a sibling _files/ dir) are mirrored
    -- as the real page; their asset files are copied, not rendered as source.
    local mirror_html, is_asset = find_mirror_pages(all_files)
    local renderable, assets, skipped_files = {}, {}, 0
    for _, rel in ipairs(all_files) do
        if mirror_html[rel] then
            renderable[#renderable + 1] = { rel = rel, kind = "mirror" }
        elseif is_asset(rel) then
            assets[#assets + 1] = rel  -- a mirrored page's asset: copied, not in the tree
        else
            local kind, lang_id = classify_file(rel)
            if kind == "skip" then
                skipped_files = skipped_files + 1
            else
                renderable[#renderable + 1] = { rel = rel, kind = kind, lang_id = lang_id }
            end
        end
    end

    local rels = {}
    for _, f in ipairs(renderable) do rels[#rels + 1] = f.rel end
    local tree = build_tree(rels)
    local issue_index = build_issue_index(rels)  -- Feature D: comment -> issue links
    local written, images, write_failed = 0, 0, {}

    -- Pass 2 -- render each renderable file by its kind.
    for _, f in ipairs(renderable) do
        local rel = f.rel

        if f.kind == "mirror" then
            -- Feature F: write the saved page ITSELF (scripts stripped), not a
            -- source view -- clicking it shows the real article, no browser chrome.
            local body = utils.read_file(DIR .. "/" .. rel)
            if body and utils.write_file(out_root .. "/" .. rel, strip_scripts(body)) then
                written = written + 1
            else
                write_failed[#write_failed + 1] = rel
            end
            goto continue
        end

        -- Build the set of directory names on the path to this file, so the
        -- sidebar opens them.
        local path_set = {}
        for p in rel:gmatch("[^/]+") do path_set[p] = true end
        local prefix = relpath_prefix(rel)
        local sidebar = render_sidebar(tree, rel, prefix, path_set, mirror_html)

        local content
        if f.kind == "image" then
            content = render_image_page(rel)
        else
            local body = utils.read_file(DIR .. "/" .. rel)
            if not body then skipped_files = skipped_files + 1; goto continue end
            if f.kind == "md" then
                content = render_markdown_page(rel, body)
            else
                content = render_text_page(rel, body, LANGS[f.lang_id or "text"])
                -- Feature D: comments here mention issues; link them to their pages.
                content = linkify_issues(content, issue_index, prefix)
            end
        end

        local page = page_shell(rel, sidebar, content):gsub("%%LINKPREFIX%%", prefix)
        local out_file = out_root .. "/" .. rel .. ".html"
        ensure_dir(out_file:match("^(.*)/[^/]+$"))
        -- A failed write is a warning we must surface, not swallow -- it usually
        -- means a path with characters io.open/mkdir choke on (spaces, quotes).
        if not utils.write_file(out_file, page) then
            write_failed[#write_failed + 1] = rel
        elseif f.kind == "image" then
            images = images + 1
        else
            written = written + 1
        end
        ::continue::
    end

    -- Feature F: copy each mirrored page's assets verbatim (CSS, images, fonts).
    -- Scripts are skipped on purpose -- the platform is no-JS and one of them is
    -- an analytics tracker a static mirror must never run; the article's text and
    -- styling carry it without them.
    local copied_assets = 0
    for _, rel in ipairs(assets) do
        if not rel:match("%.js$") and copy_raw(DIR .. "/" .. rel, out_root .. "/" .. rel) then
            copied_assets = copied_assets + 1
        end
    end

    -- Index: welcome + the full tree (nothing current, root prefix).
    do
        local sidebar = render_sidebar(tree, nil, "", {}, mirror_html)
        local welcome = string.format([[<div class="welcome">
<p class="kicker">A link-only view of the machine</p>
<h1>The source, read as a book.</h1>
<p>This is the code, the issues, and the documentation that build the poetry
collection &mdash; rendered as a small website so it can be shared by link
without a public repository. The private monorepo never leaves the machine.</p>
<div class="div"></div>
<p class="mono"><b>%d</b> text files and <b>%d</b> images, published from an
allowlist of directories. The private input corpus and the transcripts are
deliberately held back. Pick a file from the table of contents on the left, or
follow any path down through the tree.</p>
</div>]], written, images)
        local page = page_shell("Machine Codex", sidebar, welcome):gsub("%%LINKPREFIX%%", "")
        utils.write_file(out_root .. "/index.html", page)
    end

    -- Report what was published and -- loudly -- what was held back.
    print(string.format("[source-browser] published %d text + %d images to %s",
        written, images, out_root))
    if copied_assets > 0 then
        print(string.format("[source-browser] mirrored saved page(s), copied %d assets (scripts skipped)", copied_assets))
    end
    if skipped_files > 0 then
        print(string.format("[source-browser] skipped %d non-text/non-image files (binaries)", skipped_files))
    end
    if #write_failed > 0 then
        print(string.format("[source-browser] WARNING: %d pages failed to write (odd path characters): %s",
            #write_failed, table.concat(write_failed, ", ")))
    end
    local skip_report = {}
    for dir, count in pairs(skipped) do skip_report[#skip_report + 1] = string.format("%s (%d)", dir, count) end
    table.sort(skip_report)
    if #skip_report > 0 then
        print("[source-browser] NOT published (allowlist held these back): " .. table.concat(skip_report, ", "))
    end
end
-- }}}

main()
