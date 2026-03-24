-- html_gen.lua - LuaJIT FFI bindings for HTML Threaded Writer Library
--
-- This module provides parallel file writing for HTML generation.
-- Lua generates HTML strings, C handles parallel I/O via pthreads.
--
-- Usage:
--   local htmlgen = require("html_gen")
--   local ctx = htmlgen.init(8)  -- 8 threads
--   htmlgen.add_file(ctx, "/path/to/file.html", "<html>...</html>")
--   htmlgen.add_file(ctx, "/path/to/file2.html", "<html>...</html>")
--   htmlgen.write_all(ctx)
--   local stats = htmlgen.get_stats(ctx)
--   htmlgen.destroy(ctx)

local ffi = require("ffi")

-- {{{ local M = {}
local M = {}
-- }}}

-- {{{ FFI definitions
ffi.cdef[[
    /* Opaque context handle */
    typedef struct HtmlGenContext HtmlGenContext;

    /* Error codes */
    typedef enum {
        HTMLGEN_SUCCESS = 0,
        HTMLGEN_ERROR_INIT_FAILED = -1,
        HTMLGEN_ERROR_OUT_OF_MEMORY = -2,
        HTMLGEN_ERROR_WRITE_FAILED = -3,
        HTMLGEN_ERROR_INVALID_CONTEXT = -4,
        HTMLGEN_ERROR_ALREADY_RUNNING = -5,
    } HtmlGenResult;

    /* Statistics structure */
    typedef struct {
        uint32_t total_files;
        uint32_t files_written;
        uint32_t files_failed;
        uint64_t total_bytes;
        double elapsed_seconds;
    } HtmlGenStats;

    /* Core API */
    HtmlGenContext* htmlgen_init(int num_threads);
    HtmlGenResult htmlgen_add_file(HtmlGenContext* ctx,
                                    const char* filepath,
                                    const char* content,
                                    size_t content_len);
    HtmlGenResult htmlgen_write_all(HtmlGenContext* ctx);
    float htmlgen_get_progress(HtmlGenContext* ctx);
    HtmlGenResult htmlgen_get_stats(HtmlGenContext* ctx, HtmlGenStats* stats);
    void htmlgen_clear(HtmlGenContext* ctx);
    void htmlgen_destroy(HtmlGenContext* ctx);
    const char* htmlgen_error_string(HtmlGenResult result);
]]
-- }}}

-- {{{ Load shared library
-- Library path resolution: check environment, global, then default
local lib_path = os.getenv("HTMLGEN_LIB") or
                 _G.HTMLGEN_LIB or
                 "/mnt/mtwo/programming/ai-stuff/neocities-modernization/libs/html-threaded/build/libhtmlgen.so"

local lib = nil
local load_success, load_err = pcall(function()
    lib = ffi.load(lib_path)
end)

if not load_success then
    error(string.format("Failed to load libhtmlgen.so from '%s': %s\n" ..
                        "Build with: cd libs/html-threaded && make", lib_path, load_err))
end
-- }}}

-- {{{ Error handling helper
local function check_result(result, operation)
    if result ~= 0 then
        local err_str = ffi.string(lib.htmlgen_error_string(result))
        error(string.format("%s failed: %s (code %d)", operation, err_str, tonumber(result)))
    end
end
-- }}}

-- {{{ M.init
-- Initialize HTML generator context
-- @param num_threads Number of worker threads (0 or nil = auto-detect CPU cores)
-- @return Context handle (must be passed to destroy when done)
function M.init(num_threads)
    num_threads = num_threads or 0
    local ctx = lib.htmlgen_init(num_threads)
    if ctx == nil then
        error("Failed to initialize HTML generator context")
    end
    return ctx
end
-- }}}

-- {{{ M.add_file
-- Add a file to the write queue
-- @param ctx Context handle from init()
-- @param filepath Full path to output file
-- @param content HTML content string
function M.add_file(ctx, filepath, content)
    local result = lib.htmlgen_add_file(ctx, filepath, content, #content)
    check_result(result, "add_file")
end
-- }}}

-- {{{ M.add_files
-- Add multiple files at once (convenience function)
-- @param ctx Context handle from init()
-- @param files Array of {path=string, content=string} tables
function M.add_files(ctx, files)
    for _, file in ipairs(files) do
        M.add_file(ctx, file.path, file.content)
    end
end
-- }}}

-- {{{ M.write_all
-- Write all queued files using thread pool
-- Blocks until all files are written
-- @param ctx Context handle from init()
function M.write_all(ctx)
    local result = lib.htmlgen_write_all(ctx)
    check_result(result, "write_all")
end
-- }}}

-- {{{ M.get_progress
-- Get current progress (0.0 to 1.0)
-- Can be called from another thread/coroutine while write_all is running
-- @param ctx Context handle from init()
-- @return Progress as fraction (0.0 = not started, 1.0 = complete)
function M.get_progress(ctx)
    return lib.htmlgen_get_progress(ctx)
end
-- }}}

-- {{{ M.get_stats
-- Get statistics after write_all completes
-- @param ctx Context handle from init()
-- @return Table with total_files, files_written, files_failed, total_bytes, elapsed_seconds
function M.get_stats(ctx)
    local stats = ffi.new("HtmlGenStats")
    local result = lib.htmlgen_get_stats(ctx, stats)
    check_result(result, "get_stats")

    return {
        total_files = tonumber(stats.total_files),
        files_written = tonumber(stats.files_written),
        files_failed = tonumber(stats.files_failed),
        total_bytes = tonumber(stats.total_bytes),
        elapsed_seconds = stats.elapsed_seconds,
    }
end
-- }}}

-- {{{ M.clear
-- Clear the file queue (reuse context for another batch)
-- @param ctx Context handle from init()
function M.clear(ctx)
    lib.htmlgen_clear(ctx)
end
-- }}}

-- {{{ M.destroy
-- Destroy context and free all resources
-- @param ctx Context handle from init()
function M.destroy(ctx)
    lib.htmlgen_destroy(ctx)
end
-- }}}

-- {{{ M.write_files
-- Convenience function: add files and write in one call
-- @param files Array of {path=string, content=string} tables
-- @param num_threads Number of worker threads (0 = auto-detect)
-- @return Statistics table
function M.write_files(files, num_threads)
    local ctx = M.init(num_threads or 0)
    M.add_files(ctx, files)
    M.write_all(ctx)
    local stats = M.get_stats(ctx)
    M.destroy(ctx)
    return stats
end
-- }}}

return M
