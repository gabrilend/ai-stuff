<!-- written by Claude (Opus 5.5), 2026-10-11, for issue 011 (pictures and moving pictures): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 031-making-a-gif

`luajit src/031-making-a-gif.lua <project-dir> FRAMES-FOLDER OUT.gif`: reads a recording's info.lua and raw frames, chooses one colour table from all frames, shares the frames among one worker per processor (the same program in worker mode, each compressing its own run of frames to a part file), and joins the parts in frame order, so the same frames always give the same file. Finds its code beside itself.
