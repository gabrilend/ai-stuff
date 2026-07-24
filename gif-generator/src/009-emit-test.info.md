# 009-emit-test — proof for emitters

Runnable directly (`luajit src/009-emit-test.lua [project-dir]`).
Proves: divisible rates birth exact counts; awkward rates stay within
one birth over a thousand ticks (the floor-and-carry note explains
the "at most one"); one seed tells one story twice and two seeds
diverge; envelope strength scales births and silence births nothing;
full aim rides the heading exactly; misspelled recipe fields are
refused with the legal list; seed zero still rolls. Exits nonzero on
failure.
