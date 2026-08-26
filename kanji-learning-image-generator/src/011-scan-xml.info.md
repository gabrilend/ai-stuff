# 011-scan-xml — info

Walks an XML document from front to back, handing out tags as it meets them.

For a general: the two files this project reads are about thirty megabytes of XML between them. The usual way to read XML is to build the whole document into a tree of objects in memory and then ask it questions -- which for a question as small as "what are this character's strokes" means constructing several million objects to look at a few dozen of them.

This does the other thing. It reads forward once, calls a function every time it passes a tag, and keeps nothing. The programs that use it build the small structure they actually want as the tags go by.

It is not a general XML parser and does not want to be. It knows the parts of the format these two archives use and errors on anything else, which is the honest position: a parser that quietly accepts what it does not understand is a parser that quietly loses data.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `011-scan-xml.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.utf8(codepoint)` | One character number, as the bytes that spell it. |
| `M.characters(text)` | One UTF-8 string, as an array of its characters. |
| `M.decode(text)` | Character references turned back into characters. |
| `M.attributes(text)` | One tag's attribute text, as a table. |
| `M.scan(text, handlers)` | Walk the document, calling handlers as tags go past. |

### `M.utf8(codepoint)`

One character number, as the bytes that spell it.

Here rather than somewhere more obviously its home because numeric character references need it and they are this file's business -- and because the archive that draws the strokes identifies each character by its number rather than by the character itself, so the reader needs the same conversion. Two copies of this arithmetic would be two chances to get the continuation bytes wrong.

### `M.characters(text)`

One UTF-8 string, as an array of its characters.

The inverse of M.utf8, and here for the same reason: a person naming which characters they want types them as one word, and every part of this project that accepts such a list has to break it apart. A byte with its top two bits set to one-zero is a continuation of the character before it; every other byte starts a new one, which is the whole of what UTF-8 needs to be walked forwards.

### `M.decode(text)`

Character references turned back into characters.

Kept separate from the scan and called by the reader rather than by the scanner, because most text in these archives contains no references at all and checking every string for one costs more than the few that need it.

### `M.attributes(text)`

One tag's attribute text, as a table.

Called by the reader, not by the scanner. Most tags in these archives have attributes nobody wants -- KANJIDIC2 alone has hundreds of thousands of them -- and building a table for every one would be most of the running time spent on data that is then discarded.

Names with a colon in them are kept whole. `kvg:element` is an attribute whose name contains a colon, and that is all this project needs it to be; resolving namespace prefixes would be work in service of nothing.

### `M.scan(text, handlers)`

Walk the document, calling handlers as tags go past.

handlers.open(name, attribute_text, self_closing) handlers.close(name) handlers.text(raw)

All three are optional. A scan with only an open handler is the normal case and is the fastest thing this file does.

The attribute text is handed over raw, for M.attributes to make sense of if the handler wants it. A self-closing tag calls open with the third argument true and does not call close -- a handler that keeps a stack has to account for that itself, which is the one piece of bookkeeping this file pushes outward rather than doing.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `tag_end(text, from)` | The position of the > that closes a tag, ignoring any inside quotes. |

## Where it sits

Used by `012-read-the-strokes`, `013-read-the-meanings`, `019-the-kanji-record`.
