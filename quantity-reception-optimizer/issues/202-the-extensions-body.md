# 202 — The extension's body

## Current behavior

Nothing exists. Needs the measuring script from `103` and the host from `201`.

## Intended behavior

**A Firefox extension that watches the pointer, sends hover records to the
host, and passes back what the host says.** It thinks about nothing.

Three parts:

- **the manifest** — names the extension, asks for the permissions it needs
  (all pages, native messaging, storage only if `203` requires it), and lists
  the scripts below
- **the content script** — runs inside every page. Loads the measuring code
  from `103` unchanged. When the pointer enters a new word, sends a
  hover record with a fresh `hover_id`; when the pointer leaves the word, sends
  `left` for that id
- **the background script** — the only part allowed to hold the native
  messaging connection. Opens it once, forwards messages from content scripts
  to the host and answers back to the tab that asked, keyed by `hover_id`

**One hover in flight per tab.** A new hover in the same tab sends `left` for
the previous one first, so the host never draws for a pointer that has moved on.

**When the host is not installed or dies**, the background script reports it
in the browser console and to the page as an `error` message; it does not
retry silently.

## Suggested implementation steps

1. `src/extension/` — manifest, content script, background script. The
   measuring file is referenced from where `103` keeps it, not copied.
2. Load it as a temporary add-on (`about:debugging` → This Firefox → Load
   Temporary Add-on) and confirm the host starts — it writes to its log on
   start.
3. Hover a quantity on a real page; confirm the host's log shows the record and
   its answer.
4. Measure round-trip time from the content script sending `hover` to
   receiving the answer; the phase demo reports it.

## Related

`docs/002-datapath-the-hover.md`, `docs/006-datapath-the-bridge.md` · needs
`103`, `201` · blocks `203`, `205`, `501`
