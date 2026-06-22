-- test-progress-ui.lua
-- Issue 026 smoke test: fakes a 20-page book and exercises the redraw
-- region with a small sleep between pages so the gradient color shift
-- and the high-water-mark grow-and-pad behavior are visible by eye.
--
-- Run with:  LOG_FILE=/tmp/test-progress-ui.log lua5.2 test-progress-ui.lua
-- Then `cat /tmp/test-progress-ui.log` to confirm the log got plain text
-- with no ANSI escapes.

package.path = package.path .. ";./?.lua"
local progress_ui = require "libs/progress-ui"

local TOTAL = 20
progress_ui.init(TOTAL)

for page = 1, TOTAL do
    progress_ui.start_page(page)

    -- First few pages emit fewer lines so we can watch max_region_height
    -- grow when the heavier pages arrive.
    local poem_count = (page <= 3) and 4 or 12
    for i = 1, poem_count do
        progress_ui.log(string.format("  📝 Left poem %d: theme_%d (Tier 2)", i, i))
    end
    progress_ui.log("🎨 Page background theme: circuit")
    progress_ui.log(string.format("✨ Tier 1 art enabled: page is %d%% full", 50 + page))

    progress_ui.end_page()

    -- Sleep ~80ms so the human eye can see the redraw step.
    os.execute("sleep 0.08")
end

progress_ui.finish()
print(string.format("✅ Smoke test done — %d frames rendered", TOTAL))
