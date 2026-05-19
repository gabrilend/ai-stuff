---
name: Finder dual-desktop awareness
phase: 7
status: pending
blockedBy: [702, 703]
---

# 704 — Finder dual-desktop awareness

The Finder on each screen knows about the other screen's Finder and
about the shared volume in a coordinated way. Drag a file from
screen A's Finder to "the other screen" and it appears on screen B's
Finder.

## current behavior

Each instance's Finder runs independently. They share a volume
(issue 301 / 703) but don't know about each other. Users have to
manually navigate to the shared volume on each side to move files
between desktops.

## intended behavior

- The Finder gains a **"Other Screen"** menu in the Apple menu (or
  as a desk accessory).
- Selecting "Other Screen" opens a window showing the *other*
  instance's desktop layout — visible-on-this-screen icons that
  represent windows currently open on the other screen.
- Dragging an item into the Other Screen window sends it across via
  the broker IPC: the item appears on the other instance's
  desktop.
- The Finder's window list (the menu at the top right showing all
  open windows) optionally includes a "On other screen: ..." section
  that lists windows on the other instance.
- When the shared volume changes from one screen's writes, the
  other screen's Finder auto-refreshes if a shared-volume window
  is open.

## suggested implementation steps

1. Read the GS/OS Finder source. This is more complex than the
   subsystem-source reads in phase 6 because the Finder is a
   *program*, not a service — it has its own UI loop.
2. Identify the integration points: where the Finder draws its
   menus, where it handles drag-drop, where it tracks open
   windows.
3. Implement a "remote-desktop" client inside the Finder: when
   "Other Screen" is selected, send a request through the broker
   IPC for the other side's desktop state. Render a window showing
   it.
4. Implement the drag-receive logic on the other side: when an
   item arrives via IPC, treat it as a desktop drop.
5. Implement the auto-refresh logic: when the broker filesystem
   device's contents change (issue 703), notify any Finder window
   showing that volume to refresh.
6. Test the round-trip: drag a file from screen A's desktop to
   screen B's Finder via Other Screen; see it appear on screen B's
   desktop.

## related documents

- `issues/702-broker-input-device.md`, `issues/703-broker-filesystem-device.md`
  — the prerequisites
- `issues/304-appletalk-ipc-channel.md` — the cross-instance
  channel
- `docs/004-roadmap.md` — phase 7

## known design questions

- The Other Screen window is read-only as a desktop view, or
  fully interactive (can you double-click an icon on it to launch
  the program on the other screen)? Default for phase 7:
  read-only with drag-into support. Interactive Other Screen is a
  potential future enhancement.
- What if both Finders try to modify the desktop simultaneously?
  The file-locking from issue 302 mediates the underlying file
  changes; desktop database updates are last-write-wins via the
  broker's conflict policy (issue 305).

## notes

- This is the issue that makes the dual-desktop story *visible* at
  the OS level. Before this, the two desktops coexist; after, they
  acknowledge each other.
