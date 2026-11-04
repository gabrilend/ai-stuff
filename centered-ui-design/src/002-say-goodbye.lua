-- 002-say-goodbye.lua - the last thing the program does: write output/goodbye.
--
-- In plain terms: when the window closes, the program leaves a short note in
-- the project's output folder saying when it ran, from which seed, and how
-- many frames and simulation steps it got through, so a run always leaves a
-- trace a person can read.

local M = {}

-- {{{ function M.write()
-- Writes the goodbye note. `summary` is a table of plain values:
-- seed (whole), frames_drawn (whole), steps_run (whole), seconds_run (number).
function M.write(project_dir, summary)
    local path = project_dir .. "/output/goodbye"
    local file, open_error = io.open(path, "w")
    -- the output folder is missing or unwritable: say so loudly, at the end
    if file == nil then
        error("could not write the goodbye note: " .. tostring(open_error), 0)
    end
    file:write("goodbye\n")
    file:write(string.format("written    %s\n", os.date("%Y-%m-%d %H:%M:%S")))
    file:write(string.format("seed       %d\n", summary.seed))
    file:write(string.format("frames     %d\n", summary.frames_drawn))
    file:write(string.format("steps      %d\n", summary.steps_run))
    file:write(string.format("seconds    %.2f\n", summary.seconds_run))
    file:close()
end
-- }}}

return M
