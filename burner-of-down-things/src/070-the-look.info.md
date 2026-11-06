# 070-the-look.lua

The owner's style as one table (docs/067, issue 801a): `ground` (`black`,
`gray`, `white`), `palette` (`night` or `day`, resolved from `ground`, never
stored), `flair` (boolean), `line_weight` (pixels), `arrow` (`there-here`),
`flair_shift` (how far the flair's quarters move toward white or black, a
fraction; a balance number). A colour is `{r, g, b[, a]}`, 0-255, raylib's
own range.

| Function | In | Out |
|---|---|---|
| `default_palette(ground)` | a ground value | `"day"` when `ground == "white"`, else `"night"` |
| `defaults()` | | a fresh table of every field, `palette` resolved |
| `DEFAULTS` | | the stored fields and their values (not `palette`) |
| `FIELDS` | | the closed list of every field name a canvas may override (801b) |
| `with_overrides(overrides)` | a table of field name to new value | `defaults()` with those fields replaced, `palette` re-resolved from an overridden `ground` unless named outright; an unknown name is refused, naming the legal fields |
| `shift(colour, amount)` | a colour; -1..1 | a new colour moved that far toward white (+) or black (-), rounded, alpha kept (801c) |
| `flair_quarters(base, look)` | a midline's colour; a look (defaults if nil) | four quarters, each `{first half, second half}`: `{lighter, lighter}`, `{lighter, darker}` twice, `{darker, darker}`, by `look.flair_shift`; all base with `flair` off (801c) |
| `NIGHT_ONLY` | | `{[category] = true}` for categories where `day` is refused; none marked (docs/010, question 15) (801d) |
| `check_palette(category, look, night_only)` | category; a look; marks (defaults to `NIGHT_ONLY`) | the look; refuses `day` on a marked category, naming docs/067's rule (801d) |
| `for_canvas(category, overrides, night_only)` | | `with_overrides` then `check_palette`: a canvas's whole look, checked before it compiles |
