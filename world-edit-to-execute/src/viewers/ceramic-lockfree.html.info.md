# ceramic-lockfree.html

The second ceramic report (issue 515g), written for the soramech
developers. It covers the stock task queue's cost, the lock-free ring's
design (the slot states and who owns each, the hand-in and take-out steps,
the sleep and wake ordering, batching, spinning, a full ring, landing), what
it measured (bars, units per task, workers, the landing check), and what it
costs (the guarantees it bends). It is a template filled by
`src/render/ceramic/bench/analysis-report.lua` with the kit and the rows.
