# 153-the-source-end.lua

The `.src` end's checks (docs/067, issue 808 step 1): the language table,
the first-line check, the language's own parser, and the `.src`
paintbrush read through the wall (151). Writing the file is a turn of a
model through the hands (808 step 2, not built yet).

A **language row**: `extension`, `comment` (a line comment's opening),
`parser` (its syntax check, `%s` the path), `program` (what the parser
needs on the PATH). Rows: `lua` (`luajit -bl`), `c` (`cc -fsyntax-only`),
`bash` (`bash -n`). Adding a language is
adding a row. A file's first line is `<comment> <language> <version>`,
e.g. `-- lua 5.1 (LuaJIT 2.1)`.

| Function | In | Out |
|---|---|---|
| `check_first_line(language, text, version)` | a language; a file's text; the canvas's version (optional) | true, or nil and what the line should read |
| `check_parse(language, path)` | a language; a file | true, or nil and the parser's own words; a parser not installed is refused by name |
| `check_file(language, path, version)` | as above | true, or nil and every finding: the ending, the first line, the parse |
| `first_line(language, version)` | | the line a file must open with |
| `read(text, where)` | a `.src` canvas's text | `{language, version, purpose, prompt, seed, first_line, extension}`, or nil and every finding (through the wall, plus a category other than `source`) |
| `names()` | | the languages, sorted |
| `LANGUAGES`, `SRC` | | the language table; the `.src` paintbrush (its document: `docs/paintbrush-src.md`) |
