# ceramic-analysis.html

The first ceramic report: the stock engine's performance analysis (issue
515a). `analysis-report.lua` fills `/*@@DATA@@*/[]` (the measurement rows)
and `/*@@MACHINE@@*/{}` (the processor). The filled page draws everything
offline, with hand-built SVG and no libraries:
- the frame-budget bars;
- the units-per-task curve, with a mean / 99th percentile toggle;
- where a task's time goes;
- the herd experiment;
- core scaling;
- army size;
- answer size;
- steadiness;
- the findings for soramech.

Every number shown is computed from the rows.
