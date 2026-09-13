# Phase 4 Progress — The Cloud

**The goal:** the air war, somewhere else. Planes go to a swarm above the field,
fight in rounds on a counter, leave when outmatched, and are chased over the
guns. A scout's report pulls bombers out of it.

**Ends with:** an air war that one side wins and then loses — winning the cloud,
following the losers over their anti-air, and coming home thinner.

| Issue | | Status |
| --- | --- | --- |
| 401 | The cloud is a place over the field | not started |
| 402 | Planes fly from the factory to the cloud | not started |
| 403 | Fight or avoid | not started |
| 404 | Defensive planes fly over friendly ground | not started |
| 405 | Anti-air shoots what flies over it | not started |
| 406 | A report sends bombers | not started |
| 407 | The plane upgrade table | not started |

**Blocking:** E1 and E2 (where the cloud is; whether it can be shot from below)
change the air war's geometry and sit under 401 and 405. E5 (where air strength
comes from) sits under 403 and 407.

**Carry into the work:** a plane is a unit like any other — a row in the unit
arrays with the air domain — and its missions are a dispatch table. Nothing in
the cloud is a special case of the unit record.

**Demo:** not yet built.
