#!/usr/bin/env luajit
-- project-timeline-page.lua - Builds the interactive timeline page.
--
-- In plain terms: it takes the page template (project-timeline-page.html,
-- which knows how to draw) and the timeline data (timeline.json, which knows
-- what happened), and pastes the data into the template, producing one HTML
-- file that opens from disk in any browser with no server behind it. In the
-- page, sliders and switches redraw the chart and a button saves it as PNG.
--
-- Usage:
--   project-timeline-page.lua [--in=FILE] [--out=FILE] [--template=FILE] [--dir=PATH] [--help]
--
-- Issue 067.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
local input_path, output_path, template_path, wants_help = nil, nil, nil, false
for _, argument in ipairs(arg) do
    local name, value = argument:match("^%-%-([%w-]+)=(.+)$")
    if argument == "--help" or argument == "-h" then wants_help = true
    elseif name == "dir" then DIR = value
    elseif name == "in" then input_path = value
    elseif name == "out" then output_path = value
    elseif name == "template" then template_path = value
    else
        io.stderr:write("project-timeline-page: unknown argument: " .. argument .. "\n")
        os.exit(2)
    end
end
local ASSET_DIR = DIR .. "/assets/project-timeline"
input_path = input_path or (ASSET_DIR .. "/timeline.json")
output_path = output_path or (ASSET_DIR .. "/project-timeline.html")
template_path = template_path or (DIR .. "/scripts/project-timeline-page.html")
-- }}}

-- {{{ local function read_file(path, what)
local function read_file(path, what)
    local file = io.open(path, "r")
    if not file then
        io.stderr:write("project-timeline-page: no " .. what .. " at " .. path .. "\n")
        os.exit(1)
    end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ local function splice(template, marker, replacement)
-- Plain-text replacement of a marker that must appear exactly once: a
-- template edited so the marker vanished (or doubled) is a broken template,
-- and building a page without its data would hide that.
local function splice(template, marker, replacement)
    local first = template:find(marker, 1, true)
    if not first then error("project-timeline-page: template has no " .. marker) end
    if template:find(marker, first + 1, true) then error("project-timeline-page: template has " .. marker .. " twice") end
    return template:sub(1, first - 1) .. replacement .. template:sub(first + #marker)
end
-- }}}

-- {{{ local function main()
local function main()
    if wants_help then
        print([[
project-timeline-page.lua - paste the timeline data into the interactive page

  --in=FILE        timeline JSON (default assets/project-timeline/timeline.json)
  --out=FILE       page to write (default assets/project-timeline/project-timeline.html)
  --template=FILE  page template (default scripts/project-timeline-page.html)
  --dir=PATH       the delta-version folder
  --help           this text]])
        return
    end
    local template = read_file(template_path, "page template")
    local data = read_file(input_path, "timeline data (run project-timeline-gather.lua first)")
    -- inside a <script> element the only text that can end it early is "</";
    -- "<\/" means the same thing to the JSON parser and cannot close the tag
    local safe_data = data:gsub("</", "<\\/")
    local page = splice(template, "/*TIMELINE_DATA*/", safe_data)
    page = splice(page, "<!-- MADE_BY_LINE -->", "<!-- made by delta-version/scripts/project-timeline-page.lua"
        .. " (issue 067) from " .. input_path:match("[^/]+$") .. " and project-timeline-page.html on "
        .. os.date("%Y-%m-%d") .. ", so the timeline can be redrawn and restyled in a browser -->")
    local file = assert(io.open(output_path, "w"))
    file:write(page)
    file:close()
    print("project-timeline-page: wrote " .. output_path .. " (" .. #page .. " bytes)")
end
-- }}}

main()
