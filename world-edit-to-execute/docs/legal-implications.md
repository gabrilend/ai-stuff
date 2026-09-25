# Legal Implications

What this project does with Blizzard's games, what the law and the games'
licence agreements say about each part, and where the risk sits. Written for
anyone who uses, contributes to, or redistributes the project.

**This is an engineering summary of how US and EU law generally work, written
by the project, not legal advice.** If your situation matters (you run a
public server, you distribute builds, you live somewhere else), ask a lawyer
where you live.

The deeper working notes, with the licence of every component, are in
[licensing-and-boundaries.md](licensing-and-boundaries.md).

---

## The short version

| What | Who does it | Copyright | The game's licence agreement |
|------|-------------|-----------|------------------------------|
| Writing the engine, converter and tools | Contributors | Our own code; no Blizzard expression in it | Binds only contributors who accepted it, and only for what it covers (see below) |
| Reading a custom map (`.w3x` / `.w3m`) | Each user | The map belongs to its author | Maps are "New Materials" made with Blizzard's editor; the licence limits their *commercial* use |
| Extracting stock game values from your own Warcraft III install | Each user, on their own machine | Mostly numbers (facts); some text and art, which aren't used | Yes: the licence forbids reverse engineering without written consent. This is the main exposure |
| Borrowing models and textures from your own WoW 3.3.5a client | Each user, on their own machine | Blizzard's art; never redistributed by the project | The WoW licence and terms have similar clauses |
| Replacement art made by the project's tools | The maker | Theirs, when made independently; the lineage record says how it was made | Not Blizzard's concern unless it copies Blizzard's expression |
| Running a server for other people | Whoever runs it | AzerothCore is AGPL: offer its source to players | Server emulation of WoW's protocol is a well-known grey area; see below |

Nothing Blizzard owns is shipped with the project. Every step that touches
Blizzard's files runs on the user's own machine, from the user's own copy.

---

## Two different rules: copyright and the licence agreement

**Copyright is a law.** It binds everyone. It protects *expression*: Blizzard's
actual code, art, music, sound and text. It does **not** protect ideas, game
rules, mechanics, methods of operation, facts, or functional interfaces
(US Copyright Act §102(b); *Lotus v. Borland*; *Google v. Oracle*, 2021; in the
EU, *SAS Institute v. World Programming*, 2012).

**A licence agreement is a contract.** It binds only the person who accepted it,
usually by clicking through when installing. It can forbid things copyright
allows, such as reverse engineering.

### "Derivative work" means something specific

In copyright, a derivative work *incorporates protected expression* from an
earlier work: a translation, a sequel using the characters, a remix. A program
that **behaves** like another, written without copying its code or assets, is
generally not one. That's why this project's engine and tools aren't
derivative works of Warcraft III, and why the long-term goal (every asset
replaced) puts the finished game outside Blizzard's copyright.

The Warcraft III licence (§2A, in the `License.txt` of an install) also says
you may not "create derivative works based on the Program" without Blizzard's
written consent. A court would most likely read "derivative work" there in its
copyright sense, which an independently written engine doesn't meet. The
clauses that bite harder are the ones next to it: no reverse engineering, no
disassembling, no copying, no modifying. Those cover *studying and extracting
from* the game, not what you build afterwards.

### Tolerance doesn't cancel a right

Many derivative works exist (fan art, fan fiction, private servers), and
Blizzard leaves most of them alone. That doesn't make the clause void:

- Copyright doesn't lapse when it isn't enforced, and choosing whom to pursue is
  lawful. (Trademarks are different: an unpoliced mark can weaken.)
- Narrow doctrines protect a *particular* person who was led to rely on
  permission or who faced an unreasonable delay (estoppel, implied licence,
  laches). None cancels the right for everyone.
- Fan art survives mostly through **fair use** (non-commercial and
  transformative works weigh heavily in its favour) and through the rights
  holder choosing not to act.

### How server emulators stay up

AzerothCore and its ancestors (MaNGOS, TrinityCore) are written from scratch
to speak WoW's protocol and follow its rules; their code isn't Blizzard's. The
exposed parts are those that carry Blizzard's expression: quest text, NPC
names and dialogue, and anything extracted from the client. That is why every
emulator has each user extract data from their own client.

Blizzard has pursued large, public, commercial operations: a US default
judgment of about $88 million against the paid server Scapegaming (2010), and
the 2016 cease-and-desist that closed Nostalrius. Open-source emulator code has
been publicly hosted for well over a decade.

### The case closest to this project: bnetd

*Davidson & Associates v. Jung* (8th Circuit, 2005). Volunteers reverse
engineered Battle.net to build an open-source server for StarCraft, Diablo II
and Warcraft III. Blizzard won on two grounds, and **neither was "derivative
work"**:

1. **Contract.** The developers had accepted the games' licence and Battle.net
   terms, which forbade reverse engineering. The court held that by agreeing,
   they had given up the fair-use defence.
2. **Anti-circumvention (DMCA §1201).** bnetd let copies play online past
   Blizzard's CD-key check, which the court treated as circumventing an access
   control.

Lessons this project follows:
- Nothing here bypasses a CD-key, login or copy-protection check.
- Extraction is each user's own act, from their own copy.
- Code is written so that contributors don't need to reverse engineer
  Blizzard's programs: the formats involved (MPQ, the map files, SLK tables)
  are publicly documented by the modding community.

---

## Numbers, stats and cached values

Game engines and servers keep values: hit points, damage, cooldowns, spell
data. AzerothCore's database holds thousands, and a WoW client caches what the
server tells it. Do those count?

- **In the US, individual values are facts, and facts aren't protected**
  (*Feist v. Rural*, 1991). A *collection* of facts is protected only for any
  creative selection or arrangement, which is thin. **Text** in the same tables
  (quest text, descriptions, names) is expression and *is* protected.
- **In the EU there is also a database right** (Directive 96/9/EC) for
  databases whose maker invested substantially in *obtaining, verifying or
  presenting* their contents. The Court of Justice held in *British
  Horseracing Board v. William Hill* (2004) that investment in *creating* the
  data doesn't count. Game balance values are created by the designer, so the
  database right most likely doesn't cover a game's own stat tables. It is a
  closer question for a database built by *gathering* data, such as an
  emulator's database assembled from recorded traffic.
- **Client-side caches** hold what the server sent: the same values, with the
  same analysis. They are the player's local copy and aren't redistributed.

How the project handles it:
- Only **functional fields** are read from the stock tables: numbers, flags and
  identifiers that maps need to behave the same. Art paths, text and tooltips
  are dropped (issue 112).
- The values are checked against what community wikis publish (a second,
  independent source), and the record says which route produced them and which
  confirmed them.
- The long-term goal is a table of our own, openly described as the
  functional facts maps need for compatibility.

---

## Where you live matters

**United States.** Click-through licences are generally enforced (*ProCD v.
Zeidenberg*, 1996). If you accepted the Warcraft III licence, extracting from
your install is an act under that contract, and the contract forbids reverse
engineering without consent. Individual values remain facts.

**European Union.** The Software Directive (2009/24/EC, Articles 5(3), 6 and 8)
lets a lawful user observe and study how a program works, and decompile it
where needed so that an independently created program can interoperate with
it, **and it voids any contract clause to the contrary.** A program's
functionality and data formats aren't protected at all (*SAS Institute*,
2012). Using your own copy to make custom maps run in an independent engine is
the kind of interoperability the directive has in mind.

**Elsewhere** the rules differ; many countries have interoperability
exceptions of some kind, and some have none.

---

## Where the risk sits, in practice

Enforcement follows power and money: large, public, commercial operations that
redistribute a rights holder's assets or compete with its products. This
project is small, non-commercial, open source, ships nothing Blizzard owns,
and has each user work from their own copy. That is the lowest-risk profile
available. It is not zero, and what remains sits mostly with whoever runs the
extraction under a US click-through agreement.

What the project will not do:
- ship Blizzard's files, art, sound, text or code;
- bypass CD-key, login or copy-protection checks;
- run a public commercial service on Blizzard's content.

## Related documents

- [licensing-and-boundaries.md](licensing-and-boundaries.md): every component's licence and how they combine
- [wow-client-bridge.md](wow-client-bridge.md): how the project uses the WoW client
- `issues/112-stock-object-tables-by-two-routes.md`: the two-route stock values
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/012-asset-replacement-and-provenance.md`: similarity scores and lineage
