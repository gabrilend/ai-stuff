# ask-for-value.lua

Settles a value that a program needs but was not given on its command line:
asks the person, takes the default under `--yes`, or stops with an error.
Issue 10-065a.

## Functions

### `resolve(spec) -> value`

`spec` is a table:

| Field | Type | Meaning |
|---|---|---|
| `flag` | string | the command-line flag that supplies the value, used in messages (`"--words"`) |
| `question` | string | what to ask (`"How many words in the word cloud?"`) |
| `kind` | string | `"count"` (whole number of 1 or more), `"count_or_all"` (that, or the word `all`), `"pages"` (a whole number of pages per poem, or `all`, returned as text -- the form the page builder reads), `"yesno"` |
| `given` | number, string, boolean or nil | the value from the command line; nil when absent |
| `default` | number, string, boolean or nil | what Enter and `--yes` take; nil when there is none |
| `default_source` | string | where the default came from, for the `--yes` notice (`"config.lua word_cloud.max_words"`) |
| `accept_defaults` | boolean | `--yes` was given |

Returns a number, the string `"all"`, or true/false, depending on `kind`.
The first situation that applies decides:

| Situation | Result |
|---|---|
| `given` is set | `given` |
| `accept_defaults` | `default`, with one line on the error stream: `--yes: using 200 for --words (config.lua word_cloud.max_words)`. No default: error |
| environment `NEOCITIES_NO_PROMPTS=1` (set by `run.sh`) | error: run.sh should have passed the flag |
| standard input is not a terminal | error naming the flag and the default it would have used |
| otherwise | asks `question [default]` on the error stream. Enter takes the default; an unusable answer is asked again with what is accepted; end of input is an error |

### `wants_defaults(args) -> boolean`

Whether `--yes` or `-y` is among `args` (normally the program's `arg`).

### `set_terminal(replacements)`

For tests. Replaces any of `is_terminal()`, `read_line()`, `write(text)` and
`env(name)`; fields left out keep their real behaviour.

## Why it is shaped this way

- Questions and notices go to the error stream, so a program whose normal
  output is piped still shows them.
- Each program settles a value where it is first used, not when it loads, so a
  mode that does not need the value (or `--help`) never asks.
- The default shown in brackets comes from `config.lua`; the change from the
  old behaviour is that it is shown and confirmed, never applied silently.

## Test

`libs/ask-for-value.test.lua` drives every situation above with a scripted
keyboard and screen.
