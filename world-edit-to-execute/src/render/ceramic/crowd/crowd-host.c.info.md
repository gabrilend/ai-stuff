# crowd-host.c

The crowd's tick on the ceramic engine (issue 515k): the host takes the
snapshot, re-arms the landing, hands every chunk in as one batch, waits
for all to land, settles and moves the armies on. **Usage:**
`crowd-ceramic SCENE TICKS WORKERS` (`CROWD_CHUNK`, `CROWD_TIMELINE`,
`CERAMIC_SPIN` as elsewhere). Prints the same line as `crowd-hand.c`,
way `ceramic` or `ceramic-spin`.
