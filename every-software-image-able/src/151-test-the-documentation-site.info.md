# 151-test-the-documentation-site — info

Checks the renderer and the site builder: that written text comes out as the markup it should, that references reach the right page, and that every page the build produces is closed properly.

This project's documentation is now built by a program rather than written by hand, which means a mistake in the program is a mistake in two hundred pages at once. This runs the program over its own project and checks the result, so that happens once rather than being noticed later by a reader.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `151-test-the-documentation-site.lua` and run the sweep again.*

## Invocation

```
luajit 151-test-the-documentation-site.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `link` | `true, meta = true, area = true }` |  |

## Three of these are there because they happened

The renderer took the comments out of fenced blocks and replaced them with a number, because the marker it used to hold them aside was made of digits and the pass that colours numbers found it. A list whose every item was indented -- which is how a list inside a comment block arrives -- opened an inner list with no outer item to sit in, and left the page unbalanced. And the project root was stripped from paths with a pattern, though it contains hyphens, which mean something in a pattern, so every page displayed its full absolute path instead. All three produced output that looked deliberate, which is this project's usual failure and the reason the last check here reads every page rather than trusting any of them.

