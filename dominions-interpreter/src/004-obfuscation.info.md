# 004-obfuscation.lua

Seeing through the game's disguise. The only place in the project that knows
the constant.

Dominions hides the text in its save and configuration files by exclusive-or
ing every byte against one value. No key, no rotation, no compression, no
variation between files or versions. Undo it and the file is plain text mixed
with plain binary.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `mask()` | — | the constant, a number, for tests that assert rather than trust |
| `reveal(bytes)` | a string of bytes | the revealed string; **its own inverse**, so it hides too |
| `is_printable(chunk)` | a string | whether every byte is printable ASCII |
| `strings(bytes, from, minimum)` | bytes, a start offset, a minimum length | an array of `{offset, text}` |
| `names(bytes, minimum)` | bytes, a minimum length | an array of `{offset, length, text}` |

Offsets are zero-based, matching what a hex dump shows, because these numbers
get compared against hex dumps constantly.

## `strings` against `names`

They answer different questions and the difference matters.

`strings` answers *what text is in this region*, walking the null-terminated
strings structurally: split on the separator, strip each chunk's leading binary
and padding, reveal what remains. This is what the header wants.

`names` answers *where are the names*, and adds one requirement: the run must
**end at a separator**. A real name is always followed by the null that ends
its string, and requiring that keeps stretches of binary which happen to reveal
as letters out of the sample. This is what finding a record array wants,
because an array is found by measuring the distance between the names in it.

## The two consequences of the scheme, which are the whole difficulty

**A zero byte reveals to the constant.** Strings are null-terminated, so after
revealing, the constant is the separator between every string. That is what
makes the walk structural rather than a hunt for readable-looking runs — and a
hunt is worse, because a fragment of binary that looks like a name cannot be
told from a name by whoever receives it.

**A raw zero reveals to the capital letter `O`.** Padding and the letter O are
the same byte. Both functions resolve this the same way: the string starts
after the **last** raw zero in the run.

That rule is right overwhelmingly often, because padding is always there and
capital O's are not. The cost is that a name beginning with a capital O is
clipped at it — *Odysseus* comes back as *dysseus*. Lower-case o is a different
byte and is safe.

Resolving the other way was tried in the chronicler project and is worse: it
preserves capital O's but lets binary through, silently attached to the front
of real names, corrupting every name a little instead of one name a lot.

**Stripping only the leading zeros is not enough**, and the collection said so.
A commander record holds a small binary field a few bytes before the name, and
when that field holds 1 it reveals to the letter N. The run then begins at the
binary byte, there is no leading zero to strip, and the name comes back as
`NOOPaeon`. Measured across the collection, that error split one record stride
into two apparent ones.

## The standing check

The game name read out of a savegame is compared against the folder it was
found in, over the whole collection, every time the survey runs. If the padding
rule ever clips a name, that is where it says so.

## Related

- [The file format notes](../docs/dominions-file-formats.md)
- [issue 102](../issues/102-seeing-through-the-disguise.md)
- `005-obfuscation-test.lua`
