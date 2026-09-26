# Issue 603: Fetch Maps and Models From Public Sites

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** 604 (content-addressed storage), 605 (local storage manager), 116 and 117 (the model check)
**Blocks:** 1001 (the catalogue viewer reads what this writes)
**Formerly:** "LAN Asset Download Protocol" (`603-server-asset-download-protocol.md`,
renamed 2026-09-26); that design is kept at the end of this file

---

## Current Behavior

Nothing fetches anything. The engine plays whatever `.w3x`/`.w3m` files are
already on disk (the DAoW versions in `assets/`), and uses no models beyond
the placeholder shapes the renderer draws. No source list, catalogue format,
finder or downloader exists. There is no reader yet for WC3 model files
(`.mdx`, issue 116) or their textures (BLP1, issue 117).

## Intended Behavior

This issue is the **data-generation half** of getting community content: it
finds maps and models on the public websites that post them, and downloads
one when a player asks. The **data-viewing half**, the catalogue a player
browses, is issue 1001. The two meet only at the catalogue files this issue
writes; the viewer never fetches and the fetcher never draws.

How files reach a player, as decided:
- **From public hosting sites: over HTTP, by this issue.** The owner
  (2026-09-26): "we will still need to download files from the websites that
  are hosting the WC3 maps / models".
- **From another person: over rmail** (issue 609). The owner (2026-09-23):
  "the only connection protocol for assets that I trust". Nothing in this
  project serves files over HTTP; the file-server issue (607) was retired for
  that reason.

The parts:

- **Source list (data, reviewed by the owner before any fetching).** One
  entry per site: its name, base address, what it hosts (maps, models, or
  both), its stated terms for downloading, what its `robots.txt` allows, and
  whether it offers a feed or an API. A site whose terms forbid automated
  access is kept in the list, marked "visit by hand", and never fetched.
- **Finder.** One small adapter per source, all behind one interface: given
  a source, produce catalogue entries. It prefers a site's own feed or API
  over reading its pages, waits between requests, and follows `robots.txt`.
  Its requests identify the tool only (a user agent such as
  `world-edit-to-execute fetch`); nothing about the person running it is sent
  (see Privacy in `CLAUDE.md`).
- **Catalogue entries.** One Lua table per item, one file per source,
  written under the user's data folder. Fields:
  - `kind` (string): `"map"` or `"model"`
  - `title`, `author`, `version` (strings, as the site states them)
  - `page_url`, `download_url` (strings)
  - `terms` (string): the site's or the author's stated terms, quoted
  - `size_bytes` (integer), `posted` (string date, as stated)
  - `preview_url` (string, when the site shows a preview image)
  - `hash` (string, `sha256:` plus hex), filled in once downloaded
  - `checked` (table): what the downloader verified, filled in once downloaded
- **Downloader.** Only when the player asks for a chosen entry: fetch it the
  way a browser would, hash it, store it through the content-addressed store
  (604) in the local storage manager (605), and record the hash in the entry.
  Checks before an item counts as downloaded:
  - a map must open as an MPQ archive and parse its map-info file (Phase 1);
  - a model must read through the model reader (issue 116), and each
    texture it names must decode (issue 117). A model posted as a zip with
    its textures is one item: the zip is stored as it came, and read from;
  - a file whose hash doesn't match a hash the site publishes is refused.
  Nothing is re-hosted by the project.

## Suggested Implementation Steps

1. Write the source list as a data file, with each candidate site's terms
   and `robots.txt` read and quoted. The owner reviews it before step 3 runs
   against any real site.
2. The catalogue entry format above, with a writer and a reader; the viewer
   (1001) uses only the reader.
3. The finder interface and a first adapter, against a recorded copy of one
   site's pages or feed (a test fixture), then against the site itself.
4. The downloader: fetch, hash, store through 604/605, run the checks, and
   record the result in the entry.
5. Tests: a recorded fixture page becomes the expected catalogue entries; a
   source marked "visit by hand" is never fetched; a hash mismatch is
   refused; a file that isn't a map fails the map check with a message that
   names the file and the reason.

## Acceptance Criteria

- [ ] The source list is a reviewable data file with each site's quoted terms
- [ ] At least one source is read within its terms, producing catalogue entries for maps
- [ ] At least one source produces catalogue entries for models
- [ ] A chosen map downloads, is stored by hash, and parses
- [ ] A chosen model downloads, is stored by hash, reads through the model reader (116), and its textures decode (117)
- [ ] A "visit by hand" source is never fetched, and a test proves it
- [ ] Requests carry the tool's name and nothing about the person

## Open Questions

1. Which sites first? **Hive Workshop first** (owner, 2026-09-26: "hive
   workshop probably"); it hosts both maps and models. The owner asked what
   other sites there are; candidates offered: Epic War and WC3Maps (map
   archives), XGM (a Russian-language modding community with maps and
   models), ModDB (some total conversions), and Internet Archive collections
   of old map packs. Each is checked for its terms and current state when
   the source list is written (step 1).
2. ~~How far should the model check go?~~ Answered 2026-09-26: all the way.
   The owner: "sounds like we need a reader for .mdx files, and a little
   renderer in-engine." A downloaded model must read through the model
   reader (issue 116); the signature check is only the reader's first step.
   Drawing them is issue 516.
3. ~~A zip of a model and its textures: one item or several?~~ Answered
   2026-09-26: one item ("zip of model and textures is fine"). The zip is
   stored as it came, under its hash; the model and textures inside are
   read from it.
4. Should the finder also run inside the W client? Deferred by the owner
   (2026-09-26) to the Phase W work: "we should answer that question when
   we're working on the WoW client. I don't see why not". Carried in W02's
   open questions.

## Related Documents

- `issues/1001-catalogue-of-freely-posted-maps-and-models.md` (the viewer)
- `issues/609-shared-map-and-model-list.md` (files between people, over rmail)
- `issues/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
- `issues/superseded/607-file-server-application.md` (retired)
- `docs/licensing-and-boundaries.md` (content rights)
- `issues/CRITICAL-PATH.md` (question Q-2, answered 2026-09-26)

---

## Earlier Design (not built)

Kept as the record of the January 2026 plan: a host sends its asset packs to
every client on connect, over a protocol of its own. It was replaced on
2026-09-23, when the owner decided that "the user uses whichever models they
have installed, not what their playmates suggest they do", and that files
between people move over rmail (`/home/ritz/programs/r-mail/`): a file-based
messenger whose daemon delivers over TCP encrypted with AES-256-GCM, asks the
recipient's consent before any byte moves, and compresses, chunks and resumes
transfers. Two ideas from this design carried on into issue 609: a manifest
(a list of assets with hashes), and sending only the hashes the receiver
reports missing.

The original text follows.

> No asset download system exists. Players cannot receive community asset packs from:
> - LAN hosts sharing custom WC3 maps with custom asset packs
> - Matchmaking servers distributing common asset collections
>
> A peer-to-peer asset download protocol that:
> 1. Transfers community asset packs from LAN host to clients on connect
> 2. Supports resumable downloads (connection drops shouldn't restart)
> 3. Integrates with deduplication (don't re-download assets already present)
> 4. Shows download progress to the user
> 5. Works for both direct LAN connections and matchmaking server-facilitated transfers

### Protocol Overview

```
CLIENT                              SERVER/HOST
   │                                    │
   ├──── CONNECT ──────────────────────▶│
   │                                    │
   │◀─── MANIFEST ─────────────────────┤  (list of assets + hashes)
   │                                    │
   ├──── HAVE [hash1, hash2, ...] ─────▶│  (assets client already has)
   │                                    │
   │◀─── NEED [hash3, hash4, ...] ─────┤  (assets to download)
   │                                    │
   ├──── REQUEST hash3 ────────────────▶│
   │◀─── CHUNK hash3 offset data ──────┤  (chunked transfer)
   │◀─── CHUNK hash3 offset data ──────┤
   │◀─── DONE hash3 ───────────────────┤
   │                                    │
   ├──── REQUEST hash4 ────────────────▶│
   │     ...                            │
   │                                    │
   ├──── READY ────────────────────────▶│  (all assets received)
   │                                    │
   │◀─── GAME_START ───────────────────┤
```

### Manifest Format

```lua
-- manifest.lua (host-side)
return {
    version = 1,
    host_id = "custom-td-map-v3",
    map_name = "Epic Tower Defense",
    asset_pack = "community-medieval-assets-v1",
    assets = {
        {
            path = "textures/terrain/grass.png",
            hash = "sha256:abc123...",
            size = 102400,
            priority = "required",    -- required, optional, streaming
        },
        {
            path = "models/units/knight.mdx",
            hash = "sha256:def456...",
            size = 524288,
            priority = "required",
        },
        -- ...
    },
    total_size = 52428800,  -- 50 MB total
}
```

### Priority Levels

| Priority | Behavior |
|----------|----------|
| `required` | Must download before game starts |
| `optional` | Download in background, use fallback until ready |
| `streaming` | Download on-demand when asset is first needed |

### Client API

```lua
local downloader = require("assets.downloader")

-- Connect to host and start download
downloader.connect({
    host = "192.168.1.100",
    port = 7878,
    on_progress = function(current, total, current_file)
        print(string.format("Downloading: %d/%d MB - %s",
            current / 1024 / 1024,
            total / 1024 / 1024,
            current_file))
    end,
    on_complete = function()
        print("All assets downloaded!")
    end,
    on_error = function(err)
        print("Download failed: " .. err)
    end,
})

-- Check download status
local status = downloader.status()
-- { state = "downloading", progress = 0.75, speed_kbps = 1024 }

-- Cancel download
downloader.cancel()

-- Resume interrupted download
downloader.resume()
```

### Original Implementation Steps

1. Design wire protocol (binary format for efficiency)
2. Implement `src/assets/protocol.lua` - message encoding/decoding
3. Implement `src/assets/downloader.lua` - client-side download manager
4. Implement chunk storage for resumable downloads
5. Integrate with deduplication system (Issue 604)
6. Implement progress reporting and UI hooks
7. Create mock server for testing
8. Test resumable downloads (simulate disconnection)

### Original Acceptance Criteria

- Client receives manifest on connect
- Client reports already-owned assets (by hash)
- Server only sends assets client needs
- Downloads are chunked (configurable chunk size, default 64KB)
- Interrupted downloads resume from last chunk
- Progress callback fires with accurate stats
- Required assets block game start until complete
- Optional/streaming assets use fallback while downloading
- Download speed is reasonable (not artificially throttled)

### Original Notes

- Consider compression for transfer (gzip/lz4) - tradeoff between CPU and bandwidth
- Chunk size should be tunable for different network conditions
- May want parallel downloads for multiple small files
- Error handling: corrupt chunk detection via hash verification
- Security: validate asset hashes, reject mismatched data
