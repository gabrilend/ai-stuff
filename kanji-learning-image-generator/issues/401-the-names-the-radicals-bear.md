# 401 — The names the radicals bear

## Current behavior

A character's pieces are looked up in the lexicon and turned into things that
can be in a picture. Then the ones the archive marks as chosen for their *sound*
rather than their meaning are demoted out of being subjects and become
landscape — ridgelines, paths, rock faces — present in the composition and
absent from the sentence. `docs/004` argues for that at length.

The argument is sound and it answers a different question than the one this
project turns out to be for (`notes/041`).

## Intended behavior

**Every piece appears in the picture under its name, including the ones that are
only there for the sound.**

That is how the mnemonic tradition works, and the reason it works is exactly the
reason `docs/004` excluded them:

> 時 is a **sun** over a **temple**. A temple has nothing to do with time, which
> is precisely why the image sticks.

A picture that shows the semantic half and hides the phonetic half is a picture
of half the character. A learner looking at 時 sees a sun and a temple on the
page, and an image that shows only the sun has quietly dropped the part they
have to account for.

**Both readings stay available, because both are right for something.** A flag
decides:

| Mode | Phonetic pieces | Good for |
|---|---|---|
| `mnemonic` (new default) | named subjects, like any other piece | learning the character as a shape made of parts |
| `semantic` | landscape, as now | a picture that is *about* what the word means |

The mode is a setting and it belongs to a whole run, not to a character.
`docs/004` gets the second half of its argument written in rather than replaced,
because the reasoning that produced it is still correct.

**The names get better.** The lexicon's phrases were written to be dropped into
a sentence — *a standing figure*, *a hand reaching down to grasp*. A name is
shorter and blunter than a description: **leader**, **claw**, **sun**,
**temple**. Both are wanted. A piece gains a short name beside its longer
phrase, and the name is what the learner is told the piece is called.

**Where a name is ours rather than the archive's, it says so**, because a name
somebody invented and a gloss a dictionary published are different kinds of
claim and a learner who later meets a different set of names should be able to
tell which was which.

## Suggested implementation steps

1. **Extend the lexicon rows with a name.** The rows already carry a phrase and
   a world; a third field is the short name. Derived where the dictionary gloss
   is already a plain noun, written where it is not.

2. **The scene grammar takes the mode**, and the demotion in `024` becomes a
   branch on it rather than an unconditional rule. The scoring is untouched — a
   phonetic piece must still not vote on which world the character belongs to,
   in either mode, because that was never about the picture.

3. **The prompt names the pieces by name and places them by their boxes.** The
   subject cap in `205` may need raising: a character with a semantic half and a
   phonetic half now has two subjects where it had one.

4. **The card records which mode made it**, because a set generated one way and
   a set generated the other are not comparable and nothing else would say so.

5. **Test on the characters the tradition has strong opinions about.** 時 must
   produce a sun and a temple. 語 must produce speech and the phonetic half,
   not speech alone. And in `semantic` mode both must still behave as they do
   now, or the old reading has been lost rather than kept.

## Related

`notes/041` — why. `docs/004` — the argument this qualifies. `203`, `204`, `205`.
