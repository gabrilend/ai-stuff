<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Every question met while turning the vision into documents. Each is to
     be asked and worked through with the owner, one by one. When answered,
     write the answer into the design documents and mark it answered here
     with the date; do not delete it. -->

# Open questions

Each question names the interpretation the documents currently assume, so
the design can move forward while the question waits — but the assumption
is a guess until answered.

## Answered

- **Platform?** LÖVE2D + LuaJIT. (2026-10-10)
- **Who plays at first?** Hot-seat with AI foes; networked play later.
  (2026-10-10)
- **How does time flow?** Real time, with orders in transit. (2026-10-10)
- **Where are you on the map?** Your base is the hub; each team member has a
  quadrant; the map is not to scale; the view compresses like an accordion,
  with two kinds of zoom; heroes are sent a distance measured in levels by a
  dial. (2026-10-10)

## Waiting

1. **What does the rotating rim hold?** Assumed: the stands of the current
   quadrant, one per sector; turning the rim chooses which stand the next
   order goes to. Alternatives: the rim holds order types, or factions, or
   the four quadrants themselves.
2. **What are the two kinds of zoom?** Assumed: *reach* (how many tiers fit
   on screen) and *squeeze* (how much outer tiers are compressed against
   inner ones). Is the second kind instead about unit scale — how big a stand
   is drawn — or about time?
3. **What does the calendar complication control?** Assumed: it is the game
   calendar, and switching day/month sets the vote cadence (the table votes
   every game-day, or every game-month). The vision says some players will
   use it "quite often and/or routinely" — what are they doing when they do?
4. **"Distant players can move faster than near"** — assumed to mean
   tier-time: every tier band takes about the same time to cross, so far-out
   forces cover more real ground per second. Is "players" here the foes far
   away, your own far forces, or both?
5. **Held choices "increase in power the thing it requires if acquired"** —
   assumed: a held choice waiting on an unlock raises that unlock's strength
   when the unlock is bought. Or: the held choice itself grows stronger the
   longer it is held?
6. **Who is the foe in each direction?** Assumed: one opposing player (AI at
   first) per direction, with one outpost per tier. With a team of 4, are
   there exactly 4 foes (one per quadrant), or any number of directions?
   Are foes also teams, sharing a hub of their own further out?
7. **Is the game won?** Assumed: no single win condition yet — fronts are
   decided one tier at a time. What ends a game: reaching a set tier,
   losing the hub, a time limit, or never?
8. **What is a stand made of?** Assumed: a group of units bought from
   factories, gathered at the end of a factory's path. How many units, and
   can stands be merged or split (each would be an order)?
9. **Seats not being played in hot-seat** — assumed: they keep running their
   last orders, and a helper AI handles only defense. Should they instead
   pause, or should the helper AI play them fully?
10. **The voting categories** — assumed: production, upgrades, heroes,
    reserve. What else should a resource be split between?
11. **The courier** — assumed to be a visible spark running from the hub to
    the stand, which can be intercepted? (Currently: cannot be intercepted.)
12. **Text on the rim** — besides stand names, "various pieces of text written
    into various quadrants or smaller sections": what text? Stand status,
    seat names, the foe's name in that direction, lore?
13. **Engineers** — do they come from a factory like any other unit, or does
    the hub make them?
14. **"The round table rotates, so no-one is ever unawares"** — assumed: the
    center of the wheel switches seats, rotating the map so the new seat's
    quadrant faces up. Or does the table rotate on its own over time, so every
    seat periodically faces every direction?
15. **HTML documentation pages** with the feedback inbox, as the house rules
    describe — wanted for this project now, or after phase 1?
