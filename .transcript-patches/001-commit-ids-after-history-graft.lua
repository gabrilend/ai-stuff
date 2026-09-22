-- The trunk's history was rebuilt on 2026-09-22 so the first commit stands on
-- each project's pre-monorepo commits (delta-version issue 031), which gave
-- every trunk commit a new id. Transcripts quote commit ids, and the session
-- logs they are rendered from keep the old ones, so every re-export would put
-- the old ids back. This translates them through the graft's map on every
-- export. The originals stay reachable through the archive tags, and
-- `transcript-patches original <transcript>` shows a transcript as it was
-- rendered before this patch.
return {
   id         = "001",
   date       = "2026-09-22",
   reason     = "commit ids quoted in transcripts name the rebuilt history after the 2026-09-22 graft",
   applies_to = "all",
   kind       = "commit-map",
   map        = "delta-version/archive/history-graft/commits.map",
}
