# 8-061: A Second Home at ritzmenardi.com

## Status
- **Phase**: 8 (Website Completion)
- **Priority**: Low (future work, asked for on 2026-10-01)
- **Type**: Feature
- **Status**: Open
- **Blocked by**: nothing in this project; the machine it lands on is set up
  by issue 10-006 of `double-diaper-dungeon`
  (`/mnt/cmdo/ritz/games/tq/ai-stuff/double-diaper-dungeon/issues/10-006-stand-up-the-linode.md`)

## Why this exists

The same website, served from two places by two different hosts: Neocities at
`ritz-menardi.neocities.org`, as it is today, and a rented Linode at
`ritzmenardi.com`. Then the visits to both are counted the same way and shown
together. In her words, from the conversation where the Linode was stood up:

> neocities-ii is my neocities page's most recent backup from June, and I
> think it'd be neat to have it hosted at both locations - linode if they go
> to ritzmenardi.com, and neocities if they go to ritz-menardi.neocities.org
>
> same website, different domain providers. Just because... Then I'll make
> sure to track the same statistics I gather from neocities on the linode
> instance, and we can build a dashboard or something that displays both
> values combined together somehow.

## Current Behavior

- **Neocities is the only home.** `scripts/deploy-to-neocities` uploads the
  built site through `libs/neocities-api.lua` and `libs/neocities-sync.lua`:
  diffs by content hash, sends only what changed, resumes after failure, and
  never asks the server to delete a directory.
- **The newest backup of the live site** is
  `/home/ritz/backups/neocities-ii/neocities-ritz-menardi-june-2026.zip`
  (beside an older `neocities-ritz-menardi.zip`; the folder is 9.4 GB). It is
  a download of what Neocities serves, not a build from this project.
- **A Linode exists and already serves one site.** It is at
  `172.232.175.93`, Ubuntu 26.04, reached as `ssh abcd-games` (user `ritz`,
  key `~/.ssh/abcd-games.net`), walled to ports 22, 80 and 443, with Caddy
  serving `abcd-games.net` over HTTPS from `/var/www/abcd-games.net`. Its disk
  is 25 GB with about 20 GB free.
- **Statistics come only from Neocities**, which counts hits and views per
  site and reports them through its API's site-information call.

## Intended Behavior

| | Neocities | the Linode |
| --- | --- | --- |
| address | `ritz-menardi.neocities.org` | `ritzmenardi.com` and `www.ritzmenardi.com` |
| what it serves | the site | the same site, byte for byte |
| how it gets there | `deploy-to-neocities`, as now | a second sender: rsync over SSH as `ritz`, into its own folder beside abcd-games' |
| certificate | Neocities' | Caddy's, from Let's Encrypt, renewed by itself |
| statistics | Neocities' own counters, read from the API | Caddy's access log, counted on the machine |

**One build, two senders.** The site is built once and both senders read the
same output folder, so the two homes can only differ by when each was last
sent, never by what was built. The Linode sender keeps the three promises the
Neocities one keeps (only what changed, resume rather than restart, never
delete), which rsync gives with `--checksum`, `--partial`, and no `--delete`.

**Counting the same thing on both sides is the hard part.** Neocities decides
what a "hit" and a "view" are; the Linode would have only raw log lines. A
combined number is only honest if both columns mean the same thing, so the
first job is to learn Neocities' definitions and write the Linode's counter to
match them, and to show the two side by side before ever adding them up.

**The dashboard is a viewer, apart from the counting.** Counting writes a
small dated table (date, host, hits, views); the dashboard only reads it. That
keeps a mistake in either one inside that one.

## Suggested Implementation Steps

1. **Confirm the domain.** Is `ritzmenardi.com` owned, and where are its DNS
   records kept? Point `@` and `www` at `172.232.175.93` with two `A`
   records.
2. **Add the second site to the Linode.** A second site block in Caddy's
   config for `ritzmenardi.com, www.ritzmenardi.com`, serving
   `/var/www/ritzmenardi.com`, owned by `ritz`. The machine's setup lives in
   `double-diaper-dungeon/scripts/set-up-the-server`, which writes Caddy's
   whole config; the second site belongs there, or that script learns to
   include site files from a folder, so one project's re-run does not erase
   the other's site.
3. **Measure before sending.** The June backup is 9.4 GB of zips; the site
   unpacked, and the built site from this project, need sizing against the
   20 GB free.
4. **Write the Linode sender** beside `deploy-to-neocities`, reading the same
   build folder, with `--dry-run`.
5. **Turn on Caddy's access log** for the new site only, as JSON lines,
   rotated, kept on the machine.
6. **Write the counter** on the machine (or pulled to the laptop) that turns
   the log into hits and views by Neocities' definitions, and the reader that
   asks Neocities' API for its own, both writing to the same dated table.
7. **Write the dashboard** as a page that reads the table: both columns, and
   the combined total.

## Related Documents and Tools

- `scripts/deploy-to-neocities`, `libs/neocities-api.lua`,
  `libs/neocities-sync.lua`: the existing sender, and the promises the new one
  must keep
- `issues/10-052-self-hosted-source-browser.md`: another page that wants to
  live somewhere other than Neocities
- `double-diaper-dungeon/issues/10-006-stand-up-the-linode.md`: how the
  machine was built and how to rebuild it
- `double-diaper-dungeon/scripts/set-up-the-server`,
  `double-diaper-dungeon/scripts/publish-the-site`: the machine's setup, and
  the rsync sender this one can copy

## Open Questions

1. **Is `ritzmenardi.com` bought, and at which registrar? — ANSWERED.**
   *"yes. Also from squarespace."* So step 1 is the same two clicks that
   pointed `abcd-games.net` at the machine: at domains.squarespace.com, the
   domain's DNS Settings, delete the "Squarespace Defaults" group and add `A`
   records for `@` and `www` to `172.232.175.93`. Squarespace's records say
   they are good for four hours, so the machine's own resolver may lag; ask
   the domain's own name servers, as `set-up-the-server` does.
2. Does the Linode serve the June backup as it is, or the site this project
   builds now? The backup is the live site as visitors saw it in June; the
   build is newer.
3. What are Neocities' exact definitions of a hit and a view, so the Linode's
   counter can match them?
4. Should the machine's setup stay in `double-diaper-dungeon`, now that a
   second project lives on it, or move somewhere both projects share?
