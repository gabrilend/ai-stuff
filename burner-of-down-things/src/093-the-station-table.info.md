# 093-the-station-table.lua

The switchboard's station table (docs/068, issue 902d): what shape a
station takes, what shape it gives, and the function that runs it. `TABLE`
holds only stations actually built today (currently: 807a's `table`
word); `find` is generic and works against any rows of the same shape, so
905's shortest-chain search was built and tested before this table held
more than one row (strategems/build-to-the-shape-not-the-neighbor.md).

| Function | In | Out |
|---|---|---|
| `find(rows, input_shape, output_shape)` | array of `{name, input, output, run}`; the wanted input and output shapes | the matching row, or `nil` plus an array of station names that partly match (same input or same output), never silently dropped |
| `TABLE` | | the real station rows, growing as more studio ends and machine steps are built |
