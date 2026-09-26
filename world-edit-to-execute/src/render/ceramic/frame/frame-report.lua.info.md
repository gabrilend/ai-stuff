# frame-report.lua

Reads `frame.tsv`, `frame-bounds.tsv` and `frame-loc.tsv`, and fails if the
runs disagree on the checksum. It writes `frame.md` and fills
`src/viewers/ceramic-frame.html` with:
- the kit and the rows;
- the plan's constants, read from `frame-plan.h`;
- the floor, the code counts, and the machine (including its power governor
  and idle clock).

Usage: `luajit frame-report.lua [OUT DIR]`.
