# 052-test-ask-until-it-fits — info

Tests for asking until a reply fits (051). A scripted model in this process
covers the issue's three cases:
- too wide, then fits;
- too wide five times, then fits;
- too many changes, accepted with the note.

Around them:
- the report and the cut reply sent back, with the owner's line;
- a cut reply never returned;
- look calls answered, by a given answerer, and past the limit;
- a copied ruler, with rows inside the width and as the whole ruled canvas;
- too few and too many rows, a tab, and fenced replies;
- a failed call ending the turn;
- the log, and the counts of asks, tries, problems, tokens and seconds.

The scripted model stops itself after 50 asks, since the loop has no last
try.

The same loop then runs end to end, through the model caller (046) and
curl, against a stand-in llama.cpp server (047) on 127.0.0.1. So does the
module's command line, with a stopped server too.

    luajit src/052-test-ask-until-it-fits.lua [--dir ROOT]
