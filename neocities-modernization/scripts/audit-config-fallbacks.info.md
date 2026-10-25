# audit-config-fallbacks.info.md

Lists the places where a program reads a setting and writes its own
fallback beside it (`config.pagination.size or 5`). The owner's rule, Issue
10-071: defaults live only in config.lua. The sister tool
`scripts/audit-config-keys` finds the other side, settings in config.lua that
no program reads.

    scripts/audit-config-fallbacks [DIR]             report, grouped by file
    scripts/audit-config-fallbacks [DIR] --count     totals only
    scripts/audit-config-fallbacks [DIR] --declared  also list the declared ones

Exit status: 0 when nothing undeclared is found, 1 otherwise. It runs in the
test suite through `scripts/audit-config-fallbacks.test.sh`, which also
requires this project to stay at 0.

## What it reports

| kind | shape | what to do |
|---|---|---|
| value | `x.size or 5`, `x.name or "default"`, `x.on or true` | make it an error naming the setting, and put the value in config.lua |
| section | `config.layout or {}` | the section is required (make it an error) or optional (declare it) |
| declared | either shape, with a comment containing `optional:` and the reason on the same line or the line above | nothing; listed with `--declared` |

A "setting" is a name chain whose first word is one of the names the code
uses for config: `config`, `cfg`, `conf`, `settings`, `options`, `opts`,
`unified_config`, and aliases such as `wc` (word_cloud), `privacy`,
`layout`, `pagination`, `server`, `model_config`, `mc`, `sources`. The list
is `SETTING_ROOTS` at the top of the script; add an alias there when the
code grows one.

It reads the tracked Lua files and shell scripts (git decides which), with
comments stripped (`--` outside a string; whole `#` lines). Tests, the
transcripts, the word-cloud archive and vendored libraries under `libs/*/`
(except `libs/vulkan-compute/`) are left out.

A candidate list, not a verdict: an alias it does not know is missed, and a
local table that merely looks like settings is reported.
