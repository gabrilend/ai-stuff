# 013-org-page

Writes an org as one static HTML5 page: no JavaScript, no server, nothing the
files do not hold.

## What it is for

The vision says people can design their own interfaces and the model is what
matters; this is the plainest one that lets somebody without a terminal see
what is blocking. The board first; then every box with its holders and ports,
every wire a link to the other end and every waiting port marked, so following
the links from the top row walks the chain of waiting by hand; then the people
with what each holds; then the outside parties.

It refuses an invalid org, because a page of an invalid map would show
something untrue. `./org-page` is the front door.

## Exports

| Function | Returns |
| --- | --- |
| `page(org)` | the page's text |
| `escape(s)` | text safe inside HTML |
| `main(args)` | writes the page of `ORG_DIR` to standard output |

Styling is a few lines of inline CSS that follow the reader's light or dark
setting.
