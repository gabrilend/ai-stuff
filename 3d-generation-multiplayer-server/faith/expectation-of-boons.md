# expectation of boons

What is being counted on. Not predictions — things assumed true, which the
project would need reshaping around if they turned out false. Written down so
that when one of them breaks, it is recognised as an assumption breaking rather
than as a mysterious week.

---

**That the upstream server keeps being maintained, and keeps its module seam.**
The whole patch machine assumes there is an upstream to track. If it stops
moving, the pruning machine has nothing to do and we have quietly acquired a
fork. If the hook system it exposes goes away, work that was going to be
modules becomes patches, and phase 5 gets substantially heavier.

**That the protocol is genuinely as documented by its many implementations.**
Several independent servers speak this format. That much agreement is strong
evidence the format is understood. Counting on it, and on being able to generate
known-good test vectors by running the server we already have rather than
deriving them from first principles.

**That flat untextured geometry is enough to make a place feel like a place.**
The entire art plan rests on this. If a world of squares and triangles reads as
a placeholder rather than as a style, the answer is not more polygons — it is
light, colour, and motion, none of which are in the plan yet.

**That the contrast holds.** Rigid terrain, soft inhabitant. Counting on a pink
squiggle among straight edges being immediately legible to someone who has never
seen the game, in all four schemes, without being told what to look for. This is
the one assumption that is cheap to test early and worth testing early.

**That a system nobody uses stays quiet.** The design selects rather than
deletes: everything upstream can do stays present, and the game is what gets
granted and exposed. Counting on unused systems being genuinely inert — not
running timers, not filling logs, not sending the client messages about things
that do not exist. If they turn out to be noisy rather than silent, selection
starts costing what deletion would have cost, one system at a time.

**That the headless client is enough to trust.** Phases 2 and 3 produce a
program with no window, and phase 4 is built on the belief that the world model
is already right. If rendering turns up protocol bugs the headless client never
noticed, that belief was worth less than it looked.

**That the extraction tools still run, on data we can actually obtain.** The
whole map plan rests on the existing pipeline working as documented, against
archives that have to exist somewhere. This replaced what had been the least
verified assumption in the project — generating collision from a format of our
own invention — with a much smaller one, and the residue is a supply question
rather than an engineering one.

**That collision geometry is worth looking at.** Drawing the server's collision
soup means the world on screen is exactly the world you can touch. Counting on
that geometry being *pleasant* — it was authored to be invisible, and it may
carry simplifications that look wrong once anybody can see them.

**That the identity trick keeps giving.** Appearance from the character
identifier costs nothing and survives everything. Counting on being able to
reuse the same move — sound, name, small behaviours — rather than it being a
one-off.

**That the person will still want this in a month.** Six phases is a long walk.
The ordering exists so that stopping after phase 3 leaves a real thing behind: a
server that can be changed safely, and a client that proves the changes did not
break it. Counting on that being true, and on it being worth having even if the
squiggles never get drawn.
