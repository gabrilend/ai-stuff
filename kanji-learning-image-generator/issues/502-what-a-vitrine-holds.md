# 502 — What a vitrine holds

## Current behavior

The scene grammar (`src/024-the-scene-grammar.lua`, `docs/004`) picks a **biome**
by scoring the character's meanings and components against each world's trigger
words — forest, water, mountain, field, dwelling, town, sky, fire, metal, person,
beast, cloth, food, road, shrine, word, night. The biome supplies an object for
each stroke's measured shape: in a forest a long vertical is a cedar trunk, in
water it is a cataract.

Every biome is a place out of doors or a room someone lives in. None is a place
where things are **shown**.

## Intended behavior

**A hall is a biome whose things are exhibits.** The same reasoning — measure
the stroke, pick the world, ask the world what lies along a stroke of that shape
— with a closed list of halls:

| hall | a long vertical | a long horizontal | a curve | a dot |
|---|---|---|---|---|
| skeleton | femur, spine post | rib run, tail vertebrae | rib, jaw | vertebra, tooth |
| taxidermy diorama | tree in the backdrop, standing bird | branch, ground line | neck, tail | eye, small bird |
| botany | stem, reed | pressed leaf, root | tendril, petal | seed, bud |
| aquarium | kelp, bubble column | sandbar, shoal of fish | eel, jellyfish bell | fish, pebble |
| geology | crystal column, core sample | stratum band | geode rim, ammonite | pebble, gem |
| planetarium | (below) | | | |
| mechanism (models to show how things move) | piston, axle | lever, rail | gear rim, cam | rivet, bearing |

The rows are data; adding a hall is adding a row.

### The planetarium

Asked for in these words, and built to them:

> can we make a planetarium exhibit that's like the planet projection from Star
> Wars? With hologram style visuals, portrayed in the dark on large orbs that the
> kids can climb on. The inside is mostly dark with faint bright lights at the
> places of uneven footing (yay climb)
>
> also painted on the outside walls are the constellations that would be visible
> from the solar system in rough approximate spot.

So the planetarium hall is a dark room of **large climbable orbs** carrying a
**holographic projection** of the planets, with **faint lights marking uneven
footing**, and **constellations painted on the outer walls**. Its strokes:

| a long vertical | a long horizontal | a curve | a dot |
|---|---|---|---|
| projection beam, climbing pole | orbit ring, walkway | orb's lit edge, orbit arc | footing light, planet, star on the wall |

Its polarity is light-on-dark: the strokes are what glows.

### Choosing a hall

**By score, as a biome is** — 木 votes for botany, 魚 for aquarium, 石 for
geology, 骨 for skeleton, 月, 日 and 星 for the planetarium, 車 for mechanism.

**With a museum (`501`), only among its halls.** A museum without an aquarium
cannot put 魚 in one; it falls to its best hall it does have, and the scene
records that and why.

**Without a museum, any hall** — `--style hall:skeleton`, or the hall chosen by
score — named in generic words. This is the route used until a museum record
exists that is worth naming.

**A character scoring nothing in any available hall is reported, not
defaulted**, for `docs/004`'s reason: a silent fallback makes an unknown
fraction of the set into generic museum pictures.

**The two readings still hold.** Under `mnemonic`, every named piece is an
exhibit; under `semantic`, the sound half becomes the case's structure — shelf,
plinth, glass mullion — instead of terrain.

**Polarity follows the hall**, one field per hall as per biome.

**In the two routes of `416`**, a hall's stroke objects are what the inside
route places inside the mask, and its setting with nobody in it is the
background.

## Suggested implementation steps

1. **A hall table** beside the biome table in `024` (or its own numbered file if
   `024` grows past reading in one sitting), rows shaped like biomes: trigger
   words and components, polarity, shape-to-object table, and the empty setting
   for `416`'s background.
2. **Scoring among halls** only when the style is a museum or a hall; otherwise
   halls are not considered and existing scenes are byte-identical.
3. **`hall` and `museum` fields on the scene**; `025` turns them into words.
4. **Tests in `027`**: 骨 lands in skeleton; 星 in the planetarium; 魚 in a museum
   without an aquarium lands elsewhere and the scene says so; a character
   matching no hall is reported; no-museum scenes are unchanged.

## Related

`204` — the biome scoring this copies. `201` — the stroke measurements. `411` —
a radical making its own strokes. `501` — which halls a museum has. `416` — where
the hall's objects and empty setting go. `503` — the case.
