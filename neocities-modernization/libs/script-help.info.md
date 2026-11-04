# script-help (libs/script-help.lua, libs/script-help.sh)

`--help` (or `-h`) for every script, printed from the script's own header
comment, before the script does any work.

## Use

At the top of a Lua script, after its header:

```lua
dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/script-help.lua").handle(arg)
```

At the top of a bash script, after its header:

```bash
source "$(dirname "$(readlink -f "$0")")/../libs/script-help.sh"
script_help "$0" "$@"
```

(`libs/` instead of `../libs/` for a script in the project folder.)

## Functions

| function | takes | returns |
| --- | --- | --- |
| `header(path)` (Lua) | a script's path | its leading comment block: after the `#!` line, every comment line up to the first non-comment line, fold markers left out, comment marks stripped; an error when there is none |
| `handle(args)` (Lua) | the script's `arg` | prints the header and exits 0 when `--help` or `-h` is among the arguments; otherwise returns |
| `script_help "$0" "$@"` (bash) | the script and its arguments | the same, through `header` |

## Test

`scripts/script-help.test.sh`: every script can answer `--help`, and
answering prints its header and exits 0 within 15 seconds. A script without
a help call is reported and never run.
