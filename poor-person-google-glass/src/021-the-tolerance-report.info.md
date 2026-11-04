<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 009 (tolerance calculations): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 021-the-tolerance-report

Reads a results file (written by 022) and nothing else, and writes the page for people: answers with worst case, spread, limit and verdicts; what to tighten (parts) and what to absorb (conditions); the inputs with their sources.

| Offers | Takes | Gives |
|---|---|---|
| `write(results_path)` | output/calculations/NAME.results.lua | the report's markdown text |
