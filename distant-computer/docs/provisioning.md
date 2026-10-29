# Provisioning the distant computer

What has to be true of the Linode before it is a distant computer. Phase 5's
provisioner makes these true, and the health check confirms them. Until then
this list is the checklist for doing it by hand.

## The owner does

1. Create the Linode. The full monorepo history is several gigabytes
   (`git -C /mnt/mtwo/programming/ai-stuff count-objects -vH` gives the
   current size), and twinned large files come on top. Choose a disk at least
   four times what that reports.
2. Write its address and the root login method into `input/distant`
   (not tracked in git: listed in `.gitignore`).
3. Decide the steward's API key and budget (`input/budget`).

## The provisioner does

| step | why |
| --- | --- |
| create user `steward`, with sudo on the distant computer | it is the steward's machine |
| install `luajit`, `git`, `rsync`, `openssh`, `chrony`, `jq`, Claude Code | the programs it runs; chrony keeps its clock in step with kuvalu's, which the heartbeat depends on; jq is needed by the house library that rebuilds the RAM scratch folders after a reboot |
| generate a key on **kuvalu** and add its public half to `steward`'s `authorized_keys` | the link dials from near only. No key is ever made on the distant computer for kuvalu |
| firewall: allow SSH in, nothing else | the link is the only way in |
| clone the monorepo from kuvalu by pushing to a bare repository on the distant computer, then check it out | the clone comes from kuvalu, not from GitHub, so it holds exactly what kuvalu holds |
| copy `~/.claude/CLAUDE.md` and the house skills | the steward's instructions |
| make `outbox/`, `answers/`, `link/`, `loose/`, `records/` | the folders the datapaths name |
| install the watchdog and steward as services | they start again after a reboot |

## The health check reports

Each row is checked and printed as passed or failed with what was found:
reachability, the user and its sudo, each program's version, clock offset
from kuvalu, firewall rules, the clone's `main` matching kuvalu's, every
folder, both services running, and the heartbeat's age.
