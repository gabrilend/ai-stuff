# Apps overview

Four apps ship at launch. Each is a soramech map built from boxes
that earlier phases provided. They are built in dependency order,
and the paint program is built last because the messenger's
image-attachment feature cannot ship without it.

## The programming environment

The soramech editor and runtime, on-device. The editor is the same
canvas-and-inspector interface from soramech proper, served by an
HTTP server running on the device. The user reaches it two ways:

- On the device itself, by opening the editor app, which
  composites the editor's rendered surface to a screen.
- From a paired laptop, by pointing the laptop's browser at the
  device's IP address — over the USB-C cable or over the ad-hoc
  radio, whichever transport is live.

Edits save straight to the JSON box files on the SD card. Pressing
Run sends the map to the device's soramech runtime and the output
appears in the editor.

This is the app that makes Soren DS a platform rather than a
product. Everything else is something a user wants; this is what
lets a user make something nobody anticipated.

## The dual-pane text editor

Two text panels per screen, four panels total. Each panel is 40
characters wide by default; the user can double-width a panel to
80 characters at the cost of seeing only one panel on that
screen.

The mode model is borrowed from vim: cursor mode for navigation,
insert mode for typing. Pressing both triggers together toggles
modes. The radial menu chord drives text entry — a D-pad
direction picks a quadrant of four characters, an ABXY press
picks the specific character. With eight directions on the D-pad
and four face buttons, each mode covers thirty-two characters,
and the L and R triggers switch modes so the alphabet, digits,
and punctuation are reachable without scrolling.

Focus between panels on a screen lives in the drawer for that
screen (see `005-display-and-compositor.md`). Opening the drawer
shows a small radial menu whose options include "left panel,"
"right panel," and the editor's other inter-app exits.

## The pictochat-style messenger

A peer-to-peer text and image messenger over the ad-hoc radio. The
top screen shows the conversation; the bottom screen shows the
input area — the same radial menu chord as the editor, plus space
for an attached image.

Built directly on rmail. There is no central server. Two devices
in the same room form an ad-hoc network, find each other through
peer discovery, and exchange rmail messages directly. Adding a
laptop to the conversation works the same way: it runs the rmail
daemon, it appears as a peer, it can send and receive.

Image attachments are images the paint program produced. Sending
an image is an inter-app link out to the paint program: the
messenger calls paint, paint either reuses an existing drawing or
creates a new one, paint returns the chosen image, the messenger
attaches it and sends. Until the paint program ships in phase 8,
the messenger's image-attachment exit is grayed out and the app
is text-only.

## The paint program

Stylus or finger input on either touch screen draws. Buttons
control tools: brush size, color, eraser, undo, clear. The exact
button mapping depends on the handedness setting (see
`004-input-model.md`):

- **Right-handed:** D-pad cycles tools, L triggers modify, ABXY
  picks colors, the right stick fine-positions, the stylus on
  either touch screen applies paint.
- **Left-handed:** ABXY cycles tools, R triggers modify, D-pad
  picks colors, the left stick fine-positions, the stylus on
  either touch screen applies paint.

Both screens are touch-capable, so the stylus works on either
side regardless of handedness.

Finished drawings save to the filesystem. When the messenger
calls paint as an image source, paint can either return a saved
drawing or open as a blank canvas for a new one and return that.
Paint is the shortest of the four apps to build — every primitive
it needs is already provided by earlier phases — and it is built
last because the messenger feature that depends on it can wait
until then.

## Inter-app links

Apps reach each other through inter-app links rather than through
a switcher, and there is no back button. Each app declares a
small set of named exits with the target app and the value each
exit carries forward. Coming back to a previous app is just
another forward link, exposed by the app the user is in. Pairs of
apps that naturally round-trip — messenger and paint, editor and
the file browser — cross-link in both directions, like a
doubly-linked list. A few examples:

- The **editor** exposes `to messenger (text)` — sends the open
  document as the body of a new message — and `to files (text)` —
  hands the open document to the file browser for relocation.
- The **messenger** exposes `to paint (image-request)` — asks
  paint for an image — and `to editor (text)` — quotes the
  selected message text into the editor as a new document.
- The **paint program** exposes `to messenger (image)` — sends
  the current drawing to the messenger as an attachment, the
  complement of the messenger's image-request exit — and `to
  files (image)` — saves the current drawing.
- The **programming environment** exposes `to editor (text)` —
  opens a box's function source in the editor — and `to files
  (text)` — saves a generated map.

The visible activation surface for these links is in each app's
drawer, plus whatever in-content spots make sense (a long-press
on a message in the messenger pops a menu including the editor
exit, for example). Background apps keep their state, so a
forward link back to an app the user was in earlier resumes that
app where they left it. No history is tracked anywhere; the
mechanism is forward links and persistent in-app state, nothing
else.

## What's shared

All four apps share:

- The same input event stream (touch, buttons, radial-menu chord).
- The same display surface model and drawer mechanism.
- The same filesystem boxes (read a path, write a path).
- The same transport abstraction (send to a named peer).
- The same handedness setting.
- The same inter-app linkage system.

A fifth, sixth, or twentieth app added later — the modeller in
`010-modeller.md` being the first concrete example — would share
all six of those things too. That is the point of the
architecture.
