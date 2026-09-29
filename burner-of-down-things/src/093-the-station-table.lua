-- 093-the-station-table.lua
--
-- One row per station: its name, the shape it takes, the shape it gives,
-- and the function that runs it (docs/068, issue 902d). `TABLE` holds only
-- stations that are actually built today; it grows as more studio ends
-- (804, 806, 808) and machine steps join it. `find` is generic — it never
-- reaches into `TABLE` itself — so it works the same whether `TABLE` holds
-- one row or fifty (strategems/build-to-the-shape-not-the-neighbor.md).

local txt_canvas = require("072-the-txt-canvas")

local station_table = {}

-- Real stations only. Today: 807a's `table` word, the one .txt canvas
-- word that is actually built. A row's `run` is the function itself, not
-- a shell command — every station here runs in this same process.
station_table.TABLE = {
    {
        name = "txt-table",
        input = "table",
        output = "text",
        run = txt_canvas.table,
    },
}

-- {{{ function station_table.find
-- The station taking `input_shape` and giving `output_shape`, from any
-- table of rows shaped like TABLE's own ({name, input, output, ...}) —
-- not only TABLE itself, so this function can be proven against a fixture
-- before more real rows exist. Returns the row, or nil plus every station
-- name whose input or output shape is at least a partial match, said
-- plainly rather than dropped silently.
function station_table.find(rows, input_shape, output_shape)
    local near = {}
    for _, row in ipairs(rows) do
        if row.input == input_shape and row.output == output_shape then
            return row
        end
        if row.input == input_shape or row.output == output_shape then
            near[#near + 1] = row.name
        end
    end
    return nil, near
end
-- }}}

return station_table
