# 059-test-project-clone — info

Tests the clone keeper (issue 501, `src/058-project-clone.lua`) on
throwaway git repositories standing in for kuvalu's checkout, made in
`/dev/shm` so that clones placed in RAM really are (where there is no tmpfs
there, the RAM cases say so through the keeper's filesystem seam).

    luajit src/059-test-project-clone.lua --dir ROOT

- **The keeper**: a first clone in RAM, sparse, with the other folders'
  files never fetched; the same commit again; a newer commit fetched; an
  older one checked out with no fetch; a project switch and back; a RAM
  clone lost and made again; on disk when too big for the share, when the
  RAM folder is not a tmpfs, and when it cannot be made, each saying why;
  a clone measured bigger once made, moved to disk; refusals; the SSH
  command; `scripts/project-clone`.
- **The turn's step 2**: the log line and counts, and a turn with no clone
  that goes on.
- **The rehearsal** with the real turn against a stand-in model (047): each
  voice clones once and keeps its clone, and a commit made while it runs
  is fetched by the voices.

About 30 seconds. `KEEP=1` keeps the throwaway folder after a failure.
