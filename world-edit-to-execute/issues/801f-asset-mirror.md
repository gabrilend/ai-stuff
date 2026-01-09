# Issue 801f: Asset Mirror Integration

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** Medium
**Dependencies:** Issue 801b (server core), **Phase 6 (Asset System - Issue 607 file server)**
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

Matchmaking server has no asset distribution capabilities. Players must download asset packs from individual hosts.

## Intended Behavior

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

1. Integrate Issue 607 file server into matchmaking server
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

- Issue 607 - File server application (asset distribution)
- Issue 801b - Server core (integration point)
- Issue 801c - Client library (download orchestration)
- Issue 603 - Asset download protocol

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
