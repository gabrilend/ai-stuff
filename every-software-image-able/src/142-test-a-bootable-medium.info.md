# 142-test-a-bootable-medium — info

Checks that what 141 builds is a medium a firmware will open, and checks it the only way that means anything: by asking a firmware.

This project spent months producing images that were correct in every way it knew how to check and that no computer on earth could start. The checks it had compared the builder's arrangement against the engine's expectations, and both were right. Nobody asked the component that has to find the first byte. This asks it.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `142-test-a-bootable-medium.lua` and run the sweep again.*

## Invocation

```
luajit 142-test-a-bootable-medium.lua [--dir ROOT] [--quick]
```

## What it describes

| Field | Value | |
|---|---|---|
| `bytes` | `string.rep("R", 900)` |  |
| `path` | `"EFI/BOOT/BOOTRISCV64.EFI"` |  |
| `identity` | `"long-name"` |  |
| `bytes` | `"x", path = "EFI/BOOT/BOOTRISCV64.EFI", identity = "x" })...` |  |
| `bytes` | `string.rep("Z", 3000)` |  |
| `path` | `"EFI/BOOT/BOOTX64.EFI"` |  |
| `identity` | `"witness"` |  |
| `label` | `"SEED"` |  |
| `bytes` | `payload, path = target.path` |  |
| `identity` | `"boot-" .. target.arch, label = "SEED"` |  |

## Three kinds of witness, on purpose

The structures here are checked by this file, then by tools written by other people who have no stake in this being right, then by a real firmware being handed the bytes. The first can be fooled by a mistake shared between writer and reader -- which is exactly the failure this project keeps meeting -- and the second cannot, and the third is the thing that actually has to work.

## Worth knowing

  --quick skips the boots, which take about twenty seconds each.

