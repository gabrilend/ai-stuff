# 090-test-the-image — info

Checks the recipe, the board description and the builder that turns them into bytes. Issues 501 and 502.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `090-test-the-image.lua` and run the sweep again.*

## Invocation

```
luajit 090-test-the-image.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `storage` | `{}, payload = { kind = "uefi-esp" }` |  |
| `verified_against` | `"nowhere" }` |  |
| `storage` | `{}, payload = { kind = "boot-sector" }` |  |
| `verified_against` | `"invented" }` |  |
| `board_id` | `"invented-machine", arch = "x86_64"` |  |
| `console` | `{ kind = "com1-port", base = 0x3f8 }` |  |
| `storage` | `{ controller = "ahci" }` |  |
| `payload` | `{ kind = "uefi-esp", boot_path = "EFI/BOOT/BOOTX64.EFI" }` |  |
| `verified_against` | `"invented for this check, and transcribed from nothing"` |  |
| `recipe` | `recipe, board = invented, describe = describe, sampler = ...` |  |
| `rides` | `rides, envelope = envelope` |  |
| `medium_module` | `medium_module` |  |
| `waking_bytes` | `string.rep("K", 300)` |  |
| `engine_bytes_content` | `string.rep("E", 2000)` |  |
| `model_bytes` | `model_bytes` |  |
| `text_bytes` | `string.rep("T", 700)` |  |
| `components` | `{ assembler = "073", tokenizer = "059" }` |  |
| `recipe` | `recipe, board = invented, describe = describe, sampler = ...` |  |
| `rides` | `rides, envelope = envelope` |  |
| `medium_module` | `medium_module` |  |
| `waking_bytes` | `string.rep("K", 300)` |  |
| `engine_bytes_content` | `string.rep("E", 2000)` |  |
| `model_bytes` | `model_bytes` |  |
| `text_bytes` | `string.rep("T", 700)` |  |
| `components` | `{ assembler = "073", tokenizer = "059" }` |  |
| `recipe` | `recipe, board = invented, describe = describe, sampler = ...` |  |
| `rides` | `rides, envelope = envelope` |  |
| `medium_module` | `medium_module` |  |
| `waking_bytes` | `string.rep("K", 300)` |  |
| `engine_bytes_content` | `string.rep("E", 2000)` |  |
| `model_bytes` | `string.rep("X", 4096)` |  |
| `text_bytes` | `string.rep("T", 700)` |  |
| `components` | `{ assembler = "073", tokenizer = "060" }` |  |
| `model` | `{ at = 999999 }` |  |
| `console` | `{}, storage = {}` |  |
| `payload` | `{ kind = "uefi-esp", boot_path = "EFI/BOOT/BOOTSPARC.EFI" }` |  |
| `verified_against` | `"invented" }` |  |
| `recipe` | `recipe, board = wrong_arch, describe = describe, sampler ...` |  |
| `rides` | `rides, envelope = envelope` |  |
| `medium_module` | `medium_module` |  |
| `recipe` | `recipe, board = invented, describe = describe, sampler = ...` |  |
| `rides` | `rides, envelope = envelope` |  |
| `medium_module` | `medium_module` |  |
| `model_bytes` | `string.rep("W", 64)` |  |
| `shape` | `a table below` |  |
| &nbsp;&nbsp;↳ `kv_heads` | `8, feedforward = 14336, vocabulary = 128256` |  |
| &nbsp;&nbsp;↳ `context` | `8192 }` |  |
| `budget` | `budget, board_memory = 64 * 1024 * 1024` |  |
| `medium_bytes` | `8 * 1024 * 1024 * 1024` |  |
| `engine_bytes` | `2 * 1024 * 1024` |  |
| `read_only` | `read_only, contents = "" }` |  |
| `image` | `image, identity = built.identity, look = look, dry_run = ...` |  |
| `targets` | `a table below` |  |

## Worth knowing

The two checks that matter most are the ones about disagreement: that a recipe naming a board is refused, since a recipe that names one has become a recipe FOR it; and that the builder and the engine are held to the same account of where things are, because that disagreement is what makes a machine fail at the earliest possible moment with the least possible information.

## Where it sits

**Belongs to** `501`.

