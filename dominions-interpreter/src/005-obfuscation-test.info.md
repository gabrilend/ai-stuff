# 005-obfuscation-test.lua

Proves the disguise module. Exposes `run(check, home)`.

Given a Dominions folder it reads every world state file in the collection and
asserts that the first string after the header equals the folder name. That is
the standing check on the padding rule, and it is a test rather than a comment
because it is the thing that would catch the rule going wrong.

It also asserts the ambiguity itself in both directions: a raw zero reveals to
the capital letter O, and the capital letter O is stored as a raw zero.
