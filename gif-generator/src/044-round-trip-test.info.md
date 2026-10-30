# 044-round-trip-test — the reader and the writer agree

For each film, `040-gif-decode.lua` takes it apart (palette, delay, every
frame's raw indices) and `004-gif.lua` puts it back together; the result
must equal the original byte for byte. Only films this studio wrote can
pass. With no folder it films the approved six fresh into RAM; name the
owner's library to check every film there.

CLI: `luajit src/044-round-trip-test.lua DIR [gif folder]`. Run by
`./test-shape-films` on the approved six.
