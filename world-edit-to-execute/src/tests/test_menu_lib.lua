#!/usr/bin/env luajit
-- Smoke test for menu.lua library
-- Tests basic initialization and configuration without running full TUI
--
-- This validates the uncommitted changes to menu.lua haven't broken the API.

local LIBS_DIR = "/home/ritz/programming/ai-stuff/scripts/libs"
package.path = LIBS_DIR .. "/?.lua;" .. package.path

-- {{{ main
local function main()
    print("Testing menu.lua library")
    print("========================")
    print("")

    -- Test 1: Can we require the module?
    print("Test 1: Require module...")
    local ok, menu = pcall(require, "menu")
    if not ok then
        print("  FAIL: Could not load menu.lua: " .. tostring(menu))
        return 1
    end
    print("  PASS: Module loaded")

    -- Test 2: Can we initialize with empty config?
    print("Test 2: Initialize with empty config...")
    ok, err = pcall(menu.init, {})
    if not ok then
        print("  FAIL: menu.init({}) failed: " .. tostring(err))
        return 1
    end
    print("  PASS: Empty init works")

    -- Test 3: Can we initialize with sections and items?
    print("Test 3: Initialize with sections and items...")
    ok, err = pcall(menu.init, {
        sections = {
            {
                id = "options",
                title = "Options",
                type = "multi",
                items = {
                    {id = "verbose", label = "Verbose", type = "checkbox", value = "0"},
                    {id = "dry_run", label = "Dry Run", type = "checkbox", value = "1"},
                }
            },
            {
                id = "files",
                title = "Files",
                type = "single",
                items = {
                    {id = "file1", label = "test.txt", type = "checkbox", value = "1"},
                }
            }
        },
        command_base = "./test.sh",
    })
    if not ok then
        print("  FAIL: menu.init with config failed: " .. tostring(err))
        return 1
    end
    print("  PASS: Config init works")

    -- Test 4: Can we get values?
    print("Test 4: Get item values...")
    local values = menu.get_values()
    if type(values) ~= "table" then
        print("  FAIL: get_values() didn't return table")
        return 1
    end
    if values.verbose ~= "0" then
        print("  FAIL: verbose should be '0', got: " .. tostring(values.verbose))
        return 1
    end
    if values.dry_run ~= "1" then
        print("  FAIL: dry_run should be '1', got: " .. tostring(values.dry_run))
        return 1
    end
    print("  PASS: Values retrieved correctly")

    -- Test 5: Test new dependency feature
    print("Test 5: Initialize with dependencies...")
    ok, err = pcall(menu.init, {
        sections = {
            {
                id = "mode",
                title = "Mode",
                type = "single",
                items = {
                    {id = "analyze", label = "Analyze", type = "checkbox", value = "1"},
                    {id = "execute", label = "Execute", type = "checkbox", value = "0"},
                }
            },
            {
                id = "options",
                title = "Options",
                type = "multi",
                items = {
                    {id = "skip", label = "Skip Existing", type = "checkbox", value = "0"},
                }
            }
        },
        dependencies = {
            {
                item_id = "skip",
                depends_on = "analyze",
                required_values = {"1"},
                reason = "Only available in Analyze mode"
            }
        }
    })
    if not ok then
        print("  FAIL: menu.init with dependencies failed: " .. tostring(err))
        return 1
    end
    print("  PASS: Dependencies config works")

    -- Test 6: Test new content_sources feature
    print("Test 6: Initialize with content_sources...")
    ok, err = pcall(menu.init, {
        sections = {
            {
                id = "files",
                title = "Files",
                type = "single",
                items = {
                    {id = "f1", label = "File 1", type = "checkbox", value = "1", filepath = "/tmp/test.txt"},
                }
            }
        },
        content_sources = {
            {type = "text", label = "Info", content = "Test content"},
            {type = "item_file", label = "Preview"}
        }
    })
    if not ok then
        print("  FAIL: menu.init with content_sources failed: " .. tostring(err))
        return 1
    end
    print("  PASS: Content sources config works")

    print("")
    print("========================")
    print("All tests PASSED")
    return 0
end
-- }}}

os.exit(main())
