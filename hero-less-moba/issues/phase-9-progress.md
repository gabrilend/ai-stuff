# Phase 9 Progress — An Opponent Worth Playing

**The goal:** single-player. A bot built to be played against, which is a
different program from the measuring bot in phase 8 — one wants to be cheap,
deterministic and dull, the other wants to be varied and occasionally wrong the
way a person is wrong. Issue 803 is the first. This phase is the second.

**Ends with:** a person playing a full match alone — two bot teammates, three bot
opponents, lobby to library — and wanting to play another one.

| Issue | | Status |
| --- | --- | --- |
| 901 | What a bot is allowed to see | not started |
| 902 | Reading a board into a handful of numbers | not started |
| 903 | A teammate that does not trample you | not started |
| 904 | Buying bodies and pointing them | not started |
| 905 | Difficulty without cheating | not started |
| 906 | One person, five bots — **capstone** | not started |

**Blocking:** phases 1 through 8. This is the last phase and the only optional
one — everything before it is the game, and the project is complete without it.

**Carry into the work:**

- **The hard problem is the teammate, not the opponent.** Playing alone in a 3v3
  means five bots and **two of them share your chest.** An opponent only has to
  play well; a teammate has to work out what a person is trying to do from
  cursors, locks, and recent placements, and then stay out of it. Too eager and
  the chest fights you; too passive and single-player is solitaire. Issue 903.
- **A bot teammate never objects to a human's lock.** The two-objection rule is
  for people disagreeing deliberately. A bot arguing with its owner is not a
  feature.
- **It cannot cheat, and that is free rather than enforced.** Under F7 the
  enemy's chest and wallets are not on the machine at all, so there is nothing
  privileged to read. Issue 901 builds the rest of the fence and asserts it in a
  test rather than trusting a convention.
- **Difficulty is reaction delay, attention, horizon, and mistake rate.** Never
  information and never bonuses. **Never make the bot's soldiers stronger** — the
  premise of this game is that strength comes from placement, and a bot handed a
  multiplier has been given the one thing no player can be given.
- **A mistake is the second-best option, not a random one.** Senseless reads as
  broken; defensible-but-worse reads as a person.
- **The demo shows reasoning rather than output.** A recorded match replayed with
  each bot's board readings printed alongside, so a viewer can see what it
  thought the board was. Phase 9 is the only phase where that is possible.

**What this phase does not do:**

- It does not touch the simulation. Every bot enters through the same command
  door a person does and is refused for the same reasons.
- It does not replace issue 803. The measuring bot stays, because a bot that runs
  ten thousand times overnight has requirements this one does not.
