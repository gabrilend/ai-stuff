# text-formatter.info.md

The one place that decides where a poem's lines break and how wide they are
(Issues 8-056, 10-021). Pure: strings in, strings out — no files, no globals, no
project state. Both the main thread (chronological pages) and the effil worker
threads (similar/different pages) call it, so a poem breaks the same way no
matter which path drew it.

## The rule this module exists to enforce

**Width is what the reader sees, not what the string weighs.** By the time a
poem line arrives here it has already been HTML-escaped and markdown-formatted,
so it carries three kinds of byte that cost no columns of ink:

| In the string | Bytes | Columns |
|---|---|---|
| `<em>` … `</em>` around an emphasized word | 9 | 0 |
| `&amp;` standing in for one ampersand | 5 | 1 |
| an em dash, a curly quote, a box-drawing char | 2–4 | 1 |

Every measurement below counts columns. Counting bytes instead is what made a
78-column line of the note "too-harsh" shed its last two words: the `<em></em>`
around one emphasized word ate nine characters of an 80-column budget, while the
plain line two rows down sat at 80 and stayed whole.

## Public functions

- `format_poem_lines(text) -> {line, …}`
  - Splits on newlines and changes nothing else. Leading spaces, multi-space
    runs and empty lines (paragraph breaks) all survive. An empty or nil text
    gives an empty table.

- `format_poem_content(text, max_width) -> {line, …}`
  - `format_poem_lines` plus a one-space left pad on every line plus wrapping.
    `max_width` defaults to 80. The convenience entry point for a whole poem.

- `wrap_preserving_indent(line, max_width) -> {line, …}`
  - Wraps ONE line at word boundaries. Lines already inside `max_width` columns
    come back untouched as a one-element table. Continuation lines inherit the
    original line's leading whitespace. A word too long to ever fit (a URL) is
    broken across lines rather than allowed to overflow.
  - **Caller contract:** the tags in `line` must not contain spaces. Emphasis
    tags never do, so `<em>two words</em>` splits and measures correctly. An
    `<a href="…">` anchor DOES contain a space and would be torn apart — route
    link text through `wrap_external_url` instead.

- `wrap_external_url(prefix, url, content_width) -> string`
  - Renders `prefix .. url` as newline-joined lines that fit `content_width`,
    breaking the address itself rather than truncating it, and re-opening an
    `<a href>` on every line so each piece stays clickable inside its box.

- `slice_by_visible_width(str, width) -> chunk, rest`
  - Cuts a string after `width` visible columns. Walks one display unit at a
    time so the cut lands between characters, never inside one: a tag is
    swallowed whole for zero columns, an entity whole for one, a UTF-8 sequence
    whole for one. This is what keeps a long word from being cut into `<e` +
    `m>`.

- `calculate_visible_width(content) -> integer`
  - How many columns `content` occupies once tags are stripped and entities
    decoded. The measurement the whole module is built on.

- `decode_html_entities_for_width(content) -> string`
  - Strips `<…>` tags and turns `&gt; &lt; &amp; &quot; &#39; &nbsp;` and
    numeric entities back into single characters. **For measuring only** — the
    rendered page must keep the entities, or the browser will read poem text as
    markup.

- `utf8_char_count(str) -> integer`
  - Counts characters by discarding UTF-8 continuation bytes (0x80–0xBF).

- `format_cw_box(text, box_width) -> string`
  - The content-warning box (issue 9-011): a top rule, the wrapped warning,
    a bottom rule, joined by newlines, every line exactly `box_width` visible
    columns (`box_width` is a number, corners included; the text area is
    `box_width - 4`). Whitespace runs in `text` become single spaces. Lines
    break at a space or just after a dash — the dash stays at the end of the
    line — and a word too long for the box (a URL, a magnet link) is cut at
    the edge. No indentation; the caller places the box.

## Tests

`libs/text-formatter-test.lua` — `luajit libs/text-formatter-test.lua`. Pure,
standalone, touches no project state. Carries the "too-harsh" line as a
regression: an emphasized 78-column line must not wrap at 80, and the plain line
below it must not either.

## Used by

`src/flat-html-generator.lua` (poem bodies, boost bodies, and the same work
again inside the effil workers) and `src/generate-word-pages.lua`.
