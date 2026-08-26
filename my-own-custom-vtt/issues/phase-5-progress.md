# Phase 5 — The bridge and the browser

**Goal:** the first thing you can actually play.

**Status: complete.** All eight issues done. `./run-phase-demo 5` starts a server
and a bridge and hands you a URL.

## The issues

| Issue | What it established |
| --- | --- |
| [501 the bridge holds one socket](completed/501-the-bridge-holds-one-socket.md) | A third program, and the four things it buys. |
| [502 the bridge serves a browser](completed/502-the-bridge-serves-a-browser.md) | A fixed list of files on loopback, and no directory to escape from. |
| [503 the view receives state](completed/503-the-view-receives-state.md) | State in, picture out. No pixel computed on the host. |
| [504 drawing between two ticks](completed/504-drawing-between-two-ticks.md) | Interpolation, and why appearing bodies must not slide out of walls. |
| [505 your own body is predicted](completed/505-your-own-body-is-predicted.md) | The one unconfirmed thing shown, and why it is not an exception. |
| [506 light from the visibility polygon](completed/506-light-from-the-visibility-polygon.md) | The shape computed for security, drawn. |
| [507 keys become commands](completed/507-keys-become-commands.md) | A held key is a state, not an event. |
| [508 the phase five demo](completed/508-the-phase-five-demo.md) | The capstone, and the first one you play. |

## What is built

| Source | What it is |
| --- | --- |
| `064-httpd` | Enough HTTP and RFC 6455 to work. SHA-1 and base64 written out. |
| `066-view.html` / `067-view.js` | The page and the renderer. |
| `068-server-main` | The program a host runs. |
| `069-bridge-main` | The program each participant runs. |

The build now embeds the browser's files as C string literals, so the bridge is
one file to copy with no directory beside it.

## The spine, proven end to end

A websocket client spoke to a running pair and confirmed, in order:

- the handshake answer matched SHA-1 of the key plus the specification's GUID;
- a binary frame arrived carrying **1 tick, 2 walls, 4 bodies, 104 visibility
  boundaries**;
- a drive command sent the other way moved a body **9.99 metres east**;
- and a door leaf **dropped out of the update** as the new angle put it behind a
  corner.

That last one is the whole project working: the filter reconsidering what a
person may know, live, because they moved.

The server held 20.0 beats a second across 1,931 beats with a participant
connected and moving, and shut down cleanly on a signal.

## Three bugs the running found that the writing had not

**A tight spin where a wait belonged.** The door made its accepted socket
non-blocking and retried the join read a thousand times with no pause — which is
microseconds. Any client whose bytes were a moment behind its connection got hung
up on. The symptom was a bridge being told its protocol was wrong when its
protocol was fine. Replaced with a bounded blocking read and a quarter-second
timeout.

**A refusal that blamed the wrong end.** The client's default outcome was
"not this protocol", so a connection that never got answered reported a protocol
mismatch — sending somebody to look at the wrong thing entirely. There is now a
`JOIN_NO_ANSWER` that says what actually happened.

**Two programs that looked hung.** Redirected to a file, C buffers stdout by the
block, so neither program's startup banner appeared until it exited. `setvbuf`
with line buffering, in both.

None of these would have shown up in a test. All three needed the thing to
actually run.

## A test that was reasoning backwards

The check that the httpd binds loopback tried to infer it by binding the same
port on all interfaces afterwards — which *fails*, because "all" includes
loopback. It now calls `getsockname` and asks the socket directly.

## Blocking open questions

- The bridge only reaches a server on this machine, and says so rather than
  failing obscurely. Reaching one across a network is the next thing it needs.
- **4.2** — still nothing authenticates.
- **13.1** — the motion passes still go to the pool and still should not.

## What phase 6 inherits

A running system somebody can walk around in, and one viewer with one body. What
is missing is the dial: several bodies, a region, a whole map.
