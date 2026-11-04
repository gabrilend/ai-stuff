# 043-say-test — the whole say run, end to end

`luajit src/043-say-test.lua [DIR]`. A scratch project in RAM, a stand-in
`claude` playing both a word session and the director, a stand-in viewer
that records its arguments. Typed input from a pipe: "a spiral of ember
light", an empty line, "make it bigger", "/done". Checks: the unknown word
found, taught, filed and added to the tracker; the viewer told to watch the
draft; the director's first reply and the chat reply shown; prose, score,
gif and chat log kept, the kept score the last one; the goodbye counting
one word taught and one chat turn.
