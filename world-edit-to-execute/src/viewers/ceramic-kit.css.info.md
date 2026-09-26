# ceramic-kit.css / ceramic-kit.js

The look and the chart code the ceramic report pages share:
`ceramic-analysis.html`, `ceramic-lockfree.html`, and the frame report.
The report tools splice them in at `/*@@KIT-CSS@@*/` and `/*@@KIT-JS@@*/`,
so every published page stays one self-contained file.

- **CSS:** colour tokens with light and dark palettes. There is one colour
  per approach: grey (one thread), slate (fixed slices), plum (shared
  counter), brick (one task per unit), teal (chunked). Amber is "handing in
  to the task queue". Plus the section, chart, key, finding and flow styles.
- **JS:**
  - `pick(sweep, way, units, workers)` returns a row; `all(sweep, way)`
    returns rows.
  - `fmtUs(µs)` and `ms(µs)` format times.
  - `svg`, `add`, `tip` and `scale` (linear or log) build drawings.
  - `lineChart(target, {x, y, series, before, after})` draws a chart with
    axes, a grid, series (a `dash` pattern gives dashed or dotted lines;
    `noDots` hides the points) and hover notes. `x` and `y` are
    `{min, max, log, ticks, fmt, title}`.

The page declares `ROWS`, `MACHINE` and `FRAME` before the kit runs.
