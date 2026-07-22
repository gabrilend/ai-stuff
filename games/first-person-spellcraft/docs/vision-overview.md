# Vision Overview — First Person Spellcraft

> A structured distillation of `notes/vision`. The vision file is the source of
> truth. Where the vision speaks in poetry, this document quotes it verbatim
> rather than paraphrasing its voice away. When this overview and the vision
> disagree, the vision wins.

---

## Preamble — the spirit of the thing

First Person Spellcraft is a first-person "shooter" where the gun is a spell.
You need **two mice**: one for the left hand of your "boomstick", one for the
right. The boomstick is a wand-style directional (or a jax-style musketball)
aiming peripheral, and your two hands are animated live from the inputs of those
two mice. The wand is not a crosshair bolted to your face — it is a thing you
hold, with two hands, and wave.

The vision names a stretch dream past the two mice:

> then, if the player happens to have a brain-computer interface,
> something that reads common brain patterns like "look up and to the left"
> represented as the player moving their attention upward and leftward
> which moved the headset mounted to the ceiling at just the right tension
>
> (these are all stretch goals)

And the vision plants a flag about what kind of game this is and is not. This is
quoted verbatim and treated as sacrosanct — it is the reason the "AI" in this
game builds dungeons and companions instead of kill-squads:

> yay killer robot AI
>
> not ideal...
>
> there's no skynet in my socialist utopia.
>
> no murder killbots.
>
> no death squads.
>
> no murder.
>
> no reason to.
>
> no belief we so cowardly hold onto.
>
> no wrong that cannot be righted
>
> no sense in building a spynet
>
> no cowards hiding behind bombs
>
> no injustice that can't be prevented
>
> no peace because there is injustice.

The AI here is a Dungeon Master and a chorus of companions, not a warlord. It
makes puzzles, remembers who solved them, and grows kinder or crueler by how you
treat the land around you.

---

## Feature list, grouped by the nine functional phases

The phases are **functional capability slices ordered by dependency**, not a
chronological schedule. (For the time-gating / milestone view, see
[roadmap.md](roadmap.md). For the phases as organizational groupings, see
[table-of-contents.md](table-of-contents.md).) Exact per-capability counts are
deliberately not hardcoded here — see "A note on counts and statistics" below.

### Phase 1 — Engine Foundation
- Doom-style world: square rooms, each with something special about it.
- Map representation for those square rooms.
- World rendering.
- Player movement (characters "move around semi-quickly").
- Collision.
- The core game loop that ties the above together.

### Phase 2 — Dual-Mouse Aiming & Input
- The signature two-mouse "boomstick" / wand aiming peripheral.
- Each mouse drives one hand (left mouse → left hand, right mouse → right hand).
- Hand animation derived live from the dual-mouse input.
- An input abstraction layer that later systems aim through.
- The **dual-mouse control scheme** (see
  [notes/vision-control-scheme](../notes/vision-control-scheme)): a "helicopter
  jetpack" wand-pilot locomotion map — both right-mouse buttons surge forward, a
  right-click turns, scroll wheels are the two thrusters (height inertia) — plus
  the trigger hand's click fires and the off hand's raises an alt action (a
  flashlight, or a jetpack rocket aimed at the reticle), with the grip↔trigger
  roles swapping when the reticle crosses screen centre. The vision offers turn and
  strafe *alternatives* (turn-by-click vs by reticle screen-position; strafe vs a
  held "hover mode") kept as selectable modes. Middle-mouse ally signals are noted
  but deferred with the sequel's party system.
- **Stretch (documented, not built):** brain-computer interface reading patterns
  like "look up and to the left", and a ceiling-mounted attention-tracking
  headset held "at just the right tension."

### Phase 3 — Spell System
- Dominions-style spell **paths** and **levels**.
- Multiple distinct ways to cast each spell: "there are many ways to cast spells
  of each level in each path. each spell is different, and there are more than
  one ways to do each of them."
- Aimed spell effects — anything that needs aiming, the user aims through the
  input layer, "when they're playing as an NCP - New Character Person."

### Phase 4 — Puzzles, Mechanisms & Traps
- Mechanisms that provide a solution, with **multiple ways to trigger** them.
- **Multiple ways to use the mechanisms that do NOT provide the solution** —
  red-herring triggers, each made to "seem suitably equal in likely."
- Platforming puzzles.
- Magic-effect-driven solutions (apply certain magic effects to certain puzzles).
- Traps that trigger on puzzle failure; sometimes disarming the trap is itself
  the puzzle, other times it's a magical-style enchantment.

### Phase 5 — NCP Characters & LLM Companions
- Autonomous "New Character Person" (NCP) adventurers.
- LLM companion speech patterns that "change and grow and guide between
  interactions" — to prevent character burn-out.
- Every newborn character starts from a common pattern; the player can save
  patterns as new patterns, but **summarized**, "to ensure behavior remains
  coherent."
- The weaker puzzle-solving AI the NPCs use to figure out the lairs.
- The player can take control and aim when playing as an NCP.

### Phase 6 — AI Dungeon Master & Learning
- A powerful **local** AI that generates lairs — roughly three puzzles and
  exactly four combats per lair.
- The DM remembers each party's demonstrated capability: "each time they conquer
  it, the AI remembers they are that potentialed."
- It updates its conception of what a "level" means to estimate how intellectual
  the characters are, and tunes difficulty to each character's per-stat levels.
- The library / fairy-tale learning mechanic: fairy-tales that teach "mechanics
  of existence like three-dimensional rotations (quaternions) or newtons laws of
  bio-impedence, and other such magical-histories" — and then the puzzles might
  be easier.
- The DM overcomes the party "through shadows, storm, or pounding."

### Phase 7 — Economy & Settlement Management
- Treasure types: gold, gems, resource notes, and trial logs.
- In-game UI that configures **templates, never instantiations**.
- NPC requests fulfilled from player-configured markets: "trade goods come in,
  they request capabilities from ashore, and they arrive and do their duty."
- Worker allocation, e.g. lumber shops and lumberjacks — "the fewer, the better,
  as they have room to spread out. but, throughput is lower."
- Service staff who handle chores to grant a production speed bonus, so workers
  "don't have to worry about personal chores."

### Phase 8 — Territory & Majesty Formula
- The Majesty-formula loop: overcoming trials and clearing/controlling
  neighboring provinces yields resources depending on your relationship to them.
- Be peaceful → they are on your side and provide resources.
- Be unkind → they become challenges to train up on.
- Leave unclaimed → monsters return, either to fight for a specific resource type
  or to protect and leave to nature, cultivating natural materials.
- If to too many you are unkind, "they may form a union. then you better prepare
  becaus e they'll end you."

### Phase 9 — Platform & Packaging
- Run on an Anbernic handheld, and "give one copy to each european."
- The whimsical delivery concept, verbatim:
  > oh! what if we made it run on a cassette and we hooked up a cassette tape
  > player to a gameboy control interface and used the binary "sounds" it made
  > to record the game in the style of a pico-8

---

## Target platforms

- **Primary reach target:** the **Anbernic** handheld — small, cheap, widely
  distributable ("give one copy to each european").
- **Whimsical delivery experiment:** a cassette tape, played through a cassette
  tape player, wired into a **gameboy control interface**, using the binary
  "sounds" it emits to record/load the game in the **pico-8** style. This is a
  packaging capstone idea, documented so it is not lost; it is not a Phase-1
  concern.

Both live in Phase 9. Because a handheld is the reach target, memory and input
constraints inform every earlier phase — but that shaping belongs in the
per-phase datapath docs, not here.

---

## Language

- Preferred language: **Lua**, written in **LuaJIT-compatible** syntax.
- **Disprefer Python.**
- **Disallow Lua-5.4-only syntax** (nothing that would break under LuaJIT).

Rationale lives with the constraint: LuaJIT gives us the speed a Doom-style loop
wants on a handheld, and keeping to LuaJIT-compatible syntax keeps the door open
to that Anbernic / pico-8-style delivery.

---

## A note on counts and statistics

Per the project's documentation discipline, this overview deliberately avoids
hardcoding counts (number of spells, number of paths, number of puzzle types,
per-lair puzzle/combat totals beyond what the vision itself fixes, etc.). Hard
numbers rot. Instead, a future **validator / statistics-gathering utility**
should be run to produce accurate, current figures on demand, and this document
should reference that utility rather than restate its output. When such a
utility exists, link it here.

The only counts stated as fixed are the ones the vision itself fixes: a lair
holds "three-ish puzzles and four combats exact."

---

## A note on scripts (convention)

Any script written for this project should be runnable **from any directory**: a
hard-coded `${DIR}` path defined at the top of the script, overridable by a
command-line argument, with **every path in the program relative to `${DIR}`**.
This keeps the eventual Anbernic / cassette packaging honest, since the game
must not assume it was launched from its own folder.
