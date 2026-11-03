# todone-similarity.lua

Issue 053b, tiers 1-4: which of the components `todone.lua` found are the
same thing under different names, with a confidence for each.

```
todone.lua --all --json --each > found.json
todone-similarity.lua found.json                  # tiers 1-3, no model
todone-similarity.lua found.json --max-tier=4     # and ask the model about uncertain pairs
todone.lua --all --json --each | todone-similarity.lua - --json
```

| Tier | Joins | Confidence |
|------|-------|------------|
| 1 | the same name once case, spaces, `-` and `_` are ignored | 1.0 |
| 2 | names on one line of `config/component-synonyms.conf` | 0.95 |
| 3 | a likely typo: 1 letter apart (5+ letters) or 2 apart (9+ letters) | 0.8 |
| 4 | the local model says **yes** about an uncertain pair | 0.85 |

- **Uncertain pairs** (tier 4) are names that share a word of 4+ letters, one
  inside the other, or 3 letters apart. At most `--max-asks` (20) are asked.
- **Nothing doubtful is merged.** A *maybe*, an unclear answer or a model
  error leaves the pair apart and lists it under "uncertain" for a person to
  judge (a maybe at 0.5). If the server cannot be reached, the rest are not
  asked and tiers 1-3 still stand. Any failed pair makes the exit status 1.
- **A member's confidence** is the weakest link between it and the cluster's
  first member (the name most projects plan), so a typo of a synonym is 0.8.
- **Clusters** are any group with two names or two projects; a cluster
  planned by `--min` projects (default 2, as in `todone.lua`) is a library
  candidate. Names only one project plans are listed as unclustered.
- **Output** is a text report, or with `--json` the issue's format:
  `clusters`, `unclustered`, `uncertain` and `analysis_stats` (counts by tier).
  Nothing is written anywhere.
- Tier 5 (a large model given code and descriptions) is not built.

Tested by `test-todone-similarity.sh` (34 checks). The model questions go to
the stand-in server in `libs/stand-in-model/`, run with a small brain the
test writes for itself, so the shared `brain.lua` is unchanged.
