# what would be better

Wanting that has not earned a blueprint yet. Nothing here is planned. Some of it
will turn into an issue file; some of it will turn out to have been a mood.

---

**A world you can edit while standing in it.** The geometry is text, so a
running client could watch the file and reload it. Move a wall, see the wall
move, without leaving. The gap between authoring and playing is almost always
where worlds stop getting made.

**Schemes that switch on a keypress and never reload.** Already the plan, but
what would be *better* is being able to hold a key and cross-fade, so the four
schemes can be compared as one continuous thing rather than four separate looks.

**A whisp that shows what it is doing without any interface.** Waiting could be
in the squiggle itself — the wander slowing, the arms drawing inward, the trail
going still — rather than in a bar drawn over the world. An interface made of
the creature instead of an interface made of rectangles.

**Packet logs that replay into the renderer.** The world model is fed by events
rather than by a socket, so a recording should be able to drive it. Then a bug
report is a file, and a session is a thing you can watch again.

**A test that looks at a picture.** Squiggles are easier to check by eye than by
assertion. A test that dumps a frame to an image and puts it beside the last
known-good one would catch the class of bug that numbers never do.

**Patches that know how long they have been alive.** The registry could report
the age of each patch and how many upstream releases it has survived. A patch
that has been re-anchored six times is telling you something about where it
sits, and nobody is listening.

**Sound made the same way as the whisps.** Deterministic from the identity, so
your whisp has your tone, computed rather than stored, costing nothing on the
wire. The same trick twice.

**A second client, deliberately worse.** A terminal client that draws the same
world in characters. Not for players — for proving the world model really is
independent of the renderer, which is a claim currently made only on paper.

**Knowing whether anyone else has run a server on fabricated data.** Generating
the whole set of client-side tables from scratch, rather than extracting them,
feels like something people must have attempted. Their scar tissue — which
tables turned out to hide requirements, what broke six months in — would be
worth more than any amount of reading the loader.

**A viewer for the fabricated tables.** They are opaque binary files with no
checksums, where a column miscount produces plausible garbage rather than an
error. Something that renders one as a grid, using the extracted schema for the
column names, would turn a class of silent bug into something visible.
