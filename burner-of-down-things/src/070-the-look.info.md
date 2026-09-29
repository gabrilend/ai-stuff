# 070-the-look.lua

The owner's style as one table (docs/067, issue 801a): `ground` (`black`,
`gray`, `white`), `palette` (`night` or `day`, resolved from `ground`, never
stored), `flair` (boolean), `line_weight` (pixels), `arrow` (`there-here`).

| Function | In | Out |
|---|---|---|
| `default_palette(ground)` | a ground value | `"day"` when `ground == "white"`, else `"night"` |
| `defaults()` | | a fresh table of every field, `palette` resolved |
| `DEFAULTS` | | the stored fields and their values (not `palette`) |
| `FIELDS` | | the closed list of every field name a canvas may override (801b) |
