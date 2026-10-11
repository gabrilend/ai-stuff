-- 008-say-goodbye.lua - the last thing the viewer does: write output/goodbye.
--
-- In plain terms: a receipt. Its fresh timestamp proves the viewer reached a
-- clean ending (a crash never says goodbye), and its numbers say what the
-- run did without anyone watching: which file, how many triangles and parts,
-- how many frames drawn over how many seconds, and each picture it saved.

local M = {}

-- {{{ function M.write()
-- summary: { file = string, format = string, triangles = whole,
--            parts = whole, frames_drawn = whole, seconds_run = number,
--            read_seconds = number, ignored_input = whole (key presses,
--            drags and wheel turns a scripted run did not obey),
--            coverage = nil, or part name -> { stations = whole,
--            best_share = number, best_station = string } (with --stations),
--            part_order = the viewer's mesh list, for the order of parts,
--            pictures = list of { path = string, view = string,
--                                 black_share = number 0..1,
--                                 camera = string: picture size, yaw, pitch,
--                                 distance, target -- so a picture's
--                                 viewpoint can be told and repeated } }
-- One "picture" line per saved picture: view, share of pure-black pixels
-- (a good picture has none; see save_pictures in 010), path.
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
    file:write(string.format("ignored      %d real input events (a scripted run listens to its script only)\n", summary.ignored_input))
    -- {{{ coverage (issue 008): every part, and how many stations show it
    if summary.coverage then
        local unseen = {}
        for _, item in ipairs(summary.part_order) do
            local entry = summary.coverage[item.part.name]
            file:write(string.format("seen         %-20s at %2d stations, largest %5.1f%% of the picture at %s\n",
                item.part.name, entry.stations, entry.best_share * 100, entry.best_station))
            if entry.stations == 0 then unseen[#unseen + 1] = item.part.name end
        end
        file:write(string.format("unseen       %d%s\n", #unseen, #unseen > 0 and (" (" .. table.concat(unseen, ", ") .. ")") or ""))
    end
    -- }}}
    file:write(string.format("pictures     %d\n", #summary.pictures))
    for _, picture in ipairs(summary.pictures) do
        file:write(string.format("picture      %-10s black %.4f  %s\n", picture.view, picture.black_share, picture.path))
        if picture.station then file:write(string.format("  station    %s\n", picture.station)) end
        file:write(string.format("  camera     %s\n", picture.camera))
    end
    file:close()
end
-- }}}

return M
