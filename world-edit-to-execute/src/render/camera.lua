--[[
camera.lua - the game camera (camera.c, issue 501d), for Lua

In plain terms: the same camera numbers and answers as the C renderer
uses, reached through LuaJIT's FFI from a small shared library built from
camera.c, so a scene, the interface or a test can ask which ground is
under a screen point, or in view, with no window.

  local camera = require("render.camera")
  local lib = camera.open(camera.build(DIR, BUILD))   -- gcc, once
  local cam = lib.new(x, y, z)                         -- WC3's default camera there
  cam:bounds_from_w3i(map.camera_bounds)               -- the map's eight floats
  local x, y = cam:screen_to_ground(1280, 720, sx, sy) -- nil above the horizon
  local sx, sy = cam:world_to_screen(1280, 720, x, y, z)
  local quad, reached = cam:view_quad(1280, 720)       -- { x1, y1, ... x4, y4 }
  local rect = cam:view_rect(1280, 720)                -- { min_x, min_y, max_x, max_y }
  cam.c.distance = 2200                                -- the numbers, as in C

Ground height for the answers is the camera's own z (the ground under its
target) unless one is given as the last argument.
]]

local ffi = require("ffi")

local camera = {}

ffi.cdef([[
typedef struct camera_bounds { float min_x, min_y, max_x, max_y; } CameraBounds;
typedef struct game_camera {
    float x, y, z, distance, rotation, aoa, fov, farz, min_distance, max_distance;
    CameraBounds bounds;
    bool has_bounds;
} GameCamera;
typedef struct camera_frame {
    float eye[3], forward[3], right[3], up[3];
    float tan_x, tan_y, width, height;
} CameraFrame;
void camera_init(GameCamera* cam, float x, float y, float z);
void camera_bounds_from_w3i(GameCamera* cam, const float corners[8]);
void camera_clamp(GameCamera* cam);
void camera_look_at(GameCamera* cam, float x, float y);
void camera_frame(const GameCamera* cam, float width, float height, CameraFrame* out);
bool camera_screen_to_ground(const CameraFrame* f, float sx, float sy, float ground_z, float* x, float* y);
bool camera_world_to_screen(const CameraFrame* f, float x, float y, float z, float* sx, float* sy);
int camera_view_quad(const GameCamera* cam, const CameraFrame* f, float ground_z, float corners[8]);
void camera_view_rect(const GameCamera* cam, const CameraFrame* f, float ground_z, CameraBounds* out);
]])

-- {{{ camera.build
-- Compiles camera.c (and any further C files of src/render named in
-- `extra`) into BUILD/libcamera.so; returns its path.
function camera.build(dir, build, extra)
    if not dir or dir == "" or not build or build == "" then error("render.camera: build needs the project and a build folder", 0) end
    local q = function(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
    local lib = build .. "/libcamera.so"
    local src = dir .. "/src/render/"
    local files = { q(src .. "camera.c") }
    for _, name in ipairs(extra or {}) do files[#files + 1] = q(src .. name) end
    local cmd = "mkdir -p " .. q(build) .. " && gcc -shared -fPIC -O2 -Wall -Wextra -o " .. q(lib)
        .. " " .. table.concat(files, " ") .. " -lm"
    local ok = os.execute(cmd)
    if ok ~= 0 and ok ~= true then error("render.camera: build failed: " .. cmd, 0) end
    return lib
end
-- }}}

-- {{{ camera.open
function camera.open(lib_path)
    local C = ffi.load(lib_path)
    local api = { C = C }
    local Cam = {}
    Cam.__index = Cam

    function api.new(x, y, z)
        local c = ffi.new("GameCamera")
        C.camera_init(c, x or 0, y or 0, z or 0)
        return setmetatable({ c = c, f = ffi.new("CameraFrame"),
            xy = ffi.new("float[2]"), quad = ffi.new("float[8]") }, Cam)
    end

    function Cam:bounds_from_w3i(t)
        local b = ffi.new("float[8]")
        for i = 1, 8 do b[i - 1] = t[i] or 0 end
        C.camera_bounds_from_w3i(self.c, b)
    end
    function Cam:clamp() C.camera_clamp(self.c) end
    function Cam:look_at(x, y) C.camera_look_at(self.c, x, y) end
    function Cam:target() return self.c.x, self.c.y, self.c.z end
    function Cam:frame(w, h)
        C.camera_frame(self.c, w, h, self.f)
        return self.f
    end
    function Cam:screen_to_ground(w, h, sx, sy, ground_z)
        local p = self.xy
        if not C.camera_screen_to_ground(self:frame(w, h), sx, sy, ground_z or self.c.z, p, p + 1) then return nil end
        return p[0], p[1]
    end
    function Cam:world_to_screen(w, h, x, y, z)
        local p = self.xy
        if not C.camera_world_to_screen(self:frame(w, h), x, y, z or self.c.z, p, p + 1) then return nil end
        return p[0], p[1]
    end
    function Cam:view_quad(w, h, ground_z)
        local n = C.camera_view_quad(self.c, self:frame(w, h), ground_z or self.c.z, self.quad)
        local out = {}
        for i = 0, 7 do out[i + 1] = self.quad[i] end
        return out, n
    end
    function Cam:view_rect(w, h, ground_z)
        local r = ffi.new("CameraBounds")
        C.camera_view_rect(self.c, self:frame(w, h), ground_z or self.c.z, r)
        return { min_x = r.min_x, min_y = r.min_y, max_x = r.max_x, max_y = r.max_y }
    end

    api.Cam = Cam
    return api
end
-- }}}

return camera
