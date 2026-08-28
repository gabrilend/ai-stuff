# Conversation Summary: bf8216a7-c949-45c4-930b-b48a72f99cb3

Generated on: 2026-08-24 16:52:14

--------------------------------------------------------------------------------

### User Request 1

❯ hi can you read the vision file, initialize this project, build the issue
files, and make a document in the docs directory that lists all the open
questions you have?


don't look at any sibling projects.


--------------------------------------------------------------------------------

### Assistant Response 1

I'll start by finding and reading the vision file.


Vision read. Now let me scaffold the project structure.


Now the documentation. Starting with the overview and vocabulary.


Now the roadmap.


Now the open questions document you asked for.


Now the issue files. Phase 1:


Phase 2:


Phase 3:


Phase 4 — the chest:


Phase 5 — commanders and heroes:


Phase 6 — the surge and the challenge:


Phase 7 and 8:


63 issue files. Now the phase progress trackers:


Project initialized. Here's what's on disk.


## Structure


The vision file moved from the project root to `notes/vision` — that's the
path the initialization protocol names, and everything else was written from it.
The standard directories exist (`docs notes src libs assets issues`), plus
`issues/completed/demos/`, `docs/HTML/`, and the standing-notes directories
(`input output desire faith strategems`), each seeded with real content rather
than left empty.


The RAM tiers are wired: `tmp/` → `/tmp/hero-less-moba` (executable tier), and
`tmp/shared-memory/` → `/dev/shm/hero-less-moba` (logs and artefacts).
`.file-index-counter` reads 020, matching the highest document index.


## Documentation — 20 numbered documents plus two ledgers


The indices are a reading order across the whole project, not per-directory.
Datapath documents cover: the map as a path graph with nine milestones per lane;
the tick's nine-system dispatch table; the soldier record and its five-state
brain; wave bookkeeping and wipe detection; buffered damage; towers and their
leashed guards; the base and the library; the shared chest; tower slotting and
base inheritance; commanders and personal resource; hero units; sign-posts; the
siege-surge; boons and the challenge; players and the command queue; the viewing
layer; and the house style.


Two things I resolved into design rather than leaving vague, because they came
up repeatedly:


**The milestone system.** Your line about the library-spawn picking a lane "not
in terms of distance as-the-crow-flies, but rather in terms of milestones thru
the map" turned out to be a load-bearing idea, so I built the whole map around
it. Each lane carries nine ordered checkpoints (library, base tower, inner
tower, outer tower, midpoint, and the mirror). Every question about progress is
an integer comparison. A straight-line check gets the "which lane is in trouble"
question backwards exactly when being wrong costs the match.


**Stamp-at-birth.** A soldier copies its lane's upgrade set once, at spawn, and
never re-reads it. That was a performance choice — it stops hundreds of
soldiers reading back into team state per tick — but it produces the design
consequence that moving an upgrade out of a lane doesn't weaken the soldiers
already in it. That delay is what makes a placement a bet, which is what makes
it worth arguing about, which is what your lock-and-ping system is for. Towers
are the opposite: they read live, so stone is the fast option and soldiers are
the slow one.


## Issues — 63 files across 8 phases


Phases cluster functionality by how foundational it is, not by time: the ground
and the clock (9), things that walk and fight (9), things that stand and hold
(7), the shared chest (10), commanders and heroes (9), the surge and the
challenge (8), watching it happen (6), six players (5). The last one, a full
six-player match end to end, is the capstone. Each issue has current behavior,
intended behavior, implementation steps, a blocked-by/blocks table, and its own
open-questions section. All 43 cross-document links resolve.


Also written: eight phase-progress files, `docs/balance-updates.md` (empty
ledger, since no numbers are chosen), and `run-phase-demo` at the root — it
counts executable demos, offers them by number, and currently reports that none
exist and points at the roadmap. Tested.


## `docs/020-open-questions.md`


Fifty questions in five groups. Group A is seventeen rules the vision genuinely
leaves open, each with the working ruling I used, so it's obvious which parts of
the documentation are you speaking and which are me filling a gap. Group B is
unchosen numbers. Group C is the shape of a match, D is presentation and
control, E is technical.


**I have not committed anything.** The parent `ai-stuff` directory is the git
repo and it has a lot of unstaged work from other projects in it; this project
is entirely untracked. Say the word and I'll stage only `hero-less-moba/` and
commit that.


By your own rule, this task is in progress, not delivered — the open questions
need working through one at a time. Here are the four that block the most:


**[Asked the user]**


*Q1 — Who draws:* When a wave is fully defeated, which team draws the upgrade?

- The team that killed it — Winning a lane compounds — you kill more waves,
  you draw more, you win it harder. The siege-surge becomes the only brake in
  the whole design. This is what I assumed.

- The team whose wave died — A built-in rubber band: losing a lane pays you.
  Completely changes the arc of a match and makes the surge less load-bearing.

- Both teams draw — Every wipe pays everyone. Removes the economy as a source
  of asymmetry entirely and makes placement skill the only differentiator.

→ **Selected:** The team that killed it


*Q2 — Who's paid:* Personal resource is "gained when units are slain" —
slain by whom?

- Only your own hero's kills — A hero has to earn back its own price. Spending
  becomes a real investment. Risk: a player who loses their first hero badly may
  never afford a second and falls out of the match. This is what I assumed.

- Any kill by your team — Resource accrues on a schedule regardless of what
  you do, so heroes arrive on a timer and the fast layer stops being a layer.

- A trickle from waves, a lot from heroes — Middle option — nobody is ever
  locked out, but hero kills still dominate. Costs one extra rule to explain.

→ **Selected:** Any kill by your team


*Q3 — Surge trigger:* What triggers a siege-surge? You wrote "every once in a
while."

- A clock the players can see — Planning without surprise. Teams bank resource
  and hold upgrades going into it, and the surge becomes something you prepare
  for rather than survive.

- A hidden clock — Genuinely disruptive, closest to "every once in a while."
  Teams can't prepare, so the scramble is real every time.

- Triggered by the state of the game — Total kills, deepest push, or towers
  felled. Unknowable, and it means a team can accidentally cause a surge by
  playing well.

→ **Selected:** A clock the players can see


*Q4 — Challenge loss:* If a challenge monster isn't stopped — "well, game
over" — game over for whom?

- Only the team it reached — Each monster walks at one team's base and
  destroys that library. Two simultaneous solo tests; one team can fail while
  the other succeeds. The deadline is the walk, so no timer needs explaining.
  This is what I assumed.

- Both teams lose — Makes the challenge a co-operative interlude between two
  enemies — a striking idea, and a completely different feeling three times a
  match.

- A hard countdown, not the walk — A timer on the panel rather than a monster
  you can see approaching. Easier to tune, harder to read at a glance.

→ **Answered:** the team whose library the challenge monster destroyed.". Read
the answers carefully — they may request clarification, changes, or that you
not proceed — and follow what they actually say.


Four answers, and one of them overturns what I'd assumed. Let me propagate them
through the documentation now.


Now editing bottom-up so line numbers stay valid:


All four answers are propagated. Here's what changed and what they created.


## A1 — the killing team draws


Confirmed what I'd assumed, so the documentation just loses its hedge. But
recording it as settled forced the consequence into the open, and it's worth you
seeing it stated plainly:


**The chest is a snowball by design.** A team winning a lane kills more waves
there, draws more upgrades, and wins it harder. Nothing in phases 1 through 5
brakes that. The siege-surge is the only brake in the entire design, and it
works by destroying the *arrangement* rather than the upgrades — a board
rebuilt under fire by three people who disagree is worse than one built at
leisure. That's now written into the waves document and issue 403 as the thing
to look at first if surges turn out not to reset a lopsided match.


## A2 — any kill by your team pays every player on it


This one overturned my working ruling, and it's the largest change. The killer's
owner field is no longer consulted for payment at all — it still decides who
owns a hero for spawn rules and the report, and nothing else. A wave unit, a
tower arrow, a teammate's hero, the last blow on a monster: all pay identically,
in full, to all three players.


What it makes the second economy: **"personal" now means a private wallet, not a
private income.** Teammates earn at the same rate, so the only thing separating
two of them is what they do with the same money — when to bank, which of the
five heroes, which of the three spawn destinations. That's a better axis than
who was better at last-hitting, and the death spiral is gone: a player who buys
a hero, puts it somewhere stupid, and loses it in ten seconds has lost the
purchase and nothing else.


**The cost, and it's new.** A team's income now tracks its map position. Winning
lanes means killing more, earning more, fielding more heroes, winning harder —
the same snowball the chest has, running alongside it. And unlike the chest,
**nothing brakes this one.** The surge empties the chest; it doesn't touch
anybody's wallet. I've written that up as a genuine open question under C3
rather than inventing a floor for it — heroes die permanently, so the
advantage may not persist the way a placement does, and issue 804 is where it
gets measured.


I also renamed issue 502 to match (`502-killing-pays-everyone-on-the-team.md`)
since nothing was committed yet and nothing referenced the old name; roadmap and
phase-5 progress updated to match.


## C1 — a fixed clock the players can see


Settled, and the reasoning is now in the surge document: a hidden trigger
produces one interesting moment, a visible one produces an interesting
*approach* to that moment, three times over. The minutes before a surge become
their own phase with their own decisions.


**It created a problem.** If everyone can see the surge coming, the optimal play
shortly beforehand is to stop placing and let upgrades sit in the chest —
anything placed is about to be yanked back anyway. A team that does this walks
in with a full chest and loses nothing to the emptying, which partly defuses the
mechanism the surge exists for. That's filed as C1b with three ways out (bless
the hold as a skill; make holding cost something; firm up the exact tick only
late), and I did not pick one, because that's your call and issue 804 can watch
for whether it actually matters.


## A9 — the team whose library it destroyed


Confirmed, and it produced a clean implementation consequence: **issue 608
should contain no game-over code at all.** The monster fells the library the way
anything else would and the ordinary win condition does the rest. If a special
case appears there during implementation, something went wrong upstream. The
rejected co-op reading — both teams losing — is recorded rather than
deleted, flagged as the first place to look if the challenge plays flat.


## State


Twenty documents, 63 issues, eight phase-progress files. All 43 cross-document
links still resolve. Four of the fifty open questions answered, two new ones
created — the hero-economy snowball and the pre-surge hold — which is why
the list gets longer before it gets shorter.


The remaining Group A blockers, in the order they'd unblock the most: A5 (what
happens to stone upgrades when a tower falls — my ruling makes them literally
impossible to lose, which may make stone strictly too good), A6 (does a surge
empty stone slots too), A13 (can one player lock everything), and A10 (whose
upgrades a soldier funnelled into the center carries). E2 — fixed point or
floating point — should be settled before phase 2 is written rather than
after, since lockstep turns a last-bit disagreement into two different matches.


Still nothing committed. The parent `ai-stuff` directory is the git repo and has
unstaged work from several other projects in it; say the word and I'll stage
only `hero-less-moba/` and commit that alone.


--------------------------------------------------------------------------------

### User Request 2

Great, keep asking me open questions.


--------------------------------------------------------------------------------

### Assistant Response 2

Next four. Two of them are time-sensitive — one blocks phase 2 from being
written at all.


**[Asked the user]**


*Q1 — Number type:* Should the simulation store positions, health, and damage
as floating point, or as integers with an implied decimal point? This blocks
phase 2 — retrofitting it later is a rewrite of the combat system, not a
change.

- Integers with implied scale — Every value is a whole number divided by a
  fixed constant only when displayed. Integer add and multiply give identical
  results on every CPU, so two machines cannot drift. Cost: multiply needs a
  shift back down, and every division has to be written so it doesn't throw away
  the low bits.

- Doubles, as documented now — Keep floating point and accept that lockstep
  may desync between different CPUs or LuaJIT builds. Simplest to write; the
  failure mode is two players watching different matches with no error message.

- Doubles plus periodic resync — Abandon pure lockstep. A host machine ships
  authoritative state every few seconds to correct drift. No rewrite of the
  combat maths, but much more bandwidth and the host becomes a single point of
  truth.

→ *(no answer recorded)*


*Q2 — Heroes + upgrades:* Do lane upgrades apply to hero units walking in that
lane, or only to wave units?

- Per upgrade — catalogue decides — Each upgrade kind has a bit saying
  whether it reaches heroes; most don't set it. Most flexible, and the most
  surface area to balance. This is what I assumed.

- Only wave units, never heroes — The two economies stay completely separate
  — the chest buys stronger waves, resource buys stronger individuals, and
  neither multiplies the other. A hero walking through a heavily upgraded lane
  looks strangely unaffected by it.

- Heroes too, always — Stacking one lane and buying every hero into it becomes
  multiplicative — the chest and the wallet compound each other. Very strong,
  and likely collapses the game into whichever lane a team picked.

→ **Selected:** Only wave units, never heroes


*Q3 — Losing stone:* Upgrades slotted into a lane's guard towers — what
happens to them when those towers are destroyed? (Remember every lane's stone
upgrades also feed all three of your base towers.)

- Nothing — the base still carries them — An upgrade in a dead lane keeps
  firing out of your base towers. Tower upgrades become literally impossible to
  lose, which may make slotting into stone strictly better than putting it in
  soldiers. This is what I assumed.

- They return to the chest unplaced — You keep the upgrade but must re-place
  it. Losing a tower costs tempo and a decision rather than the investment —
  and it's one more thing to argue about at the worst moment.

- Destroyed with the tower — Losing a tower loses what was in it. Compounds a
  loss into a collapse and makes matches end faster; stone becomes a genuine
  risk rather than a safe harbour.

→ **Selected:** Nothing — the base still carries them


*Q4 — Hero control:* After you buy a hero and choose where it appears, can you
touch it again?

- No — sign-posts only — Abilities fire automatically; the hero walks and
  fights like any other soldier; the only steering is the sign at a junction.
  Keeps "heroes behave like regular units" honest, which is what protects the
  single soldier brain the whole game runs on. This is what I assumed.

- One standing order: hold or advance — You can tell a hero to stop and defend
  where it stands. Small, needs no targeting cursor, expressible as one field on
  the soldier record — but it is the first crack in the one-brain rule.

- One manually triggered ability — The hero's second ability waits for you to
  fire it. Gives your hands something to do in the fast layer, and starts
  pulling attention away from the chest, which is the thing that replaced
  heroes.

→ **Answered:** No — sign-posts only". Read the answers carefully — they
may request clarification, changes, or that you not proceed — and follow what
they actually say.


Three settled, and your fourth answer is a design I hadn't considered — let me
record it properly and then come back to it, because it doesn't close the
question underneath it.


First, one of these answers exposes a contradiction I'd left in the
documentation.


Now A14 — upgrades never reach heroes:


Now recording your resync answer — it's a real design, and I want to be
precise about what it settles and what it doesn't.


Now the three Group A/D entries in the open questions doc:


All propagated — including a contradiction your A5 answer exposed: the towers
document said slotted upgrades return to the chest when a tower falls, which
directly contradicted the stone-falls section two documents later. That's fixed,
and both now say the same thing.


Next four. The first is your resync answer's remaining half.


**[Asked the user]**


*Q1 — Can they drift:* You chose to resync every time a player modifies the
simulation. That settles *where* — but not whether the machines can drift
*between* those points, and that decides what the sync message even is. Six
players can go twenty seconds without issuing a command, and drift compounds.

- No — integers with implied scale — Store 0.0234375 as the integer 1536 and
  divide by 65536 only when drawing. Integer add and multiply are identical on
  every CPU. The sync message becomes 8 bytes, a mismatch is a bug rather than
  drift, and no authority is needed at all.

- Yes — one machine hosts and ships state — Keep doubles. The host's world
  is the truth and it broadcasts enough state to correct everyone on every
  command. Answers E1's authority half at the same time. Corrections are visible
  to players as things jumping.

- Yes — hash first, state only on mismatch — Send the 8-byte hash every
  command; if it disagrees, request full state and stall briefly. Cheap in the
  common case, but still needs a host for the mismatch case, and a stall lands
  exactly when someone just acted.

→ *(no answer recorded)*


*Q2 — Guards:* A guard tower puts guards on the ground to patrol around it.
They're soldiers — not wave units, not heroes. Do any of your upgrades reach
them?

- Nothing reaches them — A tower's patrol is always the same baseline bodies.
  Simplest, and keeps stone from getting stronger still — which matters now
  that A5 made stone unlosable.

- That lane's stone upgrades — An upgrade slotted into a lane's towers makes
  the towers AND their patrols stronger. Stone starts buying bodies as well as
  arrows, compounding an investment the enemy already cannot take away.

- That lane's wave upgrades — Guards are soldiers standing in a lane, so they
  get what your wave units in that lane get. Ties your tower defence to your
  soldier investment rather than to your stone investment.

→ **Selected:** That lane's stone upgrades


*Q3 — Surge + stone:* A5 means the enemy can never take a tower upgrade away
from you. That leaves the siege-surge as the only thing in the game that can
dislodge one. Does the surge actually empty the stone and library slots, or only
the lanes?

- Everything empties — Lanes, stone, and library alike — "all the upgrades"
  reads as all. Your towers go bare during the most dangerous phase in the game,
  so a defensive build is punished harder by a surge than an aggressive one.
  This is what I assumed.

- Only lanes empty — Stone and library keep their upgrades through the surge.
  Towers keep firing while the streams pour in — but stone then becomes
  permanently unlosable to literally anything, which is a very strong place to
  put an upgrade.

- Everything except the library slot — Lanes and stone empty; the last-stand
  slot is protected. A team that has already retreated to its library doesn't
  get its final defence stripped at the worst moment.

→ **Answered:** at the start of the siege-surge, all of the upgrades go to the
library, and they affect units only. The towers aren't in play during the
siege-surge. Once the siege-surge is over, the upgrades get put into the upgrade
chest.


*Q4 — Long matches:* There are three surges and three challenges. A match that
survives all three has no escalation left, no time limit, and no surrender —
it could grind indefinitely. What ends it?

- Surges keep coming — Three is a minimum, not a maximum — the clock keeps
  running and surges and challenges recur on the same schedule. Uses machinery
  that already exists, and each challenge is another chance for someone to fail.

- Sudden death: libraries crumble — After the third challenge both libraries
  begin losing health on their own. The match is guaranteed to end within a
  known window, a genuine stalemate resolves as a draw, and it's visible on the
  map rather than being a number.

- Hard clock, deepest push wins — At a fixed time the match is scored on total
  push depth across the three lanes; equal is a draw. Decisive and quick, but it
  ends the game with arithmetic rather than with a building falling.

- Nothing automatic — surrender only — A match runs until a library falls or
  a team concedes. Honest about what the vision describes, and accepts that some
  matches are very long.

→ **Answered:** the final challenge is always the eternal golem, and it has
infinite health but moves slower the more damage it takes. It recovers speed
fairly rapidly so units have to continuously damage it in order to keep it slow.
It's also fighting on-the-go, and when fighting the siege-surge challenge units
spawn as waves again (but all three lane's worth into the center lane, which is
slightly wider topographically) so the challenge can fight your entire team at
once. The eternal golem however will advance until one of the libraries fall.".
Read the answers carefully — they may request clarification, changes, or that
you not proceed — and follow what they actually say.


That's a substantial redesign in three places. Let me work through it — and
one of your answers breaks something I'd claimed elsewhere, which I need to fix
honestly rather than paper over.


Now issue 107, whose central claim your networking answer invalidates:


Now guards inheriting stone upgrades:


Now the surge redesign — your answer changes what a surge *does* to the chest:


Now the Eternal Golem — this is the piece that closes the match structure:


Editing bottom-up again:


Everything propagated; 63 issues, all links resolve. Four blockers now, three of
them created by your own answers.


**[Asked the user]**


*Q1 — Golem count:* The Eternal Golem — one, or two? The first two
challenges spawn one monster per team, each aimed at that team's base and scored
independently. You wrote "the eternal golem" singular, and "advances until one
of the libraries fall."

- Two — one per team — Matches the established pattern and A9's ruling. Each
  team holds its own back; one can fail while the other succeeds; the winner is
  whoever held longest. The two teams never interact during the endgame — it's
  two solo endurance tests running side by side.

- One — a tug of war — Both teams slow the same body, and it advances toward
  whichever of them is doing less to stop it. The only mechanic in the whole
  design where two teams act on the same object at the same time — and the
  loser is whoever flinches first, not whoever built better.

- One, walking a fixed direction — It always heads for one team's base, chosen
  at spawn (by coin flip, or by who is behind). One team defends while the other
  only has to outlast them. Sharp asymmetry — possibly a comeback mechanic,
  possibly deeply unfair.

→ **Selected:** Two — one per team


*Q2 — Un-aimed:* During a surge every upgrade sits in the library, un-aimed,
applying to all your units in all three lanes. Players can pull one out into a
lane. What makes re-aiming worth the effort?

- Nothing during the surge — only after — Un-aimed is FULL strength
  everywhere, so during the surge you're stronger than usual. The only reason to
  re-aim is that what you re-aim survives the surge, and what you leave in the
  library gets dumped into the chest where it does nothing. A choice between
  coasting strong now and being organised after.

- Un-aimed is a fraction of aimed — A straight dial: an upgrade in one lane
  hits harder there than the same upgrade smeared across three. Re-aiming pays
  immediately. The ratio becomes the surge's whole balance and has to be tuned.

- Un-aimed is full strength but capped — A lane benefits from at most N
  un-aimed upgrades at once, so a big chest is largely wasted while it sits in
  the library. Punishes the team with the most to lose, which is the team the
  surge is meant to disrupt.

→ **Answered:** during a surge the upgrades are always in effect, you can't
pull them out into a lane. Only the center lane is active, all wave units spawn
in the center lane and attack the challenge. However, that's during the
challenge phase. During the siege-surge, when units spawn continuously instead
of in waves, the units spawn for all three waves simultaneously - so instead of
a wave of 5 units every 10 seconds as during normal gameplay, during a
siege-surge it's like 1 unit per lane every half second, for a total of 3 units
per half second, one per lane. Each of these units gets 1/3rd of the upgrades,
randomly selected. So I should clarify - there's three phases in the game -
normal gameplay, which is the majority of the game, siege-surge, which is when
streams of units emerge from the bases with a random 1/3rd of the upgrades, and
the challenge phase, where the waves spawn with their normal timing, but all the
wave units go into the central lane and have to fight the challenge monster.
Challenge 1 is the pillar orc, challenge 2 is the field dragon, and challenge 3
is the eternal golem.


*Q3 — Towers in surge:* You said the towers aren't in play during a
siege-surge. How far does that go?

- They stand and shoot at baseline — Towers keep firing at their catalogue
  values, can still be attacked and felled, but receive no upgrades and can't be
  slotted. The chest can still grow from tower kills during a surge. This is
  what I assumed.

- Genuinely inert — can't shoot or be hit — A surge becomes a pure contest
  of bodies in the open, with the fortifications stepping out of the way. No
  tower can fall during a surge, so nothing at all is earned by anybody for its
  duration.

- They shoot but cannot be destroyed — Towers still defend but are
  invulnerable for the duration, so a surge can't be used to take stone cheaply
  while everything is chaotic. Preserves the defensive line without letting the
  surge be a siege window.

→ **Answered:** they shoot but cannot be destroyed and don't spawn guard
units. During the siege-surge, the guard units spawn as wave units from the
base.


*Q4 — Snapshot scope:* Each sync cycle, one peer publishes state and everyone
accepts it. Positions obviously drift and need syncing. But deaths, wave-wipe
counters, chest contents, and resource are *derived* — two machines could
disagree about what's in the chest, which three people are looking at and
arguing over.

- Positions and health only — Health determines deaths, deaths determine wave
  wipes, wipes determine draws — so syncing health makes everything downstream
  agree on its own. Middle-sized payload, and the derived layer stays honest
  without being shipped.

- Positions and projectiles only — The smallest possible payload and the
  hardest to cheat with, since everything that matters is computed locally. But
  two machines can then genuinely disagree about whether a wave died, and
  therefore about what's in the chest.

- Everything derived, explicitly — Positions, health, deaths, wave counters,
  chest contents, resource balances — all shipped. Machines never disagree
  about anything. Largest payload, and the most surface for a modified client to
  lie about.

→ **Answered:** Positions and health only". Read the answers carefully —
they may request clarification, changes, or that you not proceed — and follow
what they actually say.


That's a much more precise machine than I had. Let me rebuild the phase
documentation around it.


Now the random-third mechanic in the chest document:


Now the issues — 602, 603, 604, 606:


Everything propagated and consistent — the surge is now a genuinely different
machine from what I'd documented, and it's a better one. Next four.


**[Asked the user]**


*Q1 — Golem payout:* The Eternal Golem can't be killed, so the last-blow
payout never fires. Does damaging it pay personal resource at all? This decides
whether the endgame has an economy.

- Nothing — the endgame is spent, not earned — Income stops when the third
  surge ends. Whatever heroes you bought before it are the last heroes anybody
  fields, so the run-up to surge three becomes a spend-it-all-now moment and the
  final minutes are fought with what you already have.

- Damage pays a continuous trickle — Every point of damage pays a little to
  the whole team. The economy keeps running, heroes keep arriving, and holding
  the Golem back funds holding the Golem back — a self-sustaining last stand.

- A bounty each time you slow it past a threshold — Pushing it below a speed
  step pays out once. Rewards coordinated bursts over steady chipping, and gives
  the endgame discrete moments of success rather than a continuous grind.

→ **Answered:** the game is over when the eternal golem destroys a library.
The entire efforts of the teams are spent in slowing that monster down. There's
no need for resources at that point, all your upgrades go to the wave units in
the central wave anyway, so... there's no such thing as a last-blow payout on
the eternal golem. It doesn't die! It's eternal! It's deathless! It's the same
golem in every game, watching you play and learning how you fight! Too bad it
can't do much about it because it's made out of [redacted].


*Q2 — Lock limit:* Can one player lock every upgrade the team owns? Right now
locking is free and unlimited, and two teammates can only undo it one instance
at a time through the two-ping rule.

- A cap of two or three per player — Locking becomes a scarce statement rather
  than a default — you can protect the plan you care about, not the whole
  board. Probably the right shape for something that's really a communication
  channel.

- Unlimited and free — Simplest. One player locking everything is a griefing
  move their teammates can undo, just slowly. This is what I assumed.

- Unlimited, but locks decay — A lock releases on its own after a while unless
  renewed, so an inattentive player's claims dissolve without anyone having to
  fight them. No cap needed, but it's another timer to explain.

→ **Selected:** Unlimited and free


*Q3 — Draw source:* When you draw an upgrade, is it pulled from an
inexhaustible catalogue or a finite deck? This matters more now — a chest of
duplicates scatters differently across a surge stream than a diverse one.

- With replacement — duplicates stack — You can draw the same thing six
  times and build something extremely lopsided. Very roguelike, occasionally
  very unfair, and a chest of six identical upgrades survives a surge's
  scattering almost intact. This is what I assumed.

- A depleting deck, reshuffled when empty — Guarantees variety and makes late
  draws predictable. Every team's chest ends up broad rather than deep, which
  means scattering hurts everyone about equally.

- Duplicates merge into a stronger instance — Drawing a second Sharpened
  Blades makes your existing one stronger rather than adding a second. Fewer,
  chunkier instances — so a random third is a coarser, more dramatic slice,
  and losing one to the scatter hurts more.

→ **Answered:** with replacement, duplicates stack, but both teams get access
to the same choices. What they choose determines who wins, because you're
crafting a better strategy than your foes.


*Q4 — The setting:* There's a library you're defending, guard towers,
commanders, and now a Pillar Orc, a Field Dragon and an Eternal Golem. That's
enough to imply a world but nothing's been decided. What is this place?

- Nobody remembers why — An ancient automated war. The libraries hold the
  records of why it started and nobody has read them; soldiers spawn because the
  machinery still works. Fits a game with no heroes — there are no people
  left, only process.

- The library is the point — Two archives at war over what the other one
  holds. Soldiers are conscripted readers; upgrades are texts they've been made
  to study; the monsters are things that got out of the books.

- The monsters are the land — Pillar, Field, Eternal — they read as terrain
  that woke up. The war between the two bases is incidental and small; what's
  actually dangerous is the ground it's being fought on, and three times a match
  it notices you.

→ **Answered:** Nobody remembers why". Read the answers carefully — they may
request clarification, changes, or that you not proceed — and follow what they
actually say.


Two of those answers are lore, and one line of it I want to preserve exactly as
you wrote it. Let me give the setting its own document.


Now the Golem's payout and its character, into the challenge document and issue:


All propagated — 21 documents now, and the Golem's line is preserved verbatim
in three places. Next four; three of them are the last blockers standing.


**[Asked the user]**


*Q1 — Center stamping:* During a challenge all three lanes' units go to the
center. You said "all your upgrades go to the wave units in the central wave
anyway" — which I want to check, because it has a sting. If every upgrade
applies to every soldier in the center, then placement does nothing during a
challenge, and the no-repeat-lane rule has no phase left to live in at all
(there's no placing during a surge either).

- Everything, to everyone — retire the rule — All your upgrades apply to
  every soldier in the central wave. Simple, legible, dramatic — your whole
  chest lands on one corridor. And the no-repeat-lane rule is honestly retired
  rather than relocated a second time to somewhere it doesn't fit.

- By spawning lane — keep the rule — Each soldier carries the upgrades of
  the lane it was spawned for. Placing into the top lane strengthens one of
  three groups converging on the middle, so the rule still governs something.
  Costs legibility: identical-looking soldiers with wildly different strength.

- Everything to everyone, and move the rule to normal play — Center gets the
  whole chest, and the no-repeat rule applies during ordinary gameplay instead
  — so no player can ever place into the same lane twice running, all match
  long. Much stronger constraint than the vision described.

→ **Selected:** By spawning lane — keep the rule


*Q2 — Same draws:* You said both teams get access to the same choices. Does
that mean the same catalogue — or literally the same draw sequence?

- Same table, independent draws — Both teams roll from the same weighted
  catalogue, so nobody has access to a card the other can't get — but one team
  might draw Sharpened Blades three times and the other never. Equal access,
  unequal outcomes. This is what the docs currently say.

- Same sequence — a race, not a lottery — Team 1's fifth draw and team 2's
  fifth draw are the same kind. Killing more gets you there sooner, so the
  leader is ahead on the same track rather than holding different cards. Removes
  the last luck in the design and makes the enemy's chest readable as your own
  from two minutes ago.

- Same sequence, but each team can reorder — Both teams get the same upgrades
  in the same order, but a team can hold one back to take the next instead.
  Shared track with a small lever on it — more decisions, one more rule to
  explain.

→ **Answered:** same sequence, but players can spend resource to put one of
their upgrades at the bottom of the deck and draw the next one immediately. This
means fewer heroes however...


*Q3 — Trust:* Each cycle one peer publishes positions and health, and everyone
accepts it without argument. Rotation means every player gets a turn to publish
— and nothing stops a modified client publishing a version where its own units
are healthier.

- Accept it — this is a game among friends — No detection, no defence.
  Correct for people who know each other, and it costs nothing to build. If the
  game ever needs competitive integrity, that's a different networking model and
  a different project.

- Sanity-check on receipt — Each peer compares the incoming snapshot against
  its own and rejects any value that moved further than the elapsed time could
  explain. Catches crude cheating cheaply; catches nothing subtle; adds a
  tolerance that has to be tuned.

- Publish the diff, not the state — A peer sends what changed since the last
  accepted snapshot, and others apply it only where their own value is within
  tolerance. Harder to abuse and smaller on the wire, but a peer that falls far
  behind can't be corrected in one message.

→ **Answered:** sanity check on receipt. Compare against the units who are in
range or within capability of affecting the target unit, for each unit. Only
compare when the values differ from the local simulation.


*Q4 — Boons:* A boon arrives when each surge ends — permanent, applies to
all three lanes, can't be moved, and is the only thing not scattered by a surge.
Who gets one, and do they pick it?

- One per team, handed over — Three boons per team by match end. Fast —
  keeps the pressure on the monster that just appeared rather than on a menu.
  This is what I assumed.

- One per team, chosen from three — The standard roguelike shape, and an
  agency spike at exactly the moment the challenge lands. But it's a menu
  opening while something enormous starts walking.

- One per player, handed over — Nine permanent lane-wide upgrades per team by
  the end. A much heavier late game, and each player has one thing that's theirs
  in a system that's otherwise entirely shared.

- One per player, each chosen from three — Maximum agency and maximum
  late-game power. Three people each picking from three options while a monster
  walks — chaotic, and possibly the most memorable moment in a match.

→ **Answered:** one per player, each chosen from three, but there's a brief
period after the challenge monster is slain where you are free to choose, so it
isn't chaotic. The boon comes from slaying the challenge monster, not ending the
siege-surge.". Read the answers carefully — they may request clarification,
changes, or that you not proceed — and follow what they actually say.


Two of those change things I'd stated flatly as never happening. Let me fix
those first — one of them is a direct contradiction.


Now the shared deck and the reroll, in the chest document and a new issue:


Now the boons restructure — they come from slaying the monster, not from
ending the surge:


Now the trust check — your algorithm is a causality test, not a tolerance:


Now the boons and the remaining two entries:


All propagated — 22 documents, 64 issues, every phase now buildable. Next
four.


**[Asked the user]**


*Q1 — Reroll sight:* When a player pays to reroll, can they see what the next
card is before they commit?

- Yes — the next card is visible — Rerolling becomes a decision, which is
  what the rest of this design consistently prefers. But it also means a player
  can see when the deck is about to hand them something excellent and simply
  wait — the deck becomes a thing you read rather than receive.

- No — you pay into the dark — Rerolling is a gamble: you know what you're
  discarding, not what you're getting. Keeps some roguelike texture in a design
  that has systematically removed luck, and stops players farming the deck's
  order.

- Only your team's next card, and the enemy can see it too — You see what's
  coming; so does the other team, since it's the same deck. Everyone knows what
  everyone is about to hold, and a reroll becomes a visible, readable decision
  that your opponent watches you make.

→ **Selected:** No — you pay into the dark


*Q2 — The calm:* The calm is the phase after a challenge monster dies —
nothing spawns, each player picks a boon from three, and the whole chest gets
re-placed. How much of a pause is it really?

- Spawning stops, the field drains, it's quiet — The map empties out while you
  choose. The most distinctive beat in the game — twice a match everything
  genuinely stops. Risk: a real-time game going quiet can feel like it broke.

- Spawning stops but bodies keep fighting — No new waves, but whatever's
  already out there finishes its business. The lane thins gradually rather than
  emptying, so there's still something to watch while people choose.

- Everything continues — the calm is just the boon window — Waves keep
  coming and the game never pauses; the calm is only the period during which
  boon choices are accepted. Least disruptive to pacing, and least of a reward
  — you're choosing under pressure again.

→ **Answered:** all the units go home and players have a little bit of time
(30s to a minute, depending on testing) to select a boon and re-organize their
upgrades. After the calm, units start spawning again.


*Q3 — Fog of war:* Both teams draw the same deck in the same order, so a team
can already infer roughly what the enemy holds by counting their draws. That
reframes fog of war: it's no longer about *what* they have, but *where they put
it*. Can you see the enemy's placements?

- No — you read the frontline and infer — You know what they hold; you don't
  know their arrangement. The whole game becomes reading three lanes and
  deducing where their strength went. More interesting, and much harder to make
  legible.

- Yes — everything visible — Their chest, their slots, their locks. The game
  is one of visible commitments and counters — you can see them stack the top
  lane and respond. Legible, and removes deduction entirely.

- Placements visible, but one wave late — You see where their upgrades were as
  of the last wave that spawned, not where they are now. Since a soldier is
  stamped at birth anyway, this is arguably the honest view — you're seeing
  what's actually on the field.

→ **Answered:** upgrades take one full wave to move, and during this time
period allies can see that they're marked to move. When looking at enemy units
on the frontline, you see their upgrades, but the current status of their
upgrade placement is unknown. It takes 2-3 waves before any changes are visible,
because they have to spawn and walk toward the enemy base.


*Q4 — The third:* During a surge each body carries a random third of the
chest. Exactly one third every time, or one-in-three odds per upgrade?

- Exactly one third, every body — Every soldier carries the same number of
  upgrades, just different ones. Predictable, easy to balance, easy to explain.
  This is what I assumed.

- One-in-three odds, rolled per upgrade — Same average, real variance — some
  bodies come out nearly bare, others nearly whole. Occasionally one soldier in
  the stream is carrying almost your entire chest, which is a soldier somebody
  remembers.

- Exactly one third, but never the same third twice running — Guarantees the
  stream cycles through your whole chest rather than re-rolling the same
  combination. Everything you own reaches the field on a predictable rotation.

→ **Answered:** during a surge, each lane spawns one unit per half second or
whatever makes sense. that time period occurs at the same time for each lane -
it's the same timer. When spawning a siege-surge unit, iterate through the three
units continuously, assigning a random upgrade each time, until there are no
more upgrades to distribute. Start on a random lane each time, to ensure that if
there's a number of upgrades that isn't divisible by 3 that the one with
one-fewer upgrade is randomized each time.". Read the answers carefully — they
may request clarification, changes, or that you not proceed — and follow what
they actually say.


Four more, and one of them replaces a mechanic I'd described loosely with a
precise dealing algorithm. Starting with the biggest — upgrades now take a
wave to move.


Now the surge dealing algorithm — this replaces "a random third per body":


Now the calm — units walk home, and that resets the frontline:


Propagated. Two things this round were corrections to my own writing rather than
additions, so worth flagging plainly:


**The surge is a deal, not a sample.** I'd written "each body gets a random
third," which wastes the chest — some upgrades land on nobody in a given
instant. Your version has all three lanes spawn on *one shared timer* and deals
the whole chest across the three bodies, starting at a random lane so the short
share rotates. Every upgrade is on the field at every instant, no two of the
three carry the same one, and the lanes flatten perfectly. Issue 603 was
rewritten and renamed for it.


**The calm resets the map.** "All the units go home" turned out to be a
structural statement, not a detail. Twice a match every soldier reverses and
walks back to its base, so the frontlines reset to nothing — a match now has
**three fresh starts**, where the territory resets but the stone and the chest
don't. What carries forward is what you built, not where you were standing. That
also forced a correction in the map document: push depth is a measure of living
soldiers, not a high-water mark, so it can go *down*, and the calm is the one
moment it needs a full recompute.


Also: I'd stated flatly in two places that the two economies never touch and no
exchange rate exists. The reroll makes that false, and both are corrected.


Twenty-eight questions answered, every phase buildable. Next four.


**[Asked the user]**


*Q1 — Heroes, phases:* Can you buy heroes during a challenge and during the
calm? The calm is new and awkward here — everything on the field is walking
home, so a hero bought then would have nowhere to go and nothing to fight.

- Challenge yes, calm no — Heroes are a real answer to a monster, so buying
  continues through the challenge. During the calm, purchasing is closed — the
  map is emptying and a new body would be walking home the moment it spawned.

- Both — a hero bought in the calm waits at base — You can spend during the
  calm and the hero stands at your library until spawning resumes, then marches
  out with the first wave. Lets a player convert banked resource into a strong
  opening push.

- Neither — buying is normal-play only — The challenge becomes purely a test
  of what your chest and your waves can do, with no way to throw money at it.
  Sharpens the phases: normal play is where you spend, challenges are where you
  find out.

→ **Selected:** Both — a hero bought in the calm waits at base


*Q2 — Hero cap:* Is there a cap on how many of your heroes can be alive at
once? Right now resource is the only limit — a player who banks through two
surges could put six on the field together.

- No cap — resource is the limit — Banking and dumping is a legitimate
  strategy. A player who saved through a surge gets a genuine spike. Risk: it's
  the degenerate play everybody finds on day one. This is what I assumed.

- A small cap, three or so — Forces spending to be paced rather than hoarded,
  and makes each purchase matter more since you can't just add another. Also
  caps how much a rich team can convert income into bodies at one moment.

- No cap, but each hero costs more while others live — Your second
  simultaneous hero is dearer than your first, your third dearer again. Banking
  still works but pays diminishing returns, so a spike is possible and expensive
  rather than free.

→ **Answered:** no cap, but there is a cap on resource, meaning you need to
spend it or else it'll overflow.


*Q3 — Commanders:* How many commanders exist, and can two players on the same
team pick the same one? Each is a resource name plus a roster of three-to-five
heroes covering distinct jobs.

- A handful, and duplicates allowed — Four or five commanders to start, and a
  team can run three of the same. Simplest, and a mirror team is a legitimate
  specialist composition rather than an error.

- A handful, no duplicates per team — Forces a team to field three different
  rosters, so the three players' hero options never overlap. More variety per
  match, and one more lobby rule to explain.

- Many, and duplicates allowed — A dozen or more, which makes commander choice
  a real identity and a real thing to learn. Much larger design job — and
  doing it badly gives every commander the same five heroes with different
  names.

→ **Selected:** A handful, no duplicates per team


*Q4 — Stone and lanes:* During the post-surge scramble, no player may place
into the same lane twice running. Does slotting an upgrade into a lane's *stone*
count as placing into that lane?

- Yes — stone is that lane — Otherwise a player alternates lane-then-stone
  in the same lane forever and the rule does nothing at all. Keeps the rule's
  teeth. Leaves the library, which belongs to no lane, still needing an answer.

- Yes, and the library counts as "no lane" — Stone counts, and a library
  placement neither trips the rule nor resets it — it's simply not a lane
  placement. Clean, but it means library placements are a free move that dodges
  the constraint.

- No — only lane placements count — Stone is a different kind of decision
  and shouldn't be constrained by a rule about lane attention. Simpler to
  explain, and it hands players an obvious loophole.

→ **Answered:** I changed my mind, we should remove the "no placing into the
same lane twice" rule. It's stupid and arbitrary. Can you prune it away from
everywhere it's mentioned? No need to record it anywhere except maybe the vision
document.". Read the answers carefully — they may request clarification,
changes, or that you not proceed — and follow what they actually say.


Removing the no-repeat-lane rule. Let me find every place it lives.


Now the open-questions document — removing the rule and recording the three
new answers:


Now the three new answers — the resource cap is a new mechanic:


Pruned completely — issue 604 deleted, 63 issues remain, and the rule survives
only as one line in the roadmap's deliberately-absent list so nobody re-derives
it from the vision. Two notes on that round:


**The resource ceiling is a better limiter than a hero cap**, and the reason is
worth keeping: a hero cap *says no* — it refuses a purchase a player already
decided to make, for a reason unrelated to what's in front of them. A ceiling
*says now* — it never refuses anything, it just means sitting on a full wallet
is actively losing every kill your team lands. It also gives the reroll a job it
didn't have: a player at the ceiling with nowhere good to put a hero can convert
resource that would evaporate into a chance at a better chest.


**No duplicate commanders per team** has a consequence worth building toward: a
team's composition is chosen in the lobby and can't be corrected. If nobody took
an answer to stone, that team has no answer to stone all match.


Thirty-one answered. Four left that matter.


**[Asked the user]**


*Q1 — The ceiling:* How big is the resource ceiling? It has to be high enough
to afford your most expensive hero with room to think, and low enough that a
surge can't be banked through. Those two might not both be satisfiable.

- Your most expensive hero, plus a little — Tight. You are spending almost
  constantly and overflowing the moment you hesitate. Makes the fast layer
  relentless — and makes a player who looks away for twenty seconds genuinely
  poorer.

- About two of your most expensive — Some banking is possible, so a deliberate
  spike is a real play. Room to hold for the right moment without punishing a
  player for thinking. Won't stop a full surge being banked through, though.

- Grows as the match goes on — The ceiling rises over time, so late-game
  spikes get bigger and early play stays tight. Matches the boons' accumulating
  floor — but it's another curve to tune, and it rewards surviving rather than
  winning.

→ **Selected:** Grows as the match goes on


*Q2 — Reroll price:* What does a reroll cost? Remember you're paying blind —
buying a distribution, not an outcome — and it competes directly with buying a
hero.

- A fixed fraction of your ceiling — Always the same relative bite, so it
  scales automatically with whatever the ceiling turns out to be. A player at
  cap can always afford one, which is exactly when they should be tempted.

- Flat, roughly a cheap hero — Predictable and easy to reason about: one
  reroll equals one small body. The tradeoff is legible in the most direct
  possible terms.

- Escalating per reroll this match — Your first is cheap, your fifth is dear.
  Stops a rich team rerolling its way to a perfect chest, and makes each one a
  bigger decision than the last.

→ **Selected:** Flat, roughly a cheap hero


*Q3 — Ping expiry:* Two pings from two different teammates force a lock open.
Do pings expire, so that the two objections have to be roughly contemporaneous?

- Yes — they expire after a while — The two objections have to overlap in
  time, which makes them a decision rather than an accumulation. Without expiry,
  a ping left over from four minutes ago combines with a fresh one and the
  two-ping rule quietly becomes a one-ping rule.

- No — a ping stands until answered — Simpler, and it means a teammate who
  objected and then got busy still counts. But on a long match every lock
  eventually collects enough stray pings to pop on its own.

- They expire, but the locker sees them the whole time — Pings decay for the
  purpose of forcing the lock, but the locker keeps a running record of who has
  objected and how often — so repeated objection is visible even when it never
  reaches two at once.

→ **Selected:** Yes — they expire after a while


*Q4 — The camera:* The whole design assumes a player can see all three lanes
at once — that's what makes an upgrade "legible from across the map," one of
the three reasons the chest replaced heroes. Does the map fit on one screen?

- Yes — the whole map, always, no camera — Fixed view of everything.
  Soldiers are small and the frontlines are the loudest thing in the frame.
  Preserves the core assumption at the cost of ever showing anything in detail.

- Whole map by default, zoom to inspect — You always start seeing everything
  and can push in to read a specific lane or a soldier's upgrades, then pull
  back. Keeps the assumption while allowing detail — and adds a camera to
  build and to fight with.

- A scrolling camera, with a minimap — Conventional. You see one region in
  detail and read the rest from a minimap. The assumption breaks: the chest
  panel has to carry much more, since you can no longer judge a lane by looking
  at it.

→ **Selected:** Whole map by default, zoom to inspect


Four clean ones. Propagating.


**Group A is finished.** Every rule the vision left open now has an answer, and
no phase is blocked by a design question. 23 documents, 63 issues, 36 questions
settled.


Two of this round's answers cohere with things already in the design in ways
worth naming:


**The ceiling growing at each calm** puts the wallet on the same rhythm as the
boons. Both economies accumulate a floor as a match runs, so the late game is
simply bigger on both axes — and since the third challenge has no income at
all, the run-up to the final surge becomes a fill-the-tank moment, with the
Eternal Golem fought on a wallet that will never be topped up again.


**"Zoom reveals detail. It never reveals events"** is the rule that makes the
camera safe. Anything a player must react to has to be legible at the whole-map
default. The failure it prevents is the one every game with a camera has — a
player looking at the wrong place at the wrong time, punished by information
they were never going to have — and in a game where three people share one
chest, that failure lands on the whole team rather than the person who looked
away.


One consequence I noticed and flagged rather than smoothed over: a **flat**
reroll price against a **rising** ceiling means rerolling gets cheaper in real
terms as a match runs. That's probably right — with a shared deck, late
rerolling is the main way two teams holding the same cards end up holding
different ones — but it's a curve nobody chose, so it's filed as A16c for
issue 804 to watch.


The tail is short now. Four more.


**[Asked the user]**


*Q1 — Drawing:* Which drawing library? This is now the only decision left in
the project with a deadline — it falls due at issue 701, and the terminal
viewer is what's been making it comfortable to postpone.

- LÖVE — The obvious LuaJIT answer. Window, sprite batching, input and audio
  for free, and it's already LuaJIT so no FFI boundary. You inherit its choices
  about how a frame works, and its distribution story.

- An FFI binding to SDL or similar — You write the window, the loop, and the
  batcher yourself against a C library. More control over how thousands of
  soldiers get drawn, and a lot more work before anything appears on screen.

- Decide it at issue 701, not now — Record both candidates and keep going.
  Phases 1 through 6 don't need a window, the terminal viewer covers
  development, and the choice is better made when there's something real to
  draw.

→ **Selected:** LÖVE


*Q2 — Sign-posts:* Sign-posts stand at four junctions and route heroes. Two
questions that go together: can the enemy see which way yours point, and can a
teammate change one you set?

- Enemy sees them; teammates can freely change — They're physical objects
  standing in the world, so everyone sees them. No locks — they're instant and
  reversible, so a negotiation layer would be ceremony with nothing under it.
  This is what I assumed.

- Enemy sees them; teammates need the lock system — Visible to all, but a
  sign-post can be locked and ping-unlocked like an upgrade. Consistent with how
  the chest works — and three players fighting over two sign-posts during a
  scramble might need it.

- Hidden from the enemy; teammates free — You can't read the opponent's
  standing orders. Consistent with the fog being made of walking — you learn
  where their heroes go by watching heroes arrive, not by reading a sign.

→ **Selected:** Hidden from the enemy; teammates free


*Q3 — Map ping:* "Ping" already means something specific and consequential —
two of them force a lock open. Should there also be a general map ping, the
thing every team game has for pointing at a place?

- Yes, and it needs a different name — Teams need to point at places. But
  reusing "ping" for two mechanics with different consequences would be a real
  mistake, so the map one gets its own word.

- No — cursors already do this — Every player's cursor is synced and visible
  to teammates. Pointing at a place is just moving your mouse there, which is
  what a ping is imitating anyway. One fewer verb.

- Yes, and rename the upgrade one instead — "Ping" goes to the map, where
  players expect it, and the lock-objection verb gets a name that says what it
  does — something closer to "object" or "call."

→ **Selected:** Yes, and rename the upgrade one instead


*Q4 — Cancel a move:* An upgrade you've placed takes one full wave to arrive,
and teammates can see it marked to move the whole time. If you misclick, can you
call it back?

- No — a placement is a commitment — The wave of notice exists for teammates
  to react, not for you to change your mind. But a player who misclicks then
  watches their mistake arrive for a full wave, which is a long time to be sure.

- Yes, but it costs another full wave — You can recall it, and it takes a wave
  to come back — so a misclick costs two waves of that upgrade being in the
  wrong place rather than being permanent. Symmetric and self-explaining.

- Yes, freely, until it lands — Cancel any time during transit at no cost.
  Kindest to misclicks — and it means the marked-to-move message teammates
  rely on can evaporate without anything happening.

→ **Selected:** Yes, freely, until it lands


Four settled, and one is a rename that ripples through the whole project. Let me
handle that carefully first.


Rename is clean. Now adding the map ping as its own verb:


Now the three remaining answers — sign-posts hidden, cancel freely, and LÖVE:


**Groups A and D are finished, and nothing in the project has a deadline any
more.** Forty questions settled. 23 documents, 63 issues, all links resolve.


The rename was the big one. `ping` → `object` ran through every document and
issue: `ping_upgrade` became `object_upgrade`, `ping_mask` became
`objection_mask`, and two issue files were renamed. It made the prose *more*
consistent rather than less — I'd already been writing "two objections have to
overlap in time" throughout without noticing the word didn't match the verb.
**"Two objections open a lock" explains itself; "two pings open a lock" never
did.** `ping_map` is now the map marker, which is what players arrive expecting
the word to mean.


Two things I had to reconcile rather than just add:


**Two different passages both claimed to be "the third verb."** The cursor said
it, and marked-to-move said it. There are actually five, and the interesting
fact only shows up once they're listed together: **two of the five are
involuntary.** Your cursor is synced continuously and a placement announces
itself for a whole wave — so you can see a teammate reaching for something
*before* they touch it and see what they did for a wave *after*. Locks and
objections are only for the cases that survive all that visibility and still
need settling. That table is now canonical in the chest document and everything
else points at it.


**Sign-posts hidden from the enemy has an implementation consequence worth
carrying:** the snapshot contains *no direction field* for the enemy's
sign-posts — not a hidden field the viewer declines to draw, an absent one. A
viewer cannot leak what it was never sent. It's the only place in the whole
snapshot where a field is withheld by team.


What's left is Group B, and Group B isn't answered by thinking. Every number in
it is found by running the thing — including the one the whole project turns
on:


> **B11 — does the frontline actually move?**


The vision's premise is that a lane-pusher with the heroes subtracted out
stalemates. Nothing in twenty-three documents proves the shared chest, the two
economies, and the surges are enough to unstick it. The phase-2 demo shows the
stalemate; the phase-4 demo shows it broken in one hand-arranged case; issue 804
is where it's shown in general — or where the design is found to be wrong,
which is worth knowing early.


I can keep asking, but the remaining questions are honestly thin: a few curves
nobody chose deliberately (A16c, A11b-iii), what happens when one team's monster
dies first (A8c), how many commanders (C4b), and whether the hero economy needs
a brake (C3) — which is itself a "measure it" question. My recommendation is
to stop asking and start building phase 1, and let the numbers answer the rest.
Still nothing committed; say the word and I'll stage `hero-less-moba/` alone.


--------------------------------------------------------------------------------

### User Request 3

by the way, the license for this project is AGPL


can you initialize the git repository with the first commit? But, first make
sure all the issue files are built.


--------------------------------------------------------------------------------

### Assistant Response 3

Two things before the commit: finish the audit, then the license. Starting with
whether the issue set is actually complete.


Good — that stray line was an orphan, now gone. Fixing the capstone's missing
sections:


Now the real audit — work created by later answers that no issue file covers.


Now the phase table is missing the calm, and the map ping has no implementing
issue:


Those are development phases, not runtime phases — correct as-is. Now the map
ping, which has a verb but no implementing issue:


Every issue file exists, is complete, and agrees with the roadmap and its phase
tracker. Now the license — let me find the canonical AGPL text on this system
rather than transcribing it.


No AGPL text on this system, and I won't transcribe a license from memory — an
inaccurate license text is worse than none. Fetching the canonical copy:


Genuine AGPL-3.0 — section 13 present, correct preamble and closing.


Everything's in place. Initializing the repository:


Done. Committed as `a2a17d3` — 112 files, 13,773 lines, working tree clean.


## The audit first


The structural check found four real problems, all silent damage from my own
earlier line-range edits:


- **Two issues had vanished from the phase-4 tracker.** "A soldier is stamped at
  birth" and "Locking a placement" had been overwritten by a stray fragment of
  another paragraph sitting inside the table.

- **The capstone was missing its required sections.** It had a "The capstone"
  heading instead of current/intended behavior.


Then a content audit for work that later answers created but no issue covered
— four more gaps:


- **Issue 105's stream table was two streams out of date.** `draw` had become
  `deck` and stopped being per-team; `surge` didn't exist. It's now the busiest
  stream in the project and the note explaining *why it can't be shared* wasn't
  written down anywhere.

- **The map builder had no lane width parameter**, despite the center lane being
  permanently wider — the one real difference between the three lanes.

- **The phase table had four rows and the game has five.** The calm was a phase
  everywhere except in the table that's supposed to be the single source of
  truth for phases. That also meant game-over was numbered 4 in one issue and 5
  in reality.

- **`ping_map` was a verb with no implementing issue.** It's now in 704 along
  with the canonical five-verb table.


I also caught a stale claim in the house-style document: it still described the
determinism test as underwriting the network, which stopped being true when the
networking model changed.


## The licence


`LICENSE` is the genuine AGPL-3.0 fetched verbatim from gnu.org — 661 lines,
section 13 present, correct preamble and closing. **I deliberately didn't
transcribe it from memory or derive it from the GPL-3 text that's on this
system**; a licence that's subtly not the real licence is worse than none.
`COPYING.md` carries the notice block for source files and the reasoning, and
doc 018 now says the file-creation tooling stamps it rather than a person —
hand-copied boilerplate is exactly what rots.


## One choice you should know I made


You said "initialize the git repository," so I ran `git init` **inside
`hero-less-moba/`, making it a standalone repo**. That departs from the sibling
pattern — the other projects in `ai-stuff/` are tracked directly by the parent
repo, which is still sitting there with unstaged work in it.


I went this way because "initialize" reads as `git init`, a fresh AGPL project
reads as standalone, and it sidesteps the dirty-parent problem entirely. It's
also trivially reversible: `rm -rf .git` and the files are untouched. If you'd
rather this live in the parent repo alongside the others, say so and I'll undo
it.


Five empty directories would have vanished — git doesn't track those — so
`src/`, `libs/`, `assets/`, `docs/HTML/` and `issues/completed/demos/` each
carry a short `.gitkeep` saying what belongs there. The `tmp/` symlink is
correctly excluded, and `run-phase-demo` kept its executable bit.


--------------------------------------------------------------------------------

### User Request 4

oh... no we should have hero-less-moba be part of the monorepo. Sorry.


are all the issue files written? If so, can you do another audit to try and
catch any mistakes or open questions? Also, if you could succinctize them now
that they're all written by referencing documentation when appropriate, that'll
help.


--------------------------------------------------------------------------------

### Assistant Response 4

Undoing that first — my mistake, and it's clean to reverse since the content
is untouched.


Back in the monorepo as untracked, exactly as it was. Now the audit — starting
with what's mechanically checkable.


Now the substantive audit — hunting for claims that later answers invalidated.


Let me stop fighting sed on that block and fix it properly.


Issue 404 has three separate statements about a cooldown that no longer exists.
That's the succinctization problem in miniature — let me rewrite it as the
model for the rest.


156 lines to 84, with the contradictions gone. Applying the same treatment to
the rest of the bloated files:


Normalizing the section names first, then compressing the redundant rationale:


Now the remaining "Settled" sections — these are the pure duplication of doc
rationale:


Now normalizing the header tables so every issue points at its documents the
same way:


That's the real find — 30 issue headers cite questions that have since been
answered. Let me fix them, and one genuinely dangling reference:


These validators have ongoing use, so they belong in the project rather than my
scratchpad:


Now updating the open-questions summary to match what the validator actually
reports:


phase-1 still claims a blocker that was answered. Let me rewrite all eight
trackers to a consistent, tight shape:


Audit clean and the writing is tighter. Committing to the monorepo now, staging
only this project:


Committed as `1b0a4370` on top of the existing monorepo history, alongside its
siblings. 113 files tracked, working tree clean for this project, and the 18
modified sibling files plus their untracked ones are exactly as I found them.


## The repo fix


Removed the nested `.git` and staged only `hero-less-moba/` by explicit path, so
the commit touched nothing belonging to the other projects. The standalone
commit's content was identical, so nothing was lost — but it's worth saying
plainly: **that commit's history is gone**, since the nested repository was
deleted rather than merged. Only ever one commit's worth, and its message is
preserved in this one.


## The audit found real rot


Structural checks passed, so I went looking for semantic drift instead. Three
classes of problem:


**Stale mechanics.** Four places still referenced a per-team `draw` stream,
which stopped existing when both teams started drawing from one shared deck. Two
documents still described the `is_boon` field as "came from surviving a surge,"
which stopped being true when boons became payment for slaying a monster. The
instance record was missing `owner`, `deck_index`, and the three transit fields
entirely — they'd been described in prose but never added to the tables.


**Thirty stale question citations.** This is the one worth flagging. Every issue
header carries an "open questions" row, and **26 of them cited questions that
had since been answered** — issue 104 still claiming to wait on fixed-point,
issue 702 still waiting on three separate D-group questions. Answering a
question means editing the document it changes, and it's easy to leave a dozen
issue files claiming to be blocked on something settled. One reference, `E7` in
the bot issue, pointed at a question that had never existed; I wrote it (whether
this ships single-player, which decides how good the bot must be).


**A contradiction inside one file.** Issue 404 stated three separate times that
there was a reassignment cooldown, a rule replaced by the one-wave transit, and
still had an implementation step telling you to build it.


Because that fourth class of rot will recur every time a question gets answered,
I turned the throwaway checks into `./validate-documentation` — a real project
tool with the standard `${DIR}` header. It's a compiler for the written half:
links, issue structure, roadmap agreement, and stale question citations. It
exits non-zero, so it can go in a build.


## The succinctization


Issues went from 5,553 lines to 4,891; the phase trackers from 531 to 346. The
pattern was accretion — every answer had appended a "Settled" section
restating rationale that already lived in the documents. Those are now
two-to-four-line statements of *what to build* plus a link to the document
explaining *why*, and the header tables link their documents by title instead of
naming bare paths.


Where an issue kept prose, it's because the fact isn't in a document and would
be lost: that `tower_mask` must never be cleared by a tower dying, that the deal
is only possible because all three lanes share one spawn timer, that if leashing
is ever loosened the guards-inherit-stone rule is the one that breaks first.


**The one thing I'd flag as still unsatisfying:** A4 — whether the vision's
"guards in the base" meant soldiers or towers. Issue 305 implements both
readings, which is defensible and is not a decision. It isn't blocking anything,
but it's the last place where the documentation is hedging rather than choosing.


--------------------------------------------------------------------------------
