# 803 - Emitting database statements

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | 801, 802 |
| Blocks | nothing |

## Current behaviour

Nothing is emitted.

## Intended behaviour

The bulk of a change set is values living in the server's world database, so the
bulk of emission is database statements wrapped in the patch form that project
already applies.

The target project's patch system has three application times. Data belongs to
the middle one - the tier that fires after installation and before validation,
which is where that project already applies its own per-profile database work.

The emitted artefact is a shell script matching the conventions in use there:

- Named with the tier's letter, a number, and a dash-separated description.
- A header comment stating what it is, which issue it came from, and whether it
  can run in parallel with others.
- An apply function and an unapply function, each in a vim fold, each named for
  the patch.
- Idempotent: applying twice does the same as applying once, and the function
  returns early having changed nothing if the change is already present.
- Reverting: the unapply function restores what was there before, which is
  possible only because the change set recorded the old value.

That last point is the reason this phase depends on the change set rather than
generating statements directly from the archive. A statement that sets a value
without knowing the previous one cannot be written as a reversible pair, and an
irreversible patch in a system built entirely on reversibility is a trap for
whoever runs it next.

## Suggested implementation steps

1. Map each entity kind and field to the table and column that holds it in the
   target's database schema. This mapping is the hard part and it is per-era.
2. Generate one patch per coherent group of changes rather than one per value,
   so the registry does not acquire a thousand entries.
3. Emit both directions from the same change set entry, so they cannot drift
   apart.
4. Make applying guard on the current value rather than blindly writing: if the
   value is not what the change set recorded as `from`, something else changed
   it since, and the patch stops rather than overwriting an unknown edit.
5. Test the round trip: apply, confirm the values moved, unapply, confirm the
   database is byte-identical to before.

## Related tools

The target project's patch registry document describes the three tiers and the
pipeline they fire in. Its existing post-install patches are the worked examples
of the form to match.
