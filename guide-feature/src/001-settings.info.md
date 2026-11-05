# 001-settings — info

How every guide-feature program reads its settings: from one file in
`input/`, named after the program, in the same `name = value` lines as rmail's
`contacts` and this project's `endpoints` file. Issue 101 is the blueprint.

## The file

    # a comment, on its own line or after a value
    canvas-size   = 80x24                 # WxH: bare, columns x rows
    mark-lifetime = 12                    # whole: bare
    fade          = 0.5                   # decimal: bare
    merge-mode    = "newest"              # choice: quoted, one of a fixed set
    title         = "say \"hi\" \\ bye"   # text: quoted; \" and \\ only
    voices        = "fg-sora-1 fg-sora-2" # names: quoted, spaces or commas

Text, choices and lists are always quoted. Numbers and sizes never are. Being
strict both ways means a mistyped number cannot quietly turn into text.

## Why nothing has a default

Every value a program runs with is in its input file, where the person can see
it. A setting the program can do without is declared optional, and when it is
left out the program gets `nil`, never a number chosen in code.

## What it exports

| Name | Type | Meaning |
|---|---|---|
| `read(program, declared, opts)` | function | `input/<program>` checked against `declared`; returns settings (name to value) and the line each was set on. `opts.root` is the project root |
| `read_endpoints(opts)` | function | the project-root `endpoints` file, grouped as `{ endpoints = { name = { url, kind, ... } }, use = { role = name } }`, with each endpoint's url and kind and each role's target and kind checked |
| `parse(text, source)` | function | the lines that set something, `{ name, value, kind, line }`, with no declarations |
| `check(entries, declared, source)` | function | parsed lines against declarations |
| `TYPES` | table | type name to a parse-and-check function: `whole`, `decimal`, `text`, `WxH`, `names`, `choice` |
| `ENDPOINT_FIELDS` | table | the endpoints file's declarations |
| `ensure_tiers(root)` | function | the RAM tiers, once per root per process |
| `NAME_PATTERN` | string | what a name may hold: letters, digits, `.`, `_`, `-` |

A declaration is `name = { type = ..., required = true|nil, of = {...} }`
(`of` for a choice). A name with a `*` in it stands for any one part of a
name (`*.url`, `use.*`). Where two patterns match, the one with the longer
fixed start wins, so `use.url` is a role, and no endpoint may be called `use`.

## Refusals

Every refusal is a Lua error whose message starts with the file, and the line
when there is one: `input/blitter:4: 'merge-mode' must be one of "newest",
"distill", in double quotes; found "newst"`. Refused: a missing file, a line
that is not `name = value`, a bad name, no value, an unclosed quote, an
unknown escape, text after the value, an unknown name, a name set twice, a
value of the wrong type, and a required name not set. A program's own bad
declaration (an unknown type, a choice with no words) is refused as the
program's fault, before its file is read.

## The RAM tiers

Reading makes sure of `tmp/` and `tmp/shared-memory/` first, through
`libs/ensure-ram-tiers.lua` (`docs/vendored-code.md`), once per root per
process, because the blitter reads its settings on every arrival.

Tests: `003-test-settings.lua`.
