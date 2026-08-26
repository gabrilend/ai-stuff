# 401 — The names the radicals bear

## Current behavior

Done. `settings.scene.reading` is `mnemonic` or `semantic`, defaulting to the
first, and 時 now produces a sun and a temple.

```
luajit src/024-the-scene-grammar.lua --chars 時語
```

**The names are derived, not written twice.** The lexicon's phrases were already
noun phrases, so a name is the head of one with the elaboration cut off — *a
temple with a bronze bell* is *temple*. A hundred and seventy names written by
hand would have been a hundred and seventy chances for the name and the
description to drift apart. Only the ones the derivation gets wrong are written,
and that list is short.

**Two things had to be fixed that the plan did not anticipate.**

*The sound half was being weighted ahead of the meaning.* Subjects were ordered
largest-first, and for 時 the temple is bigger than the sun — so the temple
landed at the head of the list, which is the position the sentence weights and
the last one it gives up. It belongs in the picture; it does not belong in front
of what the character is about.

*A pronoun is a correct gloss and not a picture.* The piece inside the sound
half of 語 is glossed "I", and with the sound half promoted to subjecthood that
put the word "I" into a scene description as though it named something. The rule
that refuses glosses about the writing system now also refuses bare grammatical
words, anchored — "it" is inside "item". Six such pieces got written entries
drawn from what they are actually built out of. Then the ones the archive marks as chosen for their *sound*
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
