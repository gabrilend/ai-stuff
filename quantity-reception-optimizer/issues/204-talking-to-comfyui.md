# 204 — Talking to ComfyUI

## Current behavior

Nothing exists. Needs `201`. What happens when the pointer leaves
before a picture is finished is open question 10 in `docs/008`.

## Intended behavior

**Submit a graph, know when it is done, fetch what it made.** The sequence is
in `docs/005-datapath-the-picture.md`. The server address
(`192.168.0.88:8188`) is a setting.

- **submit** — `POST /prompt` with the API-format graph; ComfyUI answers with a
  prompt id (string)
- **watch** — poll `GET /history/<prompt id>` until it lists outputs, at an
  interval from the settings file. (ComfyUI also offers a websocket that pushes
  progress; polling is chosen first because it needs nothing beyond
  `luasocket`'s plain HTTP.)
- **fetch** — for a picture, `GET /view` with the output's filename, subfolder
  and type; for text (the language-model route in `303`), the string the
  `PreviewAny` node left in the history entry
- **cancel** — `POST /queue` with a delete list for a waiting prompt,
  `POST /interrupt` for a running one. When cancelling is used depends on
  open question 10.

The same client serves both of `303`'s uses (writing the analogy) and `402`'s
(drawing it). It is the only code in the project that speaks HTTP to ComfyUI.

The host must keep answering messages while ComfyUI works — a middle-click
re-roll that waits behind a polling loop feels broken. So ComfyUI work runs off
the main message loop: as a coroutine the loop resumes between messages, or on
a worker thread (the monorepo's `libs/lua/effil` or `my-libs/threadpool`).
Which is chosen, and why, goes in `docs/005`.

The finished picture travels to the extension by whichever transport `201`
settled on, as a `picture` message.

## Suggested implementation steps

1. `src/` — the ComfyUI client: submit, poll, fetch picture, fetch text,
   cancel.
2. Rework the host's loop so ComfyUI work does not block messages.
3. Tests without ComfyUI: a stand-in server that takes a prompt, finishes it
   after a delay, returns either an image or a text output, and records cancels.
4. Tests with the server: a small fixed graph (one prompt, one picture) submitted,
   watched and fetched; the PNG opens. The real graphs arrive in `402`.

## Related

`docs/005-datapath-the-picture.md` · `docs/006-datapath-the-bridge.md` ·
`docs/008-open-questions.md` (10) · needs `201` · blocks `205`, `303`, `402`, `403`,
`404`, `504`
