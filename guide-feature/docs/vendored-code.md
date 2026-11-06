# Code this project keeps its own copy of

The owner: "We will be implementing our own server for this project, no
cross-project interrequirements are encouraged. When needed and possible, we
should create a git upstream to one of our local directories containing the
project, so we can update the project-specific implementation by copying from
the local directory."

So guide-feature never runs, sources or links another project's files.
Anything it reuses is copied into this project, with a note of where it came
from. Updating it is a deliberate act: copy from the upstream again, read
the difference, keep or adapt.

## Two kinds of copy

- **A whole project** (llama.cpp): a git clone inside `libs/`, whose `origin`
  remote is the local folder it was cloned from. `git -C libs/<name> pull`
  updates it from that folder. The clone has its own `.git`, and the
  monorepo ignores its folder, so the monorepo records only which commit it
  is at (in `libs/<name>.upstream`), not the code itself.
- **A single file** (a Lua library): copied into `libs/` beside a
  `<file>.upstream` note giving the source path and the source's commit at
  copy time. `scripts/refresh-vendored` copies every file again from its
  upstream, shows the differences, and writes the new commit into the note.
  It never runs on its own.

## What is planned to be copied

| Copy | Upstream (local) | Why | Issue |
|---|---|---|---|
| `libs/llama.cpp/`, a git clone | `/home/ritz/programming/ai-stuff/words-pdf/libs/llama.cpp` (a llama.cpp clone with a CUDA build, last commit 2026-06-20) | guide-feature runs its own llama.cpp servers, built and started by its own scripts | 401a |
| `libs/llama-chat-client.lua` | `delta-version/scripts/libs/llama-chat-client.lua` | chat, exact token counts, reachability | 401b |
| `libs/dkjson.lua` | `/home/ritz/programming/ai-stuff/libs/lua/` | the client's JSON reader and writer | 401b |
| noble-hashes (a slow password-to-key function in plain JavaScript), for the HTML page's password prompt | its published source, copied in when 803 is built | the key is made from the password in the browser, so the password never crosses the network | 803 |
| noble-ciphers (AES-256-GCM in plain JavaScript, no dependencies), for the HTML page | its published source, copied in when 803 is built; the path and version go here then | browsers have no built-in decryption on plain HTTP | 803 |
| `libs/ensure-ram-tiers.lua` and `libs/ensure-ram-tiers` | `/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers.lua` (commit 2cd0a5bfd) and the bash library it calls, `.../scripts/libs/ensure-ram-tiers` (commit 9e9117fe5); copied unchanged 2026-11-05, each beside its `.upstream` note. The Lua file is always handed this project's root as its `scripts_dir`, so its default path into the monorepo is never used | rebuilding the `tmp/` RAM folders after a reboot; the bash library is where the layout is written down, so the Lua file needs it beside it (and jq) | 101 |

Each row is filled in with the real path and commit when its issue copies
it. Words-pdf's own server is words-pdf's business. That it should start
and stop with words-pdf is the owner's note about words-pdf, not something
this project relies on.
