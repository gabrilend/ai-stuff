# 807d — Prose templates

The fourth piece of 807.

## Current Behavior

Built. `src/072-the-txt-canvas.lua`'s `prose(template, data)` fills
`{{slot}}` marks (034's syntax) from the canvas's data. A slot with no
value, an empty value or a value that is not text or a number, and a
`{{` that opens no slot mark, are findings: the function returns nil and
every finding, never a blank. Checked by
`tests/132-checking-prose-templates.lua` against a stored expected file.

## Intended Behavior

Canvas word `prose`: a template string with `{{slot}}` marks (034's own
slot syntax) filled from the canvas's data; a missing slot is a finding,
never rendered blank.

## Suggested Implementation Steps

1. A slot-fill function matching 034's `fill` shape.
2. The missing-slot finding. **Test:** a template with every slot filled
   matches exactly; a missing slot is a finding, never a blank. Done.

## Decisions

- `prose(template, data)` returns the filled text, or nil and every
  finding in order, so one look shows all the holes; nothing partial is
  ever rendered.
- An empty-string value is a finding too: it would render blank all the
  same. The number 0 is a value.
- A value that is neither text nor a number (a table, say) is a finding,
  rather than printing as a Lua address.
- A `{{` that opens no slot mark (a typo such as `{{ name}}`) is a
  finding, since it would otherwise print as itself.
- The slot syntax is 034's own pattern, so a template filled with
  nothing missing reads exactly as 034's `fill` would make it.

## Blocked by

- 807a
