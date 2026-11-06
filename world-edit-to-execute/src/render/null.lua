--[[
null.lua - the headless renderer, for Lua (issue 501c)

In plain terms: lets game code that writes render slots run with no window
and no raylib, and asks the headless renderer (null_render.c) what it
would have drawn. The slots are the real ones (slots.c), reached through
LuaJIT's FFI from a small shared library built from slots.c and
null_render.c; `backend.render` offers the entity calls of the renderer's
Lua bridge (bridge.c, issue 508c) with the same defaults and limits, so
`package.loaded.render = backend.render` makes `src/render.lua` and any
scene written for the window run headless.

  local null = require("render.null")
  local lib = null.build(DIR, BUILD)          -- gcc, once
  local backend = null.open(lib)
  package.loaded.render = backend.render
  ... the scene ...
  local r = backend:report({ min_x = 0, min_y = 0, max_x = 1024, max_y = 1024 })
  print(backend:text())                        -- the report as lines
  backend:close()

Terrain calls of the bridge are not offered: terrain is not in the slots.
After close(), the calls do what the bridge does with no slot array:
nothing, -1, nil, or 0 slots.
]]

local ffi = require("ffi")

local null = {}

ffi.cdef([[
typedef struct render_slot {
    float x, y, z;
    float rotation, spin, facing;
    float scale;
    unsigned char r, g, b, a;
    bool visible, selected;
    int mesh_id, team_id, anim_frame;
    float anim_time;
} RenderSlot;
typedef struct component_slot {
    RenderSlot* data;
    void (*set)(struct component_slot*, RenderSlot*);
    void (*free_fn)(RenderSlot*);
    int entity_id;
    bool in_use;
} ComponentSlot;
typedef struct slot_array SlotArray;
typedef struct null_bounds { float min_x, min_y, max_x, max_y; } NullBounds;
typedef struct null_report {
    int active, drawn, hidden;
    int by_kind[4];
    int placeholders, outside, selected;
    uint64_t checksum;
} NullReport;

SlotArray* slot_array_create(void);
void slot_array_destroy(SlotArray* arr);
void slot_release(SlotArray* arr, int index);
ComponentSlot* slot_get(SlotArray* arr, int index);
void slot_set(ComponentSlot* self, RenderSlot* new_data);
int slot_find_by_entity(SlotArray* arr, int entity_id);
int slot_get_active_count(SlotArray* arr);
int slot_allocate_for_entity(SlotArray* arr, int entity_id);
int null_render_slots(SlotArray* slots, const NullBounds* map, NullReport* out);
int null_report_format(const NullReport* report, char* buf, size_t size);
void* malloc(size_t size);
]])

null.KINDS = { "circle", "cube", "triangle", "cylinder" }   -- mesh ids 0 to 3, as the bridge numbers them
null.MAX_SLOTS = 4096                                       -- slots.h

-- {{{ null.build
-- Compiles slots.c and null_render.c into BUILD/libnull-render.so; returns its path.
function null.build(dir, build)
    if not dir or dir == "" or not build or build == "" then error("render.null: build needs the project and a build folder", 0) end
    local q = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
    local lib = build .. "/libnull-render.so"
    local src = dir .. "/src/render/"
    local cmd = "mkdir -p " .. q(build) .. " && gcc -shared -fPIC -O2 -Wall -pthread -o " .. q(lib)
        .. " " .. q(src .. "slots.c") .. " " .. q(src .. "null_render.c")
    local ok = os.execute(cmd)
    if ok ~= 0 and ok ~= true then error("render.null: failed to build: " .. cmd, 0) end
    return lib
end
-- }}}

-- {{{ null.open
-- A headless backend over a fresh slot array: `backend.render` (the
-- bridge's calls), `backend:report(bounds)`, `backend:text(bounds)`,
-- `backend:close()`.
function null.open(lib_path)
    local C = ffi.load(lib_path)
    local slots = C.slot_array_create()
    if slots == nil then error("render.null: no slot array", 0) end
    local backend = { C = C, slots = slots }

    -- The slot's data, if the slot is in use and has some (as bridge.c checks).
    local function data(index)
        if backend.slots == nil or index < 0 or index >= null.MAX_SLOTS then return nil end
        local slot = C.slot_get(slots, index)
        if slot == nil or not slot.in_use or slot.data == nil then return nil end
        return slot.data
    end
    local function clamp(v) v = math.floor(v) return v < 0 and 0 or (v > 255 and 255 or v) end

    -- {{{ the bridge's entity calls (bridge.c, 508c)
    local r = { MESH_CIRCLE = 0, MESH_CUBE = 1, MESH_TRIANGLE = 2, MESH_CYLINDER = 3, MAX_SLOTS = null.MAX_SLOTS }
    function r.create_entity(entity_id, mesh_id, x, y, z)
        if backend.slots == nil then return -1 end
        local index = C.slot_allocate_for_entity(slots, entity_id)
        if index < 0 then return -1 end
        local d = ffi.cast("RenderSlot*", ffi.C.malloc(ffi.sizeof("RenderSlot")))
        if d == nil then C.slot_release(slots, index) return -1 end
        ffi.fill(d, ffi.sizeof("RenderSlot"))
        d.x, d.y, d.z, d.mesh_id = x, y, z, mesh_id
        d.visible, d.selected, d.scale = true, false, 1
        d.r, d.g, d.b, d.a, d.team_id = 255, 255, 255, 255, -1
        C.slot_set(C.slot_get(slots, index), d)
        return index
    end
    function r.destroy_entity(index) if backend.slots ~= nil then C.slot_release(slots, index) end end
    function r.set_position(index, x, y, z)
        local d = data(index) if d then d.x, d.y, d.z = x, y, z end
    end
    function r.set_color(index, cr, cg, cb, ca)
        local d = data(index) if d then d.r, d.g, d.b, d.a = clamp(cr), clamp(cg), clamp(cb), clamp(ca or 255) end
    end
    function r.set_selected(index, on) local d = data(index) if d then d.selected = on and true or false end end
    function r.set_visible(index, on) local d = data(index) if d then d.visible = on and true or false end end
    function r.set_scale(index, s)
        local d = data(index) if d then d.scale = s <= 0 and 0.01 or s end
    end
    function r.set_team(index, team) local d = data(index) if d then d.team_id = team end end
    function r.set_rotation(index, rotation, spin, facing)
        local d = data(index) if d then d.rotation, d.spin, d.facing = rotation, spin or 0, facing or 0 end
    end
    function r.set_mesh(index, mesh_id) local d = data(index) if d then d.mesh_id = mesh_id end end
    function r.get_slot_count()
        if backend.slots == nil then return 0, 0 end
        return C.slot_get_active_count(slots), null.MAX_SLOTS
    end
    function r.find_by_entity(entity_id)
        if backend.slots == nil then return nil end
        local index = C.slot_find_by_entity(slots, entity_id)
        if index < 0 then return nil end
        return index
    end
    backend.render = r
    -- }}}

    local function bounds(b)
        if not b then return nil end
        return ffi.new("NullBounds", b.min_x, b.min_y, b.max_x, b.max_y)
    end

    -- {{{ backend:report
    -- What the frame would draw: active, drawn, hidden, kinds (by name),
    -- placeholders, outside, selected, checksum (16 hex digits).
    function backend:report(map)
        if self.slots == nil then error("render.null: report after close", 0) end
        local out = ffi.new("NullReport")
        C.null_render_slots(slots, bounds(map), out)
        local kinds = {}
        for i, name in ipairs(null.KINDS) do kinds[name] = out.by_kind[i - 1] end
        return { active = out.active, drawn = out.drawn, hidden = out.hidden, kinds = kinds,
            placeholders = out.placeholders, outside = out.outside, selected = out.selected,
            checksum = string.format("%08x%08x", tonumber(out.checksum / 4294967296ULL), tonumber(out.checksum % 4294967296ULL)) }
    end
    -- }}}

    -- {{{ backend:text
    function backend:text(map)
        if self.slots == nil then error("render.null: report after close", 0) end
        local out = ffi.new("NullReport")
        C.null_render_slots(slots, bounds(map), out)
        local buf = ffi.new("char[512]")
        C.null_report_format(out, buf, 512)
        return ffi.string(buf)
    end
    -- }}}

    function backend:close()
        if self.slots ~= nil then C.slot_array_destroy(self.slots) self.slots = nil end
    end

    return backend
end
-- }}}

return null
