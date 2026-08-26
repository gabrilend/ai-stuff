# 411 — A radical makes its own strokes

## Current behavior

Done. A stroke's shape still comes from `021`; what it is made *of* now comes
from the radical that owns it. 休 describes its first two strokes as **leader**
and its last four as **tree**; 時 describes four as **sun** and six as
**temple**.

**Owned by the pieces the prompt names, not by the finest piece available.** The
temple is itself built from earth and a measuring hand, and attributing strokes
to that level described the temple's strokes as "dirt" and "measurement" while
the sentence beside them said "temple". The picture has to be made of the things
the sentence names or the two describe different pictures. The finer
decomposition is still in the card, where it is study material rather than
instructions to a model.

## Was

Every stroke gets an object from the **world's** vocabulary, chosen by the
stroke's own shape. In the forest, a long vertical is a cedar trunk and a dot is
a bird — whichever radical the stroke happens to belong to.

So in 時, which is a sun beside a temple, the sun's four strokes and the
temple's six all draw from the same list. The archive knows perfectly well which
radical owns each stroke; nothing asks it.

The radicals are named — they arrive as subjects, placed by the box their own
strokes occupy — but their *strokes* are made of whatever the world supplies.

## Intended behavior

**A stroke is made of the thing its own radical represents.**

> I want specifically to make the strokes, the structure, be comprised of the
> thing that each radical is representing. That way we can learn to tell
> radicals apart.

In 時 the four strokes of 日 are made of **sun**, and the six strokes of 寺 are
made of **temple**. A learner who sees that twice knows what 日 looks like as a
shape before anybody tells them its name.

**The shape still decides the form; the radical decides the substance.** A
vertical stroke is still an upright and a horizontal is still a level bar — that
part comes from `021`'s measurement and does not change. What changes is what
the upright is *made of*: a temple post rather than a cedar trunk, because the
stroke belongs to the temple.

**Where a radical has nothing to be made of, the world supplies it as now.**
Some pieces have no picture (`203` counts them); some strokes belong to no
named piece at all. Those fall back to the world's vocabulary, which is exactly
what they get today, so nothing gets worse.

**The card says which radical every stroke belongs to.** That is the whole
pedagogical point and it costs a field. A learner looking at the page should be
able to read: *strokes one to four are the sun; five to ten are the temple.*

**The world does not stop mattering.** It still sets the register, the light and
the palette, and it still supplies the strokes that have no radical of their
own. What it loses is the monopoly on what a stroke is made of.

## Suggested implementation steps

1. **`024` asks which piece owns each stroke.** The information is already in
   the record — every stroke carries the group it came from, and `012` has the
   lookup. It is not consulted anywhere yet.

2. **A small set of templates, by stroke shape**, that turn a radical's name
   into a thing of that shape: an upright, a level bar, a fall to the left, a
   dot. Six or seven phrasings, shared by every radical, rather than a
   vocabulary per radical — which would be a thousand rows nobody could
   maintain.

3. **The prompt names the radical, repeatedly, near a placement.** That is what
   actually moves a diffusion model: the same noun appearing beside several
   positions, rather than one mention of it and then a list of generic shapes.

4. **Test that two radicals in one character get different substances**, which
   is the entire claim. 時 must not describe its sun and its temple with the
   same words.

## Related

`204` — the world's vocabulary, which this narrows rather than replaces.
`401` — the names this uses. `012` — which already knows the answer.
