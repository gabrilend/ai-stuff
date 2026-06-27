# page-template

Fills `{UPPERCASE_NAME}` markers in a plain-text template with live values, so a
generated page's wording can live in an editable `input/` file while its numbers
are still computed in code. Strict by design: an unresolved marker stops the
build instead of leaking onto the page.

Created for Issue 11-005 (editable explore-page copy). Generalizes the
`{PLACEHOLDER}` substitution that `report-generator.lua` did inline.

## Marker shape

A marker is `{` + one or more of `A-Z 0-9 _` + `}`, e.g. `{TOTAL_POEMS}`.
Uppercase-only on purpose: ordinary prose and HTML never contain that exact
shape, so the template's real text is never mistaken for a marker. Lowercase
`{x}` is left untouched.

## External functions

### `M.substitute(template, values)`
- **template**: string. The raw template text.
- **values**: table mapping a marker name (without braces) to a string, a number,
  or `M.OMIT`.
- **returns**: the filled string on success; `nil, error_message` if `template`
  names a marker absent from `values` (the message lists every missing marker at
  once), or if the arguments are the wrong type.
- Percent signs in values are safe (no escaping needed by the caller).

### `M.render_file(path, values)`
- **path**: string. Path to a template file on disk (read with `io.open`, so the
  module has no dependency on the project utils).
- **values**: same as above.
- **returns**: the filled string on success; `nil, error_message` on a missing
  file or any unresolved marker.

### `M.OMIT`
A sentinel value. Set a marker to `M.OMIT` and the **entire template line** that
mentions that marker is removed -- no blank gap. Use it for stat lines that only
appear when the fact exists (e.g. a date range, an image-only count of zero).

## Usage shape

```lua
local tmpl = require("page-template")
local html_body, err = tmpl.render_file(DIR .. "/input/pages/explore.txt", {
    TOTAL_POEMS  = stats.total,
    SOURCE_COUNT = #stats.source_order,
    MIN_DATE     = stats.min_date or tmpl.OMIT,  -- drops the "spanning..." line
    SOURCE_LIST  = table.concat(source_list_lines, "\n"),  -- a pre-built block
})
if not html_body then error(err) end
```

## Related
- `src/flat-html-generator.lua` -- the explore-page generators that use this.
- `input/pages/explore.txt`, `input/pages/explore-math.txt` -- the templates.
- `src/page-template.test.lua` -- the unit tests.
