# Issue 540: Computer Players Build, Buy and Cast

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 521 (AI), 531/535 (construction, upgrades), 533/539 (shops), 528/529 (heroes, abilities), 532 (items)

---

## Current Behavior

Computer players only train units at the buildings they have and gather.

- **Builds:** an AI Editor profile's "building" and "expansion" entries are noted as unplayed. The melee AI never builds its barracks, so its waves never form.
- **Upgrades and hires:** nothing upgrades a hall to a Keep, and nothing hires at taverns.
- **Heroes:** they never learn skills (profile skill orders are "kept, not used").
- **Items:** no one drinks potions or shops, even with "Buy Items" set.
- **Spells:** computer units never cast.
- **Repair:** the "repair" option does nothing.

## Intended Behavior

- **Making things:** `AI:produce(id)` makes a thing however it's made:
  - upgrading a building that upgrades to it;
  - training it;
  - hiring it at a shop that sells it to the player (a unit walks there first);
  - else building it with a worker on a free spot near home, clear of the gold mines (`AI:construct`).
- **Counting:** `AI:count` also counts what's on its way: ordered built, upgrading, being hired.
- **Expansions:** a hall at the gold mine nearest home that has no hall of the player near it.
- **Heroes** learn their skills as they level: the profile's skill order, else the first they can.
- **Spells in a fight** (an enemy within 900):
  - harmful ones on the nearest enemy in range (heroes first with "target heroes");
  - healing ones on the most hurt ally below 60%;
  - ally buffs on fighters without one;
  - area spells where three or more enemies bunch;
  - no-target area spells when two enemies are within the area;
  - Divine Shield only below 30%;
  - Blink, auras and passives never.
- **Items:**
  - heroes drink restoring items below 35% health;
  - with "Buy Items", a hero at home with room walks to the nearest shop selling items and buys what it can afford above a 300-gold reserve, restoring items first;
  - with "Take Items", heroes pick up items within 600.
- **Repair:** with the "repair" option, idle workers mend damaged buildings near home.
- **Profiles:** an AI Editor profile's building entries are built and its expansions made. Research ("upgrade" entries) is still kept, not played.
- **Speed:** enemies are looked up in a 512-unit grid made once per casting pass. On DAoW with every computer player running, a minute of game costs about what it did before (64 s against 77 s, both measured while the test suite ran alongside).

## Suggested Implementation Steps

1. `ai/acts.lua`: builders, upgrader, seller, site, construct, hire, expand, hall_type, coming; learn_skills; cast_spells / cast_one; use_items, shop, take_items; repair_base; `AI:acts`.
2. `ai/player.lua`: produce dispatches; count includes what's coming; update calls acts.
3. `ai/editor_ai.lua`: building and expansion entries played; hero skill orders passed on. `ai/melee.lua` notes.
4. Tests.

## Acceptance Criteria

- [x] produce builds with a worker on a free spot near home, counted once from order to finish
- [x] produce upgrades a hall to a Keep; hires a hero at a tavern with a unit sent there
- [x] Heroes learn in the profile's order
- [x] Strike, heal, area, shield-when-hurt, no-target-when-close spells cast as described
- [x] Potions drunk when hurt; buying at a shop, restoring first, keeping the reserve
- [x] Repair with the option only
- [x] Expansion toward a free mine (or "no free mine")
- [x] A profile's building entries built
- [x] Tests: test_ai_acts (33); test_ai still passes; the full suite (127 files) passes

## Notes

- **Stand-ins:** the spell choices are rules of thumb by the ability's kind (from its entry in abilities.lua), not WC3's own AI.
- **Unknown kinds:** abilities the game doesn't know the kind of aren't cast.
- **Building sites** search rings around home up to 2400. Nothing keeps paths between buildings open yet.
