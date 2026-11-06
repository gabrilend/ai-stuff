# component-orchestrator.lua / component-orchestrator.sh

Starts, stops and checks a project's long-running parts (daemons, clients,
model servers) in dependency order, and remembers what it started so a later
run can stop it. Abstracted from `handheld-office/scripts/orchestrator.lua`.
Design: issue 013.

## Lua

| call | does |
| --- | --- |
| `init{project_dir, state_dir?, quiet?}` | sets the project folder, reads `state.tsv` |
| `register(name, spec)` | `command` (or `binary`), `cwd`, `port`, `health_command`, `health_url`, `depends_on`, `start_wait`, `stop_wait` |
| `load_components(path?)` | registers from `components.tsv` |
| `start(name)` / `start_all()` | dependencies first; waits until healthy |
| `stop(name)` / `stop_all()` | TERM to the process group, KILL after `stop_wait`; `stop_all` stops dependents first |
| `status(name)` / `status_all()` | `{name, state, pid, started_at, port, port_open}`; state is `running`, `stopped` or `exited` |
| `health_check(name)` | true, or false and why |
| `port_open(port, host?)` | a TCP connect test through bash's `/dev/tcp` |
| `dependency_order(names?)` | names after their dependencies; errors on a cycle or an unknown name |
| `on(event, fn)` | `fn(name, info)` after `start`, `stop`, `fail` |

## Shell

```bash
source scripts/libs/component-orchestrator.sh
orch_init "$PROJECT_DIR"
orch_register daemon "target/release/daemon" 8080
orch_register client "target/release/client" "" daemon
orch_start_all; orch_status_all; orch_health daemon; orch_stop_all
```

Or straight from the command line:
`luajit scripts/libs/component-orchestrator.lua <project> start-all|stop-all|status|start NAME|stop NAME|health NAME`.

## Files

`<project>/tmp/orchestrator/`, or `$ORCH_STATE_DIR` when it is set:

| file | holds |
| --- | --- |
| `state.tsv` | name, pid, process start time (ticks since boot), started at |
| `components.tsv` | name, port or `-`, dependencies or `-`, command |
| `orchestrator.log` | one timestamped line per start, stop, failure |
| `<name>.out` | the component's own stdout and stderr |

A pid counts as the component only while `/proc/<pid>/stat` still shows the
same start time, so a reused pid is never signalled. Tested by
`tests/test_component-orchestrator.lua`.
