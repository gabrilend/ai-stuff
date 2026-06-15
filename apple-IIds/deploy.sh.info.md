# deploy.sh

Copies `tmp/build/` to the Anbernic RG DS over ssh. Skeleton until the
device is in hand; `--dry-run` is the only useful mode pre-hardware.

## configuration

Create `tmp/device.conf` (gitignored — per-developer, per-network):

```sh
DEVICE_HOST=user@10.0.0.42
DEVICE_PATH=/home/user/apple-IIds
```

## invocation

| invocation                       | effect                                |
|----------------------------------|---------------------------------------|
| `./deploy.sh`                    | rsync `tmp/build/` to the device      |
| `./deploy.sh --dry-run`          | print the rsync plan, copy nothing    |
| `./deploy.sh /custom/dir`        | override the project DIR              |

## checks

Refuses to run if `tmp/build/` is missing (you forgot to build).
Warns if `tmp/build/manifest.txt` is missing (build may be incomplete).
