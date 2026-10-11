-- 023-the-ceramic-host.lua - the render thread's handle on the ceramic engine.
--
-- In plain terms: the world's work runs in C on the ceramic engine's worker
-- threads (020, 021, 022, built by scripts/build-ceramics). This file loads
-- that library through LuaJIT's FFI and drives one step of the world in two
-- stages, never waiting:
--
--   hand in every unit chunk  ─▶ (workers: units think and move)
--   all landed? hand in every cuboid chunk ─▶ (workers: cuboids settle)
--   all landed? the step is done: the caller swaps front and back
--
-- Each frame the render thread calls `advance` once. It looks at how many
-- chunks have landed and, only if a stage is complete, hands in the next.
-- Between frames it does nothing; it never blocks on the workers.
--
-- Every refusal from the engine stops the game with the engine's own
-- sentence (no fallbacks).

local ffi = require("ffi")

local M = {}

ffi.cdef([[
const char *ceramics_error(void);
void ceramics_set_fold(double strength, double tiers, double hub, double edge, double figure);
void ceramics_set_size_keep(double keep);
int ceramics_set_section(int index, double r, double angle, double radius);
int ceramics_start(int workers, int units, int cubes, unsigned seed);
void ceramics_set_world(unit_record *units_front, unit_record *units_back,
                        cuboid_record *cubes_front, cuboid_record *cubes_back);
int ceramics_hand_in(int stage, double step_seconds);
int ceramics_landed(int stage);
int ceramics_chunks(int stage);
void ceramics_stop(void);
void ceramics_run_inline(int stage, double step_seconds, int reversed);
void ceramics_set_counts(int units, int cubes, unsigned seed);
void ceramics_move_reference(const unit_record *source, unit_record *destination, double dt);
]])

-- The stages of one step.
local UNITS, CUBOIDS = 0, 1

-- {{{ function M.load()
-- Loads the library from the project's executable scratch tier. A missing
-- library is an error naming the build script.
function M.load(project_dir)
    local path = project_dir .. "/tmp/tmp/ceramic/libceramics.so"
    local ok, library = pcall(ffi.load, path)
    -- not built (or the scratch tier was emptied by a reboot)
    if not ok then
        error("the world's engine is not built: run scripts/build-ceramics (" .. tostring(library) .. ")", 0)
    end
    return library
end
-- }}}

-- {{{ local function must()
local function must(library, result, what)
    -- a refusal: stop, with the engine's sentence
    if result < 0 then
        error("the ceramic engine refused " .. what .. ": " .. ffi.string(library.ceramics_error()), 0)
    end
    return result
end
-- }}}

-- {{{ function M.start()
-- Starts the engine. `world` holds the fold, the figure scale, the sections,
-- counts, worker count and seed.
function M.start(library, world)
    library.ceramics_set_fold(world.fold.strength, world.fold.tiers_shown,
        world.fold.hub_radius, world.fold.edge_radius, world.figure_scale)
    library.ceramics_set_size_keep(world.fold.size_keep)
    for index, section in ipairs(world.sections) do
        must(library, library.ceramics_set_section(index - 1, section.r, section.angle, section.radius),
            "a section")
    end
    must(library, library.ceramics_start(world.workers, world.unit_count, world.cuboid_count, world.seed),
        "to start")
    return {
        library = library,
        stage = nil,          -- nil: nothing in flight; else the stage in flight
        step_seconds = 0,
        size_keep = world.fold.size_keep,  -- the size law wanted (0 or 1)
    }
end
-- }}}

-- {{{ function M.advance()
-- Called once a frame. `set_world` is called just before a step's first stage
-- is handed in (so the caller points the engine at the current front and
-- back blocks); `step_seconds` is the time the next step should cover.
-- Returns whether a step has just finished (the caller swaps the blocks) and
-- whether one has just begun; `host.just_handed_in` says the cuboid stage
-- went in on this look.
function M.advance(host, step_seconds_waiting, set_world)
    local library = host.library
    host.just_handed_in = false
    -- nothing in flight: begin a step with the unit stage
    if host.stage == nil then
        set_world()
        -- the size law, changed only here, between steps
        library.ceramics_set_size_keep(host.size_keep)
        host.step_seconds = step_seconds_waiting
        must(library, library.ceramics_hand_in(UNITS, host.step_seconds), "the unit chunks")
        host.stage = UNITS
        return false, true
    end
    -- the stage in flight has not wholly landed: look again next frame
    if library.ceramics_landed(host.stage) < library.ceramics_chunks(host.stage) then
        return false, false
    end
    -- the units have landed: the cuboids read them, so they go in now
    if host.stage == UNITS then
        must(library, library.ceramics_hand_in(CUBOIDS, host.step_seconds), "the cuboid chunks")
        host.stage = CUBOIDS
        host.just_handed_in = true
        return false, false
    end
    -- the cuboids have landed: the step is done
    host.stage = nil
    return true, false
end
-- }}}

-- {{{ function M.set_size_keep()
-- Asks for a size law (0: far things shrink; 1: full size everywhere, for
-- the slant view). It reaches the engine at the start of the next step.
function M.set_size_keep(host, keep)
    host.size_keep = keep
end
-- }}}

-- {{{ function M.stop()
-- Lets any stage in flight land (a short wait, only when closing), then
-- stops the workers.
function M.stop(host)
    local library = host.library
    while host.stage ~= nil and library.ceramics_landed(host.stage) < library.ceramics_chunks(host.stage) do
    end
    library.ceramics_stop()
end
-- }}}

return M
