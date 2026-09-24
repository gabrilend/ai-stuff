# Issue W05c: "Default Client Compatible" Seal

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** Low (a badge, not a requirement)
**Dependencies:** W05a, W01, W04 (the rig that runs the stock client)

---

## Current Behavior

Replacements made by the forge are meant for the W client, which reads its
pack formats (glTF/OBJ meshes, PNG textures) directly. Nothing checks whether
a replacement would also work in the stock 3.3.5a client, and nothing marks
the ones that do.

## Intended Behavior

In the owner's words: "the stock client doesn't need to read our archives,
but it'd be neat. I think models and such will have to have a seal or medal
that says 'default client compatible' and most models wouldn't have it."

A replacement earns the seal when all three hold:

1. **Converted** into the stock formats: M2 (version 264) with its `00.skin`,
   textures as BLP2 (the W client's shared-library encoder), any DBC rows it
   needs (display info pointing at the new model path).
2. **Within the stock client's limits**: power-of-two texture sizes, bone
   count and bones-per-submesh within what the stock client accepts,
   texture-unit count per material. Each limit is a named check with the
   measured value, not a yes/no.
3. **Confirmed in the stock client**: packed into a patch archive, loaded in
   the stock client by W04's rig, rendered, recorded, and compared with the
   same asset in the W client. A crash, missing geometry or a large
   difference fails it.

The seal is stored in the provenance record and pack manifest (bool, plus the
date and the stock-client build it was checked against) and shown on the asset
card with the similarity score.

## Suggested Implementation Steps

1. M2 writer for static meshes first (no bones), then skinned meshes bound
   to borrowed skeletons (W05b). No M2 writer exists in either project yet;
   decide between writing one or driving an existing open-source exporter.
2. Limit checks as a table of named rules, each reporting the measured value.
3. Patch-archive packing through the shared library's `mpq_write`.
4. A W04 scenario template: "show asset X at the origin, rotate the camera
   once", run in both clients.
5. Record the seal; show it on the asset card and in the gallery.

## Acceptance Criteria

- [ ] One static doodad replacement earns the seal end to end
- [ ] A deliberately oversized texture fails with the named limit and measured size
- [ ] The seal appears on the asset card and in the pack manifest

## Open Questions

1. Write our own M2 writer, or drive an existing open-source exporter (for example a Blender add-on that targets 3.3.5a)? An exporter we don't own becomes a dependency of the seal.

## Related Documents

- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/012-asset-replacement-and-provenance.md`
