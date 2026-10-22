# render-image-post-comparison

One page showing image-only posts (posts that are only a picture) drawn both
ways the site draws them: as a gallery picture box (similar and different
pages) and as an ordinary post (chronological and word pages), side by side,
with what a screen reader says for each picture written under it. For
choosing one way for every page (Issue 9-013).

## Usage

`scripts/render-image-post-comparison [DIR] --out FOLDER --model NAME`

| option | meaning |
| --- | --- |
| `--out` | where the page goes; must not exist yet (put it in `tmp/shared-memory/`). Open `FOLDER/pages/compare.html` |
| `--model` | the embedding model whose picture list (`image-manifest.json`) marks the image-only posts |

## The sample

Fixed by rule: the first image-only post (in poems.json order) that has some
text, a content warning, several pictures, a picture with no description,
and one that is picture only. Their pictures are copied next to the page, so
it works before a build has filled the site's picture folder.
