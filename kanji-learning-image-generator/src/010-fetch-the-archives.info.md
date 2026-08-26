# 010-fetch-the-archives — info

Gets the two published datasets this project reads, and writes down which releases were taken.

For a general: everything this project knows about kanji comes from two files other people maintain -- one holding the strokes of every character and the order a hand writes them in, one holding what each character means. They are about thirty megabytes together and are not committed here, because they are somebody else's work and they are versioned where they live. This fetches them, and records exactly which edition it got, so that a set of images generated a year ago can still be traced to the dictionary that described it.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `010-fetch-the-archives.lua` and
run the sweep again.*

## Invocation

```
luajit src/010-fetch-the-archives.lua [--dir ROOT] [--force]
```

## What it offers

| | |
|---|---|
| `M.fetch_one(name, archive, options)` | Download, decompress, and check the shape of one archive. |
| `M.require_archive(name)` | The path to an archive, or an error saying how to get it. |
| `M.provenance()` | What the provenance file currently says, as text, or nil. |
| `M.fetch_all(options)` | Both archives, and the provenance file written afterwards. |

### `M.fetch_one(name, archive, options)`

Download, decompress, and check the shape of one archive.

Returns a table describing what happened, which the provenance file is written from.

### `M.require_archive(name)`

The path to an archive, or an error saying how to get it.

Every reader calls this instead of building the path itself. A missing archive is not a condition to work around -- there is no smaller set of kanji to fall back to, and a program that carried on with an empty one would report success having done nothing.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `shell_quote(text)` | One argument, safe to hand to a shell. |
| `tool_present(name)` | Whether a command exists on this machine. |
| `file_size(path)` | Bytes, or nil if there is no such file. |
| `ends_of(path, bytes)` | The first and last stretch of a file, for the shape check. |
| `main(argv)` | Run directly, this fetches. Loaded as a library, it does not. |
