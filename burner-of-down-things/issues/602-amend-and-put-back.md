# 602 — Amend and put back

Writing a request into the blueprint, and restoring the blueprint when that
fails ([008](../docs/008-datapath-the-update.md)).

## Current Behavior

A request can be graded; nothing changes the blueprint.

## Intended Behavior

- **Amend** (case, request, touched): copies each touched issue file (and
  the outline) into the amend turn's folder first; one `amend` turn whose
  prompt holds the request, the touched issues whole, and the outline; it may
  edit touched issues, add new issue files, and add rows to the outline.
- After it: the outline checks (401) and each changed or new issue's checks
  (403). Failing → a new amend turn given the findings, up to three; the
  third failure puts every copied file back, removes any new issue file, and
  appends `request-failed`.
- New issues get `described` lines; the graph is rebuilt.

## Suggested Implementation Steps

1. **Test:** a stand-in amend that edits one issue's Intended Behavior passes;
   the file changed, nothing else did.
2. **Test:** three bad amends leave the blueprint byte-identical to before.

## Blocked by

- 601
- 403
