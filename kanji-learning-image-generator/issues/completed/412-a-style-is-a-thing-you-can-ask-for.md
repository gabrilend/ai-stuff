# 412 — A style is a thing you can ask for

## Current behavior

Done. `--style wimmelbild`, and the four refusals no style may lift are refused
by name if one tries.

**Two bugs stood between asking for a style and getting one, and both made it
look as though the feature did nothing.**

*The prompt was built twice and the wrong one was posted.* `044` worked out the
styled prompt, then called `030` to write the recipe — and `030` worked out its
own prompt without the style. What got posted was `030`'s. So the style went
into the pool as the picture's description while the picture was made from a
different prompt entirely. The pool recorded a brief the picture had never
answered. `030` is now the only place a recipe is built.

*And the seed ignored the style.* Two styles of one character began from
identical noise, met an identical field at full control strength, and differed
by one clause — so they came out as very nearly the same picture. The rule this
project wants is that the same *description* gives the same bytes, and the style
is part of the description. Folding the style in needed the modulo applied on
every step: multiplying a codepoint by thirty-one ten times carries it past the
fifty-three bits a double keeps exactly, and the seed came out as zero.

**The style is part of a rendering's name in the pool**, or the same character
in two styles would land on one name and the second would quietly replace the
first — in a pool whose first paragraph says nothing is ever deleted.

## Was

Every picture is photographic, and the negative prompt makes sure of it:
*illustration, cartoon, flat colour, poster, diagram*.

That constant is argued for in `205` and the argument is specific:

> An illustration has large flat regions of one colour, and a flat region
> cannot hide a shape — there is no light and shade in it for the strokes to
> live in.

It is a good argument for the thing it was aimed at. It is not an argument
against every non-photographic style, and it was written as though it were.

## Intended behavior

**A run can ask for a style, and a style may lift the refusals its own
reasoning does not apply to.**

The case that raised it:

> Can we... Can we try supplying a style hint of "Wimmelbilder" to it? I want to
> see what happens.

A Wimmelbild — a teeming picture, the seek-and-find kind — is an illustration,
and is the **opposite** of flat. It is hundreds of small distinct things, each
with its own edges and shadow. There is more for a hidden shape to live in than
a photograph offers, not less. Refusing it under a rule written against flat
colour is refusing it for a reason that is not true of it.

**So a style is:**

| | |
|---|---|
| terms it adds | what the picture should look like |
| terms it replaces | the photographic tail, where a style has its own |
| refusals it lifts | named one by one, never wholesale |
| a reason, written down | why each lifted refusal does not apply |

**Lifting is per term and never blanket.** A style may say that *illustration*
does not apply to it. No style may lift *kanji*, *calligraphy*, *text* or
*lettering* — those defend the thing the whole project is for, and a style that
wanted them lifted would be asking for a picture of a character rather than a
picture that is one.

**Photographic stays the default**, and remains a style like the others so that
nothing is special-cased.

**A rendering records which style made it.** A pool holding two styles and no
way to tell them apart is a pool where every comparison is meaningless.

## Suggested implementation steps

1. **A table of styles in `025`**, beside the refusals, because that is the one
   file allowed to write English.

2. **The refusals become a list rather than one string**, so a style can lift
   an entry by name and the rest survive untouched. The four that no style may
   lift are marked as such in the table and the lifting refuses them by name.

3. **`--style` on the command line and a default in settings.**

4. **Test that the four cannot be lifted**, which is the assertion protecting
   the project rather than the one making the feature work.

## Related

`205` — the refusals, and the argument this qualifies. `docs/004` — where the
defence is described.
