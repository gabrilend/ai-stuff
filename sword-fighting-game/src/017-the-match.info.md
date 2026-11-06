<!-- made by scripts/build-info-pages from the comments in 017-the-match.lua; change the comments and rebuild, not this page -->
# 017-the-match


A match is rounds, and a round has four acts, each a row in a table:

  command     the push direction and the perk are chosen (third person)
  approach    the battle begins; the commander throws volleys and raises
              shields while the lines close (third person)
  front_rank  the lines have touched: the player fights as one soldier
              (first person), until the battle ends or the soldier falls
  result      the winner is recorded, the campaign moves, and after a pause
              the next command act begins or the match ends

The match holds no view. A window and a headless run drive the same acts;
the only thing a person adds is choices and intents.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `config, catalogue, seed, opts` | opts.person: a person makes the choices and may drive the player's soldier. |
| `M.begin_command` | `match` | Deals the perk cards and clears last round's choices. |
| `M.choose_for_mind` | `match` | What a commander with no person behind it picks: the straightest push toward the enemy home that is legal, the first card, and to stay a normal soldier. |
| `M.begin_round` | `match` | Ends the command act: records the choices, the enemy chooses, and the battle is set up in the region pushed into, every soldier replenished. |
| `ACTS.command` | `match, dt` | Headless, the mind chooses at once; with a person, the act waits. |
| `ACTS.approach` | `match, dt, intent` | (no comment in the source) |
| `ACTS.front_rank` | `match, dt, intent` | The player's soldier takes the person's intent while they are in it; if it falls, the person is back in the commander's seat. |
| `ACTS.result` | `match, dt` | (no comment in the source) |
| `M.end_battle` | `match` | (no comment in the source) |
| `M.tick` | `match, intent` | One fixed step of whatever act the match is in. |
| `M.summary` | `match` | The person asks to stand in the line (tab). Only once the lines have touched, and only while their soldier stands. What the receipt reads from a match: every finished battle's counters and draws, plus the battle in progress if the run stopped in one. |
| `M.drop_in` | `match` | (no comment in the source) |
| `M.step_out` | `match` | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `ACTS` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `enemy_perk` | `match` | (no comment in the source) |
| `add_totals` | `match, counters` | (no comment in the source) |
