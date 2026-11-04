# todone.lua

The first slice of issue 053 (TODONE): which building blocks several
projects are each planning to build on their own.

```
todone.lua --all                               # every top-level folder with issues/
todone.lua world-edit-to-execute symbeline-realms soren-ds --min=2 --each
todone.lua --all --json
```

**What it reads.** For each project, the titles of its open issues (not
`completed/`, `done/`, `archive/` or `moved-` pointers) and the headings of
`docs/roadmap.md`. The local model (`libs/llama-chat-client.lua`) lists the
reusable components that work plans: a threadpool, a TUI framework, a
JSON parser and the like. It is told to leave out project-specific
features.

**How names are matched:**
1. **Tier 1, spelling:** case, spaces, `-` and `_` are ignored, so
   ThreadPool, thread-pool and thread_pool are one component.
2. **Tier 2, synonyms:** names listed together in
   `config/component-synonyms.conf` are one component, reported under the
   first name.

**What it reports.** Every component planned by at least `--min` projects
(default 2), with those projects: the list of things worth building once.
`--each` adds what was found in each project. Nothing is written anywhere.
A project the model fails on is named, and the rest are still reported
(exit 1).

Tested by `test-todone.sh` (23 checks) against the stand-in model in
`libs/stand-in-model/`.
