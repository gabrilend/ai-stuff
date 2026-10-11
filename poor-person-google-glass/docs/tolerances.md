<!-- Made by Claude (Opus 5.5), 2026-10-10, for issue 009, as the contract for calculation files: src/019 checks every file against it. -->
# Tolerance calculations: the format

A calculation answers one question about whether parts will fit and work
when every number is a little off. Each lives in its own file in
`input/calculations/NAME.lua`; `./calculate` works them all out (or
`./calculate NAME`), writing `output/calculations/NAME.results.lua` (the
numbers) and `NAME.report.md` (the same, for people).

## A calculation file

```lua
return {
    question = "Does a tab still swing freely in its channel, cold to warm?",
    inputs = {
        { name = "channel_width", nominal = 0.40, unit = "mm", minus = 0.02, plus = 0.02,
          from = "guess: etched glass channel" },
        ...
    },
    outputs = {
        { name = "clearance_per_side", unit = "mm", at_least = 0.01 },
    },
    compute = function(v)
        return { clearance_per_side = (v.channel_width - v.tab_thickness) / 2 }
    end,
}
```

- `nominal` is the intended value; `minus` and `plus` (zero or more) say
  how far below and above it the real value may be. A range like "15 to
  45 °C, usually 30" is nominal 30, minus 15, plus 15.
- `condition = true` marks an input nobody can make more exact — the
  temperature, the wearer's eye spacing. The report lists conditions apart
  from parts: parts are what to tighten, conditions what the design must
  absorb.
- `from` says where the number came from: a datasheet, `docs/sizes.md`, or
  `guess:` and why. A guess is allowed; an unsourced number is not.
- `unit` is one of: `mm`, `mm2`, `mm3`, `um`, `deg`, `arcmin`, `mrad`,
  `C` (degrees Celsius), `per-C`, `GPa`, `MPa`, `g`, `ratio`, `count`,
  `percent`. Formulas do their own conversions, said in a comment.
- An output may have `at_least` or `at_most` (a limit it must keep), or
  neither (worked out for information).

## What is worked out
| Name | Meaning |
|---|---|
| nominal | every input at its nominal |
| worst case | the lowest and highest the output takes over every combination of input extremes (2ⁿ corners). Exact when the output only rises or only falls with each input; a formula that turns round inside a range needs a note |
| spread | the root-sum-square: each input alone moved to its lowest and to its highest, the larger of the two changes taken, those combined as if independent. Centred on the output with every input at the middle of its range. Outputs that can be off either way should keep their sign and have a limit on each side (`at_least` and `at_most` together), rather than being made into a size, which bends back at zero |
| share | each input's part of the spread, in percent: what to tighten first |
| verdict | pass or fail against the limit, for the worst case and for the spread separately |

No randomness: the same file always gives the same numbers.
