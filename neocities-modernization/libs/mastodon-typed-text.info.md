# mastodon-typed-text.lua

Reconstructs what an author typed into the Mastodon compose box from the
rendered HTML stored in an ActivityPub archive, and counts that text the way
the compose box counted it while the author watched. The archive stores what
the server *rendered*, not what was *typed*: markdown emphasis delimiters are
consumed into tags (`*love*` becomes `<em>love</em>`), URLs are wrapped in
anchor markup with invisible spans, and entities are escaped. Recovering the
typed text is what makes golden poem qualification (exactly 1024 characters as
composed) possible. Created for issue 4-003 (August 2026 re-open).

## External functions

### `restore(html)` → string
- **Input**: `html` (string) — one post's content HTML as stored in the
  archive's outbox.
- **Output**: string — the reconstructed typed text: emphasis delimiters put
  back (`*`, `**`, `~~`, backticks), paragraph breaks as blank lines, line
  breaks as newlines, entities decoded (`&amp;` decoded last so a typed
  `&lt;` survives), all remaining markup stripped, leading/trailing newlines
  trimmed. Typed backslashes are preserved (the older inline cleaner deleted
  them before quotes).
- Used for both the displayed poem content and the golden poem content.

### `compose_box_count(html, content_warning)` → number
- **Input**: `html` (string) — post content HTML, pre-anonymization so real
  mention text is priced; `content_warning` (string or nil) — CW text without
  any "CW: " prefix.
- **Output**: number — the count the author watched while composing:
  reconstructed typed text plus CW text, measured in composer characters,
  with every non-mention link priced at a flat 23 regardless of URL length,
  and mentions priced at `@user` alone — both anchor-form mentions (visible
  text is already `@user`) and plain-text `@user@domain` mentions the server
  never linkified (the domain part rides free).
- A poem is golden when this returns exactly 1024.

### `composer_length(s)` → number
- **Input**: `s` (string) — UTF-8 text.
- **Output**: number — length in composer characters, the unit the compose
  box counter used: one per visible character regardless of byte width
  (a curly apostrophe is 3 bytes but counts 1), one per emoji even from the
  astral plane (4 bytes, counts 1), zero for the invisible glue codepoints
  emoji carry (variation selectors, zero-width joiner). Empirically anchored:
  archived poems with emoji sit at exactly 1024 under this model and at 1025
  under UTF-16-unit counting, and the compose box refused anything past 1024.

## Data notes

- Mention anchors carry `class="u-url mention"`; hashtag anchors carry
  `class="mention hashtag"`. Both keep their visible text; only true URL
  anchors become the 23-character placeholder.
- The legacy `^_^` emoticon repairs from the original cleaner are retained
  verbatim (observed archive-specific damage; length-neutral).
- Underscore-style emphasis (`_x_`) is indistinguishable from asterisk-style
  in rendered HTML; both restore as asterisks — identical length, so counting
  is unaffected either way.

## Tests

`libs/mastodon-typed-text-test.lua` — standalone, plus an optional
integration pass that recounts three audit-verified poems straight from
`input/fediverse/files/poems.json` when that file is present.
