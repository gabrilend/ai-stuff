-- 008-say-goodbye.lua - the last thing the viewer does: write output/goodbye.
--
-- In plain terms: a receipt. Its fresh timestamp proves the viewer reached a
-- clean ending (a crash never says goodbye), and its numbers say what the
-- run did without anyone watching: which file, how many triangles and parts,
-- how many frames drawn over how many seconds.

local M = {}

-- {{{ function M.write()
-- summary: { file = string, format = string, triangles = whole,
--            parts = whole, frames_drawn = whole, seconds_run = number,
--            read_seconds = number, screenshot = string or false,
--            black_share = number 0..1 or nil (only with a screenshot) }
-- The viewer uses no randomness, so the receipt's seed line says so rather
-- than inventing one.
function M.write(project_dir, summary)
    local path = project_dir .. "/output/goodbye"
    local file, problem = io.open(path, "w")
    -- the output folder is missing or unwritable: say so loudly, at the end
    if file == nil then error("could not write the goodbye note: " .. tostring(problem), 0) end
    file:write("goodbye from the CAD viewer (src/010-the-viewer.lua)\n")
    file:write(string.format("written      %s\n", os.date("%Y-%m-%d %H:%M:%S")))
    file:write("seed         none (the viewer uses no randomness)\n")
    file:write(string.format("file         %s\n", summary.file))
    file:write(string.format("format       %s\n", summary.format))
    file:write(string.format("triangles    %d\n", summary.triangles))
    file:write(string.format("parts        %d\n", summary.parts))
    file:write(string.format("read         %.3f seconds\n", summary.read_seconds))
    file:write(string.format("frames       %d\n", summary.frames_drawn))
    file:write(string.format("seconds      %.2f\n", summary.seconds_run))
    file:write(string.format("screenshot   %s\n", summary.screenshot or "none"))
    -- only with a screenshot: the share of its pixels that are pure black,
    -- which a good capture never has (see take_screenshot in 010)
    if summary.black_share then file:write(string.format("black        %.4f\n", summary.black_share)) end
    file:close()
end
-- }}}

return M
