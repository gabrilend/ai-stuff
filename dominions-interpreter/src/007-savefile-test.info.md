# 007-savefile-test.lua

Proves the savegame reader against the whole local collection. Exposes
`run(check, home)`.

The properties checked are the ones a wrong offset would break all at once:
every version recovered must be a real published Dominions version, every turn
must land in a plausible range, and every game must call itself what its folder
calls it.

It also asserts that one record stride dominates the collection — without
naming the number, because the number is measured, not declared. Naming it here
would put a literal in exactly the place the project promised not to.
