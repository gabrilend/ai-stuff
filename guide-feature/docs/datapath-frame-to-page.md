# Datapath: from a frame to the page

How one frame written on an fg-sora machine becomes part of the page, and how
the page travels back. This is the current design; the issue that changes it
updates this file.

## The path

    fg-sora-N                         kuvalu
    ─────────                         ──────
    thinker
      │ rewrites outbox/frame
      ▼
    rmail daemon ──── encrypted ────► rmail daemon (mailbox "guide", port 1223)
    (port 10101/20202/30303)            │ first frame:  on_receive hook
                                        │ later frames: on_update hook
                                        ▼
                                      arrival hook script
                                        │ writes the frame text into the
                                        │ arrivals folder, by rename
                                        ▼
                                      tmp/shared-memory/arrivals/
                                        │
                                        ▼
                                      page keeper (running Lua program)
                                        │ 1. reads and checks the frame
                                        │ 2. replaces that voice's frame
                                        │ 3. measures what was carried forward
                                        │ 4. updates every thought's relevance
                                        │ 5. builds page N+1
                                        ├──► tmp/shared-memory/page/current + history/
                                        ├──► page server (HTTP) for remote viewers
                                        └──► rewrites outbox/the-page (to all 3 voices)
                                                │
    rmail daemon ◄──── encrypted ───────────────┘
      │ on_update (or on_receive the first time)
      ▼
    inbox/the-page   ◄── the thinker reads this before its next frame

## Step by step

1. **Writing.** The thinker writes the complete new frame
   (`docs/frame-format.md`) into its mailbox's `outbox/frame`, under the
   `to: guide` line. It writes to a temporary name in the same folder and
   renames it over `frame`, so rmail never reads half a file.
2. **Carrying.** rmail notices the change at once, and sends it when kuvalu's
   timer for that voice comes due (at most every 30 seconds or so; see
   `docs/rmail-constraints.md`).
3. **Hooking.** On kuvalu, rmail runs the arrival hook. For the first frame
   from a voice it is `on_receive`, given the inbox file's path. For every
   later frame it is `on_update`, given the new body as an argument. Either
   way, the hook writes the frame text to
   `tmp/shared-memory/arrivals/<sender>-<unix time>-<random>` by writing a
   temporary name and renaming it. Then it exits, printing nothing. Printing
   nothing tells rmail to keep the new body as it is.
   The hook does no checking and no deciding, because `on_update` holds up
   rmail while it runs. Its whole job is "put this where the page keeper will
   see it".
4. **Taking.** The page keeper watches the arrivals folder. It takes files in
   name order (which is arrival time order), and deletes each one only after
   it has been taken into the keeper's state. A frame that fails its checks is
   moved to `tmp/shared-memory/arrivals-refused/` with a line in the log saying
   why. It is never silently dropped.
5. **Deciding.** The page keeper replaces that voice's current frame with the
   new one and recomputes relevance (`docs/datapath-relevance.md`).
6. **Publishing.** If any thought's relevance or text changed, the page number
   goes up by one and the page is written three ways:
   - `tmp/shared-memory/page/current` (by rename) and
     `tmp/shared-memory/page/history/NNNNNN`;
   - handed to the page server, which wakes any viewer waiting on
     `GET /page?after=`;
   - written as the body of kuvalu's `outbox/the-page` (by rename), under
     three `to:` lines, one per voice, so rmail carries it back as a living
     message.
7. **Reading back.** On each fg-sora, rmail updates `inbox/the-page`. The
   thinker reads it before writing its next frame.

## What lives where

| Data | Where | Type |
|---|---|---|
| A frame in flight | each fg-sora `outbox/frame`, then kuvalu `inbox/<voice>-frame` | plain text file |
| A frame waiting for the page keeper | `tmp/shared-memory/arrivals/` on kuvalu | plain text file, one per arrival |
| Every thought and its relevance | page keeper's memory | a list of thought records, see `docs/datapath-relevance.md` |
| The page | `tmp/shared-memory/page/`, page server memory, kuvalu `outbox/the-page`, each voice's `inbox/the-page` | plain text, `docs/page-protocol.md` |
| Run log | `tmp/shared-memory/page-keeper.log` | plain text lines |
| Goodbye receipt | `output/goodbye` | plain text |

Everything under `tmp/shared-memory/` is RAM, and a reboot empties it. Pages
from an earlier run are therefore gone after a restart. Whether a run should
start from the last page of the previous run is an open question
(`docs/open-questions.md`).
