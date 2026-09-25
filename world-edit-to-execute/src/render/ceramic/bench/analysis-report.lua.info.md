# analysis-report.lua

Reads `tmp/shared-memory/ceramic/analysis.tsv` and writes into the same
folder:
- `analysis.md`: one table per sweep, with derived numbers;
- `analysis.json`: the rows;
- `ceramic-analysis.html`: the viewer `src/viewers/ceramic-analysis.html`
  with the rows and this machine's processor filled in.

It fails if any pose-computing way's checksum disagrees with the one-thread
loop. Usage: `luajit analysis-report.lua [TSV] [OUT DIR]`.
