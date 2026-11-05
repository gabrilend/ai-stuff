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
- **From a package registry** (noble-ciphers, noble-hashes, 803): the files
  a project needs from one exact released version, copied unchanged into
  `libs/<name>/`, beside `libs/<name>.upstream`. The note gives the tarball's
  address, the version, the registry's published integrity (which the
  tarball was checked against before use) and each file's SHA-256. There is
  no local upstream, so `scripts/refresh-vendored` only names them. A
  refresh is by hand: fetch the newer tarball, check its integrity, copy the
  same files, rewrite the note.
- **A single file** (a Lua library): copied into `libs/` beside a
  `<file>.upstream` note giving the source path, the source's commit at
  copy time (the last commit that touched the file), the date, and
  `changes:`, either `none` or what this project changed in its copy.
  `scripts/refresh-vendored` copies every file again from its upstream,
  shows the differences, and writes the new commit into the note. It never
  runs on its own.
  - It shows the upstream's own changes since the note's commit.
  - A copy with `changes: none` is replaced by the source as committed.
  - A copy with changes of its own is merged three ways (`git
    merge-file`), so the upstream's changes are carried into this
    project's copy. A merge with conflicts is left beside the copy as
    `libs/<file>.merge`, with the copy and its note untouched, for a
    person to settle.
  - `--check` only says which copies are behind.

## What is planned to be copied

| Copy | Upstream (local) | Why | Issue |
|---|---|---|---|
| `libs/llama.cpp/`, a git clone | `/home/ritz/programming/ai-stuff/words-pdf/libs/llama.cpp` (a llama.cpp clone with a CUDA build, last commit 2026-06-20) | guide-feature runs its own llama.cpp servers, built and started by its own scripts | 401a |
| `libs/llama-chat-client.lua` | `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/libs/llama-chat-client.lua` (commit f12d85693); copied 2026-11-05 with this project's changes made in the copy and listed in its `.upstream` note: an endpoint record per call (no configured address, no environment override), an embedding call, dkjson found beside it | chat, exact token counts, reachability, embeddings | 401b |
| `libs/dkjson.lua` | `/mnt/mtwo/programming/ai-stuff/libs/lua/dkjson.lua` (commit 472e9b9de); copied unchanged 2026-11-05 | the client's JSON reader and writer | 401b |
| `libs/bitmap-font.lua` | `/mnt/mtwo/programming/ai-stuff/every-software-image-able/src/068-bitmap-font.lua` (commit 70c79f3e8); copied unchanged 2026-11-05 | the Lua window's letters: 8x8 pictures in plain Lua, so the window needs no font library. The printable characters it lacks are drawn in `src/072-lua-window.lua`, keeping the copy unchanged | 802 |
| `libs/noble-hashes/` (eight files) | `@noble/hashes` 1.8.0 from the npm registry (`https://registry.npmjs.org/@noble/hashes/-/hashes-1.8.0.tgz`), the tarball checked against the registry's published integrity, copied unchanged 2026-11-05; the files, their hashes and the integrity are in `libs/noble-hashes.upstream` | PBKDF2-HMAC-SHA256 in plain JavaScript: the key is made from the password in the browser, so the password never crosses the network | 803 |
| `libs/noble-ciphers/` (four files) | `@noble/ciphers` 1.3.0 from the npm registry, checked the same way, copied unchanged 2026-11-05; `libs/noble-ciphers.upstream` | AES-256-GCM in plain JavaScript, no dependencies: browsers have no built-in decryption on plain HTTP | 803 |
| `libs/ensure-ram-tiers.lua` and `libs/ensure-ram-tiers` | `/mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers.lua` (commit 2cd0a5bfd) and the bash library it calls, `.../scripts/libs/ensure-ram-tiers` (commit 9e9117fe5); copied unchanged 2026-11-05, each beside its `.upstream` note. The Lua file is always handed this project's root as its `scripts_dir`, so its default path into the monorepo is never used | rebuilding the `tmp/` RAM folders after a reboot; the bash library is where the layout is written down, so the Lua file needs it beside it (and jq) | 101 |

guide-feature is itself an upstream for one file: another project that
wants an embedding index copies `src/060-embedding-index.lua` (the piece and
name rules and the index's files) into itself, beside a `.upstream` note
naming guide-feature, as `docs/embedding-index-build-guide.md` says.

Each row is filled in with the real path and commit when its issue copies
it. Words-pdf's own server is words-pdf's business. That it should start
and stop with words-pdf is the owner's note about words-pdf, not something
this project relies on.
