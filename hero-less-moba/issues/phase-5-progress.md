# Phase 5 Progress — Commanders and Heroes

**The goal:** the fast layer. A private wallet filled by every kill the team
lands, bodies bought with it that never come back, abilities that fire on their
own, and the sign-posts that steer them — three per team, one per lane.

**Ends with:** a match where one side's chest sits half-empty while its players
win on hero purchases alone, against a side doing the opposite. Two economies,
visibly distinct.

| Issue | | Status |
| --- | --- | --- |
| 501 | The commander catalogue | built |
| 502 | Killing pays everyone on the team | built |
| 503 | A hero is a soldier you bought | built |
| 504 | Abilities are a dispatch table | built |
| 505 | Spawning onto a wave | built |
| 506 | Spawning onto a tower, and being pushed back | built |
| 507 | Spawning onto the library picks the worst lane | built |
| 508 | Sign-posts stand at the corners | built |
| 509 | Five heroes for the first commander | built, five of them |
| 510 | The healers, and what they remember | one healer, not five |

**Blocking:** nothing.

**Carry into the work:**

- **Every kill your team lands pays every player**, in full. Teammates have
  identical incomes, so the only thing separating two of them is what they do
  with the same money. There is no death spiral in the hero economy.
- **No cap on heroes; a ceiling on the wallet**, and it **rises at each calm**.
  Income arriving at the ceiling is lost — a ceiling *says now* where a hero cap
  would *say no*.
- **Buying is open in every phase.** During the calm a hero waits at the library
  until spawning resumes, which makes the calm the one moment a player can
  deliberately build an opening push.
- **No manual control over a hero at all.** That makes issue 504 far more
  important than its position suggests: with nothing able to intervene, a hero's
  entire personality is its ability *conditions*. The condition table must not be
  three entries deep.
- **Sign-posts are hidden from the enemy and have no locks.** The snapshot
  carries no direction field for the enemy's two — an absent field, not a hidden
  one.
- **No two players on a team share a commander**, checked in the lobby rather
  than the simulation. A team's composition is chosen before anybody has seen
  anything and cannot be corrected.

**Still open:** C4b (how many commanders — a handful with no duplicates gives few
compositions and players will exhaust them fast), B5 (payout per kill).

**Demo:** not yet built.

## Where the prototype got to

The second economy runs. A commander is a captain, a mixture, a bounty and a roster
— four short fields — and the commanders take turns sending waves, so a third of
what leaves a base is somebody else's. Resource is **six colours**, each with its own
shape as well as its own hue, and every body carries the one its commander decided:
**you farm what the enemy fields**, so their selection reaches into your purchases.

Wallets are capped by the die ladder and climb on the match clock, income arriving
at a full colour is lost, and the waste is counted per colour so a player can be told
*which* one they are throwing away. Every kill pays every player on the other team in
full, with no last-hit accounting anywhere.

Heroes buy into all three destinations. A tower whose command radius is not clear
**refuses and names the tower behind it**, which is the rule that makes the outer
towers worth defending before they are in trouble. Abilities are (condition, effect,
cooldown) triples that fire on their own — there is no cast key, and a hero's whole
personality is its condition.

Sign-posts stand at the three junctions, cycle with a click, and are obeyed by
heroes and nothing else. A hero takes one branch and then goes straight on forever;
it walks the connector node by node and joins the far lane at its junction. Tested
end to end.

**510 is a stub.** One healing ability exists — mend, which picks the ally who will
die soonest from health *and* incoming damage rather than from health alone. The
five distinct healers, and the positional obligation that keeps two of them from
reaching for the same body, are not built.

**A catalogue trap was found and is now asserted against.** Both commanders paid
might and neither paid wit, which made two heroes on one of their own rosters
impossible to buy in any match — silently, with no refusal to read. A pair of
commanders defines an economy, and the catalogue owes a check that the pairing can
pay for the rosters it offers.

**Not built:** the bidding half of the resource design — rolling a die per attribute
and paying more for a high pick — which is a large open question rather than a gap.
