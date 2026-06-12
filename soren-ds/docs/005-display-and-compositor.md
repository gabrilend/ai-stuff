# Display and compositor

Two screens. Each has its own framebuffer in shared memory. The
question this document answers is: how do multiple soramech boxes,
running on different threads, share a screen without painting over
each other?

## Surfaces

A *surface* is a rectangle of pixels that one box (or one
encapsulated sub-map) owns the right to draw into. A surface knows
which screen it lives on, where in that screen it sits, and which
box owns it. A box can have many surfaces, but each surface has
exactly one owner.

When a box wants to draw, it asks the compositor "give me a
surface this big at this position on this screen." The compositor
either grants the surface (returning a handle the box can write
to) or denies it because something else owns that real estate.

## Damage tracking

When a box writes into its surface, the surface marks itself
dirty. The compositor scans dirty surfaces once per frame and
copies their pixels into the right screen's framebuffer, one
rectangle at a time. Surfaces that didn't change don't get copied.
This keeps the per-frame cost proportional to what actually
changed, which matters on a battery-powered device.

## Per-screen ownership

Each screen has a single foreground app at any moment. The
foreground app is the only app whose surfaces get composited to
that screen — with two exceptions, both described below: the
drawer for that screen, and the link transition that brings a
different app to the foreground. Background apps can still hold
surfaces and still draw into them; the compositor just doesn't
copy those surfaces forward until they come back to the
foreground.

The two screens have separate foregrounds. The top screen might
show the messenger while the bottom screen shows the editor. The
two foregrounds know nothing about each other.

## Drawers

A drawer is an overlay surface that slides in from the left or
right edge of a screen on a center-button press. There are four
drawers — left and right for each of the two screens — and the
mapping from center button to drawer is documented in
`004-input-model.md`.

A drawer occupies the full height of its screen minus about 5% of
margin on each edge, so the user sees they are inside a menu rather
than back in the app. It slides in from the full edge it belongs
to (the left drawer from the entire left edge, not from a corner)
in a single fast animation, then sits there until dismissed. On
dismissal it slides back out the same edge.

The drawer's contents come from whichever app currently holds the
screen's foreground. Apps populate their drawers with the
utilities they want close at hand — tool palettes, settings, the
list of inter-app links the app exposes. Most drawer contents
present as a small radial menu so the user can pick with the
input mechanism they already know.

While a drawer is open, the underlying surfaces still draw and
still update; the drawer just sits on top of them. Closing the
drawer reveals whatever the app has been doing in the meantime.

## Link transitions

When the user follows an inter-app link, the foreground app on
that screen changes. The compositor swaps the surfaces: the old
app's surfaces stop being composited (they remain allocated, with
their last contents preserved, because the app continues running
in the background), and the new app's surfaces become the
screen's foreground. The transition is a single-frame swap rather
than an animation, because the user has already chosen where they
want to be.

There is no back button, no return mechanic, and no history the
compositor has to track. If the user wants to go back to where
they came from, they follow another link — typically one the
destination app exposes specifically for that purpose. The
compositor treats every link transition the same way regardless of
which app it points to. Background apps that the user returns to
later through a forward link come up with the state they had when
they were foreground last, because they have been running in the
background the whole time.

## Boot and persistence

There is no launcher screen. On power-on, each screen restores the
app that was its foreground the last time the device was powered
off. The compositor draws those apps directly. If the device has
never been powered on before, the bottom screen starts in the
programming environment and the top screen starts in the
messenger, but as soon as the user changes anything that default
is overwritten by the persisted state.

Background app state is *not* persisted across power cycles. On
boot, the restored foreground app comes up fresh — at whatever
default state the app uses on a cold start — and the user follows
links forward from there. Mid-session, background apps keep
their state because they are still running; across a power cycle,
nothing is running, so nothing has state to keep.

## Both screens light up in phase 1

The phase 1 demo brings up both screens together, not just the
bottom one. The display hardware is a single controller with two
output paths, so the work to bring up the controller plus one
output is essentially the same work as the controller plus both —
the second output is a few extra register writes and a second
framebuffer allocation. Phase 1 is supposed to demonstrate the
hardware, and the hardware has two screens.
