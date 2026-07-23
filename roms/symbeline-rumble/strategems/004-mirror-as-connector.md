# 004 — Mirror as connector

**Shape.** Two things written in the same form, placed in adjacency
(one directly below the other, or one directly beside the other), are
connected by the form. The adjacency is not decorative; it is the
edge of a graph whose vertices are the two things. The form is the
edge label.

**Origin.** The user's own example in the global CLAUDE.md:

```
wrongful applie
         applie is norm
```

…where "applie" is the same word in both lines, vertically aligned, and
the alignment is what makes the two phrases comment on each other.

**Where else it fits.**

- **Indexed filenames.** The global rule "code should be written like a
  story; source files have indices" is the same idea. Two files with
  adjacent indices are *near* each other in the project's reading
  order; that nearness is meaningful.
- **The divergence grid.** Two cells in the same row are connected by
  *the problem they both solve*. Two cells in the same column are
  connected by *the target they both serve*. The grid is mirror-as-
  connector applied twice.
- **Diff review.** Old line and new line aligned by position make the
  delta legible. Misalignment is itself a signal (deletion, insertion).
- **Function pairs.** `patch` and `unpatch` named with the same `<id>_<name>`
  suffix are connected by the suffix. The naming is the edge.
- **Songs.** A repeating melodic phrase three bars later, transposed
  but recognizable, is the same word "applie" in a lower octave. The
  ear connects them because the form is preserved.

**Why it works.** Lexical connection is fragile (rename one symbol and
the connection is lost). Adjacency-based connection is robust to
renaming if the adjacency is preserved. It is also dense — a lot of
meaning per character — because the form does the work that words
would otherwise have to do.

**Where it breaks.** When adjacency is illusory (two things look
aligned but are not actually paired) or when the medium destroys
adjacency (text wrapped to a narrower terminal, code reformatted by an
autoformatter that doesn't know about the alignment). Those are
fragility points. The pattern wants stable rendering to do its work.

**Credit.** This strategem is the user's. I am writing it down because
she taught it, and because writing it down is one way to honor a
teaching.
