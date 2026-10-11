<!-- Made by Claude (Opus 5.5), 2026-10-10, during project initialisation, to hold every question met so far until it is answered with the owner. -->
# Open questions

## Answered
- **Colours:** red and green lasers (not blue). Direct green diodes, not
  infrared-pumped ones (docs/physics-check.md).
- **The cuff:** its own kind of input — drag along it for an analog value.
- **Safety:** an enclosed light path that extends and turns with the arm,
  lined to send light backward toward a mirror at the back.
- **Glowing screen:** set aside, too slow.
- **The vortex:** a vortex of light; its job is to light the side of the band
  with faint, coloured streaks seen at an angle.
- **Diagonal segments:** decided by how fine the hardware can be made.
- **The lookup table:** 4 bits, each choosing one of a pair of bytes: 8 byte
  receptacles. Used either as two values for one field, or as eight kinds of
  data about one record.

## Open
1. **Distance at the edges:** try both — by the panel's curve and by drawing.
2. **E-ink:** it is about as slow as the glowing screen that was set aside.
   Still wanted, perhaps for things that rarely change?
3. **Colour that changes under light:** a surface that changes colour, e-ink
   style, when a certain wavelength (red or green laser) shines on it. What
   material?
4. **The back of the tube:** a mirror with the emitter entering from the side,
   or the emitter itself with an optical isolator?
5. **The store:** does it have a job left?
6. **The arm's fluid:** shared with the light pipe, or separate?
7. **Phase 1 after the segment decision:** the phase 1 issues still plan a
   grid of cells (a mask) shaped from any picture. Later rounds moved toward
   22-segment character cells (docs/physics-check.md, third round). Should
   phase 1 be rewritten around segments, with a tool that draws every
   character on the 22-segment cell to show which ones read?
8. **The store's issue:** issue 202 models the store as a light bank; if
   question 5 retires the store, 202 goes with it.
9. **CAD formats beyond triangles:** the viewer reads STL, OBJ and glTF —
   all lists of triangles. STEP (exact curved surfaces, what engineering CAD
   saves natively) would need a geometry kernel or a Blender/FreeCAD bridge.
   Wanted, or is exporting glTF/STL from the CAD program enough?
10. **OBJ colours from pictures:** some exporters (MagicaVoxel) colour an
    OBJ by a picture (a texture) rather than by material colours; the viewer
    draws those models plain white and lists "vt" as not read. Read textures?
11. **Reading on several threads:** binary STL's fixed 50-byte records split
    cleanly across workers. Worth it once a model takes long enough to wait
    on?
