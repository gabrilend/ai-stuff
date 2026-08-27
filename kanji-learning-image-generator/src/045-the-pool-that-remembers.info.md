# 045-the-pool-that-remembers — info

Every picture this project has ever made, kept, with everything true about it in a file beside it.

For a general: there is no database here and no index. A picture and its description are two files with the same name in the same folder, and that is the whole store. The convention already exists for source -- every source file has a companion page you read instead of opening the code -- and this is the same idea pointed at what the project produces.

```
    pool/shrine/06642-時-20f3a9.png
    pool/shrine/06642-時-20f3a9.info.md

```

Three things follow from it and each is the reason for it.

```
  Asking "which of the forest ones are good" reads small text files. It never
  opens a picture.

  Nothing can be separated from its meaning. Copy the pair anywhere and the
  tier, the seed and the origin come with it. A record in a central store
  drifts from what it describes the first time somebody archives one without
  the other.

  Ratings are appended and never overwritten, so a machine's guess stays
  visible underneath the correction a person later made -- which is the only
  reason the agreement between them can be measured at all.

```

NOTHING IS EVER DELETED. Not the bad ones. A low tier records what missed and by how much; re-rating later can promote something scored in a hurry; and a pool that has been pruned cannot answer why the output drifted. Storage is cheap and judgement is expensive, and this trades the cheap thing away deliberately.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `045-the-pool-that-remembers.lua` and
run the sweep again.*

## Invocation

```
luajit src/045-the-pool-that-remembers.lua --counts
luajit src/045-the-pool-that-remembers.lua --list --category forest --floor 4
```

## What it offers

| | |
|---|---|
| `M.root(settings)` |  |
| `M.stem(record, seed, style, resolution)` | What one rendering is called, without an extension. |
| `M.place(settings, record, scene, seed, style, resolution)` | The two paths one rendering occupies. |
| `M.render_companion(entry)` | Everything true about one rendering, as the text of its companion. |
| `M.read_companion(path)` | One companion, back as a table. |
| `M.tier_of(entry)` | The tier that counts, and who set it. |
| `M.tier_by_a_person(entry)` | The last tier a person set, if a person ever set one. |
| `M.add(settings, entry, picture_bytes)` | One rendering, into the pool. |
| `M.rate(companion_path, tier, who)` | One more rating, appended. |
| `M.elaborate(companion_path, file, what)` | A note that a rendering earned some extra work, and got it. |
| `M.walk(settings, filter)` | Every rendering that matches, as entries. |
| `M.counts(settings)` | How many of what, and how often the machine agrees with a person. |

### `M.stem(record, seed, style, resolution)`

What one rendering is called, without an extension.

The number first so a folder sorts in a stable order, the character next so a person can read the listing, and the seed last because the same character can be rendered more than once and those are different pictures.

### `M.place(settings, record, scene, seed, style, resolution)`

The two paths one rendering occupies.

Arranged by category, because quality is never discussed globally -- it is always *these* that are looking bad, and the unit somebody says that about here is the world.

### `M.render_companion(entry)`

Everything true about one rendering, as the text of its companion.

Markdown, because it has to be readable by a person and greppable by a program, and this project already reads and writes that shape everywhere.

### `M.read_companion(path)`

One companion, back as a table.

By pattern over a file this project wrote itself, in a shape chosen to be read this way. There is no parser here because there is no format here -- there is a table with two columns and a list of lines beginning with a dash.

### `M.tier_of(entry)`

The tier that counts, and who set it.

The last rating wins, which is how a person's correction overrides a machine's guess without either being erased.

### `M.tier_by_a_person(entry)`

The last tier a person set, if a person ever set one.

Separate from the tier that counts, because "tier 4 or better" and "tier 4 or better as judged by a person" are different requests and the second is smaller and more trustworthy. Confidence and quality are not the same axis.

### `M.add(settings, entry, picture_bytes)`

One rendering, into the pool.

The picture is written first and the companion second, so that a run interrupted between them leaves a picture with no description rather than a description of a picture that is not there. The first is visible and recoverable; the second is a lie.

### `M.rate(companion_path, tier, who)`

One more rating, appended.

The whole companion is rewritten because that is how a text file gains a line, and no rating that was already in it is touched. The history is the point: a machine's guess has to stay visible under a person's correction, or the agreement between them cannot be measured.

### `M.walk(settings, filter)`

Every rendering that matches, as entries.

The whole query layer. It reads companions and never opens a picture, which keeps filtering cheap and, more importantly, keeps it simple: the thing that answers "what is available" is text processing rather than a media pipeline.

filter.category    only this world filter.kind        "character" or "phrase" filter.floor       this tier or better filter.by_a_person the floor must have been set by a person filter.character   only this character

### `M.counts(settings)`

How many of what, and how often the machine agrees with a person.

A utility rather than a number written into a document. A number typed into documentation was true once; this is true when asked.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `032-a-gallery-you-can-page`, `035-test-the-machine`, `044-run-the-pictures`, `046-two-ways-of-saying-it-is-good`, `047-the-quality-dial`, `048-what-a-higher-tier-buys`.
