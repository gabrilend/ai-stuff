# 010 — Open questions

Every question met while designing the machine. Each is asked of the owner
one at a time; an answer is written in beside its question and the documents
it changes are updated in the same pass. A question here is not decoration:
the work it touches is not finished until it is answered.

| # | Question | The design assumes, until answered | Touches |
|---|---|---|---|
| 1 | *"the harness and etceteras"* — is the delivered design working code (the harness that runs it, plus what surrounds it), or something else? | Working code, with its tests and a house-layout project around it | [007](007-datapath-the-design.md) |
| 2 | When the person names no target, what should the design be written in: the source's own language, or Lua (the house language)? | The source's own language, since the person handed over that kind of software | [007](007-datapath-the-design.md) |
| 3 | Acceptance commands are written by a model and run on this machine. Should they run inside a wall (the bubblewrap containment `init-project.sh` already builds), or is the design folder as working directory enough? | Working directory only, with the person told on a case's first build | [007](007-datapath-the-design.md) |
| 4 | Which update grade should stop and wait for the person before rebuilding: foundation only, middle and up, or none? | Foundation | [008](008-datapath-the-update.md) |
| 5 | Is "half the blueprint" the right line between a middle and a foundation update? | Yes, until real updates say otherwise | [008](008-datapath-the-update.md) |
| 6 | The center's keep factor (0.97 per ledger line) and weight table — are these the right shape for a personality, or should the center weigh something else (who asked, how the design turned out)? | As written | [009](009-datapath-the-center.md) |
| 7 | A live run with the Claude Code harness spends the owner's subscription. May the capstone demo run one, on a small source, or should every demo use the stand-in? | Demos use the stand-in; a live run happens only when the owner starts one | [011](011-roadmap.md) |
| 8 | Should a case's ledger and blueprint ever be committed somewhere (they are the story of how the design was made), given that `cases/` is kept out of this repository because the source is often someone else's? | Not committed; the design folder is a house project and can become its own repository | [003](003-datapath-the-case-and-the-ledger.md) |
