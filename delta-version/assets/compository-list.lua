-- compository-list.lua - What goes on a compository flash drive.
--
-- compository.lua walks this list, one item at a time, and carries each item
-- to every connected drive that has been marked as a compository. Edit this
-- file to change what travels; the tool itself holds no choices of its own.
--
-- Two sections:
--
--   repositories -- the owner's git repositories, found by searching rather
--                   than listed one by one, so a new repository joins the
--                   drive without anyone remembering to add it. A repository
--                   is the owner's when its first commit was made under one
--                   of the owner's email addresses; that keeps clones of
--                   other people's work (raylib, LuaJIT, V) off the drive
--                   even when the owner has committed on top of them.
--
--   selected     -- hand-picked notes, documents and tools, as paths relative
--                   to the first root. They are gathered into a git
--                   repository of their own on this computer
--                   (selected_repository), committed whenever they change,
--                   and that repository is then carried like any other --
--                   so the drive plays them forward too. While the list is
--                   empty, no such repository is made.

return {
    repositories = {
        -- Folders searched for repositories, at any depth. The home-folder
        -- path is a symlink to this one, so it is not listed twice.
        roots = { "/mnt/mtwo/programming" },

        -- Every address the owner has committed under.
        owner_emails = { "gabrilend@gmail.com" },

        -- Folders the search never enters: third-party code and generated
        -- trees, where no repository of the owner's lives.
        never_enter = { "node_modules", "libs", ".git" },

        -- Repositories that are the owner's but stay off the drive, as paths
        -- relative to a root. (Worktrees need no entry: their .git is a file,
        -- not a folder, so the search never counts them.)
        exclude = {
            -- The owner: "neither of those should be included" (2026-09-23).
            "teriyaki-euler",
            "lua/project-euler/teriyaki-euler",
        },
    },

    selected = {},
    selected_repository = "/mnt/mtwo/programming/compository-selected",
}
