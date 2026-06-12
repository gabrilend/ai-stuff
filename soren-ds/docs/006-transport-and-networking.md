# Transport and networking

The device can reach other devices in three ways: over a USB-C
cable, over the ad-hoc WiFi radio, and across the local soramech
runtime to itself. This document describes how applications above
that layer don't have to know which.

## The peer abstraction

Applications never name a transport. They name a *peer*: "the
laptop currently connected by cable," "the handheld named Foo on
the radio," "myself." The kernel keeps a table mapping peer names
to the transports they are currently reachable through, and when
an app says "deliver this to peer X," the kernel picks whichever
transport is live and routes the bytes through it. If the user
unplugs the USB cable and then turns on the radio, the same peer
is now reachable through a different transport; the app doesn't
notice.

Underneath, every transport ends up looking like a soramech wire
— a producer drops bytes in, a consumer pulls them out. The wire
discipline is the same one the kernel uses for its own threads.
USB-C, radio, and intra-device IPC differ in their drivers, not
in their shape.

## USB-C as a virtual ethernet adapter

When a USB-C cable is plugged in, the device presents itself to
the laptop as a virtual ethernet adapter using a standard USB
networking profile. The laptop sees a new network interface and
treats it like any other. Linux, macOS, and Windows all pick this
up without driver work on the laptop side.

Once the link is up, the laptop and the device have an IP
connection between them. Any protocol that runs over IP — the
editor's HTTP, rmail, anything we add later — works over the
cable without knowing it's a cable.

## The USB-C inbox and outbox

Alongside the virtual ethernet adapter, the device also exposes
itself as a USB mass-storage device with two directories:

- A **read-only** directory containing the laptop client
  installer and anything else the device offers for download.
  The laptop user drags the installer to their desktop and runs
  it.
- A **write-only** inbox where the laptop can drop files. The
  device watches the inbox and processes anything dropped into
  it: a soramech map gets imported, an image gets handed to the
  paint app, a config gets opened in the editor. Files in the
  inbox don't persist past the disconnect.

This split — read-only down, write-only up — communicates intent
without documentation. The user doesn't have to read instructions
to know which folder is for what; the asymmetry tells them.

## Ad-hoc radio

The WiFi driver runs in IBSS mode, also known as ad-hoc mode.
There is no router and no access point. Devices that want to
talk to each other negotiate directly on the air.

Once associated in IBSS, devices pick their own IP addresses
from the link-local range (`169.254.x.x`) and announce themselves
with a small "I am here, my name is X" broadcast every few
seconds. Other devices listening on the same channel see the
announcement and add the announcer to their peer table.

There is no router-based LAN support and no general internet
access. The reasoning lives in `009-deferred-work.md`.

## rmail as the messenger and the file mover

rmail is a token-authenticated, AES-256-GCM-encrypted peer
protocol originally designed for messaging across the open
internet. We use a stripped version of it as the universal
"send something to a peer" layer in Soren DS.

The messenger app sends rmail messages. The paint program sends
rmail attachments (which is just an rmail message with an image
body). The remote-file feature — "save this to my laptop" —
sends an rmail delivery to the laptop peer's inbox. One
protocol, three uses.

What changes from rmail's original design is the layer
underneath: instead of opening TCP connections to addresses
resolved against the open internet, our rmail binds to the
transport abstraction described above. A delivery to a peer
goes out through whichever transport is currently live for that
peer.
