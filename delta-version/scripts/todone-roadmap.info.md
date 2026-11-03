# todone-roadmap.lua

The second slice of issue 053 (053c). It takes the components that several
projects each plan to build, as `todone.lua` reports them, and works out
the order to build them in. It also says what each project waits on.

```
todone.lua --all --json > /tmp/todone.json
todone-roadmap.lua /tmp/todone.json                  # Markdown
todone-roadmap.lua /tmp/todone.json --json
todone.lua --all --json | todone-roadmap.lua -       # straight from todone
todone-roadmap.lua /tmp/todone.json --out=/tmp/shared-roadmap.md
```

**Facts beyond todone's** are in `config/shared-components.conf`, one per
line:

```
llm client: needs http client, threadpool
threadpool: complexity high        # low 5 h, medium 20 h, high 50 h, very high 100 h
threadpool: home libs/lua/threadpool
```

Names are matched as todone matches them: by spelling, and through
`config/component-synonyms.conf` (`libs/component-names.lua`). A component
that a shared one needs is built too, even when no two projects share it.
A component with no complexity line is taken as medium, and the roadmap
marks that as a guess. A line of an unknown kind is refused, with its line
number.

**Worked out, with no model:**

| What | How |
|------|-----|
| priority | usage × 2 + dependents × 1.5 + hours × 0.5 (the issue's formula; dependents counts everything that needs it, directly or not) |
| phases | shared phase 1 is what needs nothing; each later phase is what needs only earlier phases; higher priority first within a phase |
| cycles | named, and their members are left out of the order; the rest is still ordered |
| effort | built once: hours, plus 2 for each project to fit it in. Built alone: hours × projects |
| projects | which components each project waits on, and after which phase it has them all |

Output is printed. `--out=FILE` saves it, and never replaces an existing
file.

Tested by `test-todone-roadmap.sh` (30 checks). One check pipes `todone.lua`
in through the stand-in model in `libs/stand-in-model/`.
