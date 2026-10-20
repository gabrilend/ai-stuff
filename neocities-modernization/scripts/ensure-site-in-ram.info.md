# ensure-site-in-ram

Makes the built website live in RAM, with only its pictures on disk, so the
pages each build rewrites never wear the disk. Design: Issue 10-072.

## Usage

```
scripts/ensure-site-in-ram [DIR] [--migrate]
```

| argument | type | meaning |
| --- | --- | --- |
| `DIR` | directory | the project (default: this project's folder) |
| `--migrate` | flag | one-time move from a real on-disk `output/` folder |

`run.sh` calls it on every run, right after `scripts/ensure-tmp-symlink`.

## What it makes

| path | is | points at |
| --- | --- | --- |
| `output` | a relative link | `tmp/shared-memory/site` (RAM) |
| `tmp/shared-memory/site/media` | an absolute link | `assets/site-media/` (disk) |

Every program that writes `output/...` is unchanged; the link carries the
writes into RAM. After a logout the RAM folder is empty: the next run makes an
empty `site/` again and the build fills it.

## --migrate

For a project whose `output/` is still a real folder:
1. `output/media/` is renamed to `assets/site-media/` (same disk: instant).
2. The rest of `output/` is renamed `output-before-ram/` (ignored by git), to
   delete by hand once a build and a deploy have worked.
3. The links above are made.

Nothing is deleted. Each step refuses if its target already exists.

## Refusals (exit 1, message on standard error)

- `tmp/shared-memory/` does not exist (run `ensure-tmp-symlink` first).
- `output` is a real folder or file and `--migrate` was not given.
- `--migrate` finds `output-before-ram/` or `assets/site-media/` already there.

A refusal creates nothing.

## Readers of the site that know about the link

- `scripts/validate-output` and `scripts/quarantine-stale-output` search with
  `find -H`, which goes into a starting folder that is a link.
- `scripts/deploy-to-neocities` refuses a missing or empty site before it
  contacts the live site (an empty listing would make `--prune` delete
  everything live).

## Test

`scripts/ensure-site-in-ram.test.sh` covers: refusal without `--migrate`,
the migration, a second run, a simulated logout, the page check through the
link, and deploy's two refusals. It works in a scratch project in RAM.
