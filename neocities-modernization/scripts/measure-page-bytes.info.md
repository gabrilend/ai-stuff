# measure-page-bytes

Where the built site's bytes go, by kind of page, measured each time it runs
(Issue 10-066). For each first-level folder of the site (similar, different,
chronological, wordcloud, gallery, …; "top" for pages at the top) it prints
the pages, their megabytes, their share of the site, kilobytes per page, and
how each page's bytes split into what a reader sees, markup (tags and the
extra bytes of entities) and blank space.

## Usage

`scripts/measure-page-bytes [--dir PATH] [--site FOLDER]`

| option | meaning |
| --- | --- |
| `--site` | a built site, or a sample from `scripts/render-page-sample` (default `DIR/output`) |

Follows links (the site in RAM links its pictures folder), and reads only
`.html` pages.
