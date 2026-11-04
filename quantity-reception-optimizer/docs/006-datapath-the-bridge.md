# 006 — Datapath: the bridge

How the extension and the host talk. (The host's other connection, to the
ComfyUI server at `192.168.0.88:8188`, is plain HTTP and is described in
[the picture datapath](005-datapath-the-picture.md); both connections are
built in phase 2.)

```
content script ──► background script ──► native messaging pipe ──► host (LuaJIT)
     panel     ◄──  background script ◄──  native messaging pipe ◄──  host
options page   ──►  background script ──►  (settings message)   ──►  host writes settings file
```

## Native messaging

Firefox starts the host itself, as a child process, the first time the
extension asks to connect. It finds the program through a small JSON manifest
installed at `~/.mozilla/native-messaging-hosts/<name>.json`, which names the
executable and which extension is allowed to talk to it.

Each message, in both directions, is four bytes giving the length of what
follows (in the machine's own byte order) and then that many bytes of UTF-8
JSON. Messages from the host to Firefox may not exceed 1 MB, which matters for
pictures: a picture is sent as a file path inside the shared-memory folder and
the background script reads it — or, if Firefox will not read local files, as
base64 split across several messages. Which of these works is the first thing
the bridge issue must establish.

## Messages

Every message is a JSON object with a `type` field. The host answers by looking
the type up in a table of handlers.

| Type | Direction | Carries |
|---|---|---|
| `hover` | page → host | a hover record ([002](002-datapath-the-hover.md)) and a `hover_id` (integer) |
| `left` | page → host | the `hover_id` the pointer left; cancels its work |
| `reroll` | page → host | the `hover_id` to try again for; sent on a middle-click over the quantity or its panel |
| `no_quantity` | host → page | the `hover_id`; nothing is shown |
| `analogy` | host → page | the `hover_id` and the analogy record, sent before the picture so the sentence can appear at once |
| `picture` | host → page | the `hover_id` and the picture |
| `exhausted` | host → page | every kind has been shown for this hover |
| `settings_get`, `settings_put` | options page ↔ host | the settings table |
| `recent_pictures` | menu page ↔ host | the list of recently shown pictures, with sentence, quantity and page |
| `picture_bytes` | menu page ↔ host | one picture, for saving through Firefox's downloads |
| `error` | host → page | a message for the panel and the log; never silent |

## The host's life

When Firefox starts it, the host first reads `input/` (the settings file lives
there), then serves messages until the pipe closes, then writes `goodbye` to
`output/`. Everything it does is logged to `tmp/shared-memory/host.log`, and it
rebuilds the RAM folders behind `tmp/` before writing, since a reboot empties
them.
