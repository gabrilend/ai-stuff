# Issue 801f: Asset Mirror Integration

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Medium
**Dependencies:** Issue 801b (server core). (The file server issue was retired 2026-09-26: files between people move over rmail, issue 609.)
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests), 801g

---

## Current Behavior

Matchmaking server has no asset distribution capabilities. Players must download asset packs from individual hosts.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #310 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- A pack of 4 GiB or more (or a mirror contact over 1024 bytes) makes the server's advert fail to encode, and nothing catches it, so the whole daemon exits.
- The new message (0x11) was added without raising the protocol version; clients built before it drop the connection right after joining.
- A plain id-to-hash table holding a pack named "has" is mistaken for a registry and crashes (confirmed).
- Adding a pack treats any read failure as end-of-file and ignores failed writes: adding a folder registers an empty pack (confirmed), and a full disk replaces a good pack with a cut-off one.
- Symlinked packs are skipped by `find -type f` and not even listed as skipped.
- The packs folder is read once at startup; added or removed packs are never noticed until restart.
- A missing or unreadable folder silently becomes an empty mirror, and `find`/`sha256sum` errors are discarded.
- Every pack is hashed one after another at startup, before the server listens.
- A backslash or newline in the path makes `sha256sum` prefix its line, so every pack is skipped; size and hash are read separately and can belong to different moments.

## Intended Behavior

> **Transport, 2026-09-23:** every asset transfer goes over rmail, "the only
> connection protocol for assets that I trust" (owner). A mirror is then an
> rmail contact that answers requests for packs, and players still accept each
> transfer through rmail's consent step. See issues 603 and 609.

Matchmaking server can host commonly-used community asset packs:
1. Players download once from central mirror
2. Reduces bandwidth burden on individual game hosts
3. Faster downloads from dedicated server
4. Curated packs with quality standards

### Architecture

```
        MATCHMAKING SERVER
┌─────────────────────────────────────┐
│  ┌──────────────────────────────┐   │
│  │  Game Listing Service        │   │
│  │  (port 8080)                 │   │
│  └──────────────────────────────┘   │
│  ┌──────────────────────────────┐   │
│  │  Asset Mirror Service        │   │
│  │  (port 7878)                 │   │
│  │  - Serve common asset packs  │   │
│  │  - Generate manifests        │   │
│  │  - Handle downloads          │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
            │
            ▼
    COMMUNITY PACKS
    ┌──────────────────┐
    │ medieval-v1      │
    │ fantasy-v2       │
    │ sci-fi-v1        │
    │ ...              │
    └──────────────────┘
```

### Workflow

1. **Lobby created** - Host specifies required asset packs
2. **Client joins** - Matchmaking server sends asset pack list
3. **Client checks** - Does client have these packs?
4. **Download needed** - Download from matchmaking server (or host as fallback)
5. **Game starts** - All clients have required assets

### Configuration

```lua
-- matchmaking-server.conf.lua (updated)
return {
    bind = "0.0.0.0:8080",

    -- Asset mirroring
    asset_mirror = {
        enabled = true,
        port = 7878,  -- Separate port for asset downloads
        packs_dir = "./community-packs/",
        bandwidth_limit_mbps = 100,

        -- Curated pack list (server operator maintains)
        packs = {
            "medieval-v1",
            "fantasy-v2",
            "sci-fi-v1",
        },
    },
}
```

## Suggested Implementation Steps

1. ~~Integrate Issue 607 file server into matchmaking server~~ (607 retired 2026-09-26; a mirror is an rmail contact)
2. Add asset mirror configuration to server config
3. Implement pack registry (which packs are available)
4. Add `ASSET_PACKS_AVAILABLE` message type to protocol
5. Update lobby creation to include asset pack requirements
6. Update client library to check for required packs
7. Implement download orchestration (mirror first, host fallback)
8. Add bandwidth limiting
9. Add pack curation tools (add/remove packs from mirror)
10. Create documentation for server operators

## Acceptance Criteria

- [ ] Matchmaking server can serve asset packs
- [ ] Lobby includes asset pack requirements in metadata
- [ ] Client checks if required packs are present
- [ ] Client downloads from mirror if available
- [ ] Client falls back to host if pack not on mirror
- [ ] Bandwidth limiting works (doesn't saturate server)
- [ ] Server operator can add/remove mirrored packs
- [ ] Download progress shown to client
- [ ] Failed downloads handled gracefully

## Related Documents

- Issue 607 - File server application (retired 2026-09-26, `issues/superseded/`)
- Issue 801b - Server core (integration point)
- Issue 801c - Client library (download orchestration)
- Issue 603 - Fetch maps and models from public sites (was: asset download protocol)

## Open Questions

1. **Pack curation:** Who decides which packs are mirrored?
   - Server operator manually maintains list?
   - Automatic based on popularity?
   - Community voting?

2. **Storage limits:** How much storage should mirror use?
   - Top 10 most popular packs?
   - Size-based limit (e.g., 10 GB total)?
   - Time-based expiry (remove unused packs after 30 days)?

3. **Bandwidth costs:** How to prevent abuse?
   - Rate limiting per IP?
   - Require joining lobby before download?
   - Donate bandwidth model?

## Notes

- Asset mirroring is optional - server operators can disable it
- Fallback to host download ensures packs work even without mirror
- Consider CDN integration for large deployments (Cloudflare R2, etc.)
- Pack manifests should be cached to reduce repeated downloads
- Monitor bandwidth usage - this can get expensive at scale

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Question Q-1 is open.

1. **The matchmaking server only says what the mirror holds.** With the
   transport settled as rmail (2026-09-23), nothing here moves a pack:
   whoever opens or joins a lobby whose packs the mirror holds (same id,
   same hash) is sent ASSET_PACKS_AVAILABLE, the issue's new message
   (0x11): those packs and the mirror's rmail contact. Asking that
   contact for a pack, and accepting it, is rmail's (issues 603, 609).
   So there is no port 7878.
2. **A pack is one file, `<id>.pack`,** in the mirror's folder, its hash
   "sha256:" and the file's SHA-256, the form lobbies already give for
   map hashes. No pack format existed yet. If 601 or 609 settle on
   another (a folder, an archive with a manifest), the registry's
   reading of the folder is the one part to change.
3. **Mirror first, host second, decided by the player:** the library's
   `lobby:missing_packs(have)` lists each missing pack with
   `from = "mirror"` when the advertised list has that very pack,
   otherwise `"host"`. Another hash of a pack counts as missing.
4. **The curation is the operator's** (open question 1): the folder is
   the list; `registry:add`/`remove` (and 801g's `assets add`/`remove`)
   change it. No popularity count, voting, size limit or expiry (open
   questions 1 and 2).
5. **No bandwidth limit here** (step 8, open question 3): the bytes move
   over rmail, so a limit belongs to rmail's sending. The server's own
   rate limit (801b) still caps the messages.
6. **Daemon:** `--mirror-contact C --packs-dir DIR`, both or neither; the
   configuration file of 801g will take the same two.
7. **The test makes its folder with `mktemp -d`,** under `$TMPDIR` when
   set, and removes it.

## What happened (2026-11-05)

- `src/matchmaking/packs.lua` with its info page: the registry, hashing,
  `available` and `plan`.
- Protocol: ASSET_PACKS_AVAILABLE (0x11). Server: the `mirror` setting
  and the message after JOIN_ACK. Client: `lobby.mirror`, the
  `asset_packs` event and `lobby:missing_packs`. Daemon:
  `--mirror-contact`, `--packs-dir`.
- `src/tests/test_matchmaking_packs.lua` (40 checks, no network): hashes,
  the registry (good and bad ids, copies over a chunk, half-written
  files, removals, reloads, order), what a mirror offers, plans, and the
  server's core with and without a mirror through the client library.
  `test_matchmaking_daemon.lua` checks the two flags and the message over
  a socket (35 checks); the protocol test counts the seventeenth type.
- In `run-net-tests.sh`; `src/cli/run-tests.sh -d DIR matchmaking` runs
  and counts it.
- Mutation check: 32 mutants of `packs.lua`, the server, the library and
  the daemon, with `ulimit -f`; all 32 caught, two of them only after
  checks were added (a slash in an id refused for the right reason, the
  list's order). A 33rd, a length check on `sha256sum`'s output, could
  not fail; the dead check was removed.

**Left for the owner:** the transfers themselves (an rmail contact that
answers pack requests, and the consent step), download progress (rmail's
to report), the host fallback's transfer, the bandwidth limit, and the
three open questions. So the issue stays open.
