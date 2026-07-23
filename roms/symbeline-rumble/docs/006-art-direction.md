# Art Direction

## Tilt-shift, as design rule

The visual identity is a tilt-shift miniature: a sharp horizontal band in
the middle of the frame, with the top and bottom of the image softened into
blur. The optical reference is a macro photograph of a model railroad. The
emotional reference is *"these are tiny people we are watching from a
respectful distance."*

### The rule of the sharp band

Units render only in the sharp band. Period.

- If a unit walks toward the top or bottom of the visible area, the camera
  follows so the unit stays in the band.
- If a unit cannot be kept in the band (e.g., player is paging or panning),
  it is briefly absent rather than rendered into blur.
- Scenery — trees, terrain, structures, props — may extend into blur freely.

This rule serves two purposes: it bakes the tilt-shift aesthetic into
gameplay legibility, and it makes the DS implementation tractable. On DS,
the blur is faked with pre-blurred 2D sprite backdrops; the sharp band is
the 3D engine's actual output. If units never enter the blur, the DS never
has to render a blurred 3D unit (it can't).

## Palette

Saturated, slightly chalky. Think gouache illustration scanned with a warm
white balance. Specific palette is defined in `assets/palette/` and refined
in the early phase demos; this doc just commits to the *family*:

- Greens lean toward moss and verdigris, not neon.
- Earths lean toward umber and ochre, not flat brown.
- Skies lean toward cream, lavender, and pale teal, not blue-gradient.
- Highlights are warm; shadows are cool. No pure black, no pure white.

## On-map signaling

All in-world communication is **diegetic**: it comes from things that exist
in the scene, not from chrome overlaid on top.

| Information                  | Channel                                                            |
|------------------------------|--------------------------------------------------------------------|
| Unit took damage             | Brief flash on the model + a soft *thwack* SFX                     |
| Unit died                    | Tumble animation + fade; no death number                           |
| Unit picked up treasure      | Glow halo on the unit; back-end strap visibly weighted             |
| Notification ("ready", "low gold") | Speech bubble emerging from the relevant structure/unit       |
| Cast feedback                | Ground-anchored particle at the cast site                          |
| Gold accumulation            | Section-marks on a bar near owned infrastructure                   |
| Targeting / selection        | Soft ring beneath the targeted entity                              |

## Speech bubbles

- Always anchored to a thing in the world.
- White ground with a 1-pixel border, charcoal lettering.
- Short phrases only. If it needs a paragraph, it belongs in a menu.
- Persistence: timed (a few seconds), or dismissed by player input that
  resolves the underlying state.

## What is forbidden

- Floating health bars.
- Damage numbers ("-23!").
- Corner UI of any kind during the match (gold lives on the bar; pause lives
  in the menu).
- Lens flares.
- Cinematic letterbox bars (the vertical screen is already the letterbox).

## Native vs. NDS, aesthetically

Native should not look "better" — it should look *the same*. The DS
imposes resolution, palette, and triangle limits; the native build observes
them voluntarily (see the parity rule in `004-architecture.md`). The only
sanctioned divergence is the tilt-shift technique (real shader vs. faked
layers), and even there, the resulting frame should be hard to tell apart
without inspecting pixels.
