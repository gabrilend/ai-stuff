# 102 — Tag parsing

A tag is a word in a note's text that starts with `#`.

## Current Behavior

Nothing is built yet.

## Intended Behavior

A module `src/tags.lua` returning a table with two functions.

| Function | In | Out |
|---|---|---|
| parse(text) | a note's text | array of tags in the order first met, lower-cased, each once. A tag is `#` followed by letters, digits, `_` or `-`; the `#` is not part of the tag |
| filter(notes, tag) | array of notes; a tag, with or without a leading `#`, any case | the notes holding that tag, in their order |

## Suggested Implementation Steps

1. parse. Test: "buy #Milk and #milk #home" gives milk, home.
2. filter. Test: "#HOME" and "home" both select the notes tagged home.

## Acceptance

```sh
luajit tests/102-tag-parsing.lua
```

## Blocked by

None

## Covers

- src/tags.lua
