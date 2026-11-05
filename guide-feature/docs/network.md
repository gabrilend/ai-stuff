# The network

The owner sets the network rules in the router, not this project. This
document records them and works out what each part of guide-feature needs
from them.

## The rules, in the owner's words

> Each system will have an r-mail mailbox, and they are wired to only accept
> connections from each other in the router settings. They can reach out to
> external LLM providers, but then they only accept exactly them as well, and
> only if we reached out first this session.

and, for the viewers:

> they talk to just the kuvalu program server. the router can be open for a
> single route of approach. Like a narrow cause-way at a castle.

In firewall terms:

- **Between the four machines** (192.168.1.100, .11, .12, .13): connections
  allowed in both directions.
- **The causeway**: one port forwarded from outside to kuvalu's canvas
  server, and nothing else. Phones, the watch and browsers elsewhere come in
  this way and reach nothing but that one program.
- **From anywhere else, inward**: refused.
- **Outward to an outside language-model provider**: allowed. The provider's
  answers are let back in only on a connection one of the four opened
  ("stateful" or "established-only" filtering), so a provider can never start
  a conversation.

## What each part needs

| Part | Connection | Allowed? |
|---|---|---|
| rmail, voice ↔ kuvalu | between the four, ports 1223, 10101, 20202, 30303 | yes |
| a voice → kuvalu's llama.cpp servers | between the four | yes |
| a voice → an outside provider | outward, answered on the same connection | yes |
| a voice cloning the project from kuvalu | between the four (git over SSH) | yes |
| kuvalu's desktop viewers | on kuvalu itself | yes |
| a browser, phone or watch → kuvalu's canvas server | through the causeway | yes |
| rmail's public-address check and port mapping (it asks outside websites for the public IP, and the router for a port) | outward to services that are not language-model providers | **unclear** |
| installing software on the mini-computers | outward to package mirrors | **unclear** |

rmail asks outside websites for the public address and uses UPnP or NAT-PMP
to map its port (`rmail.lua`, the address and port-mapping code). The owner: each is
a switch "the user should be able to turn ... off or on as they please". If
rmail has no such switch, one is added in this project's setup of it, and
whether it was on or off is written in each mailbox's log at start.

## Keeping the causeway narrow

The canvas server is the only program anyone outside can reach, so it is
built to have as little in it as possible (`issues/204`):

- **Read-only.** It answers `GET` requests for the canvas and the one HTML
  page. Nothing sent to it can change anything, and it has no other routes.
- **One program, one port.** It runs as its own process, separate from the
  blitter, reads only the canvas folder, and holds no rmail secrets and no
  endpoint keys.
- **Bounded.** It limits open connections and request size, and drops
  requests that do not finish quickly, so a flood of slow requests cannot hold
  it open.
- **Logged.** Every request from outside the four machines is logged with its
  address and route.

Built in `src/025-canvas-server.lua` (issue 204), with its limits in
`input/canvas-server`. The forwarded port on the router, and the encryption
described next, need the owner's machine and the HTML page (803). Until
then the server sends the canvas as plain text, through a seam (`seal`)
where the encryption goes.

The owner's answer on keys and encryption: "we can use r-mail's encryption
maybe? The display program (on your phone, computer, whatever) will have a
mailbox and display whatever it receives." rmail encrypts every message with
a secret shared by each pair of mailboxes (`docs/rmail-constraints.md`), so a
display that is a mailbox needs no separate key or HTTPS. Whether the display
collects from kuvalu or kuvalu pushes to it (a phone on a mobile network
usually cannot accept incoming connections), and how often: "we will tune
these numbers as we implement." A plain web browser cannot hold a mailbox,
so it keeps the HTTP canvas server: "HTTP server. We encrypt it in transit
and decrypt it in javascript." The server only ever holds and sends the
encrypted canvas.

The key never crosses the network. Each browser session has its own key,
separate from every rmail secret. It arrives one of two ways:

- **In the address.** It rides after the `#` (`http://.../#<key>`), a part
  of the address browsers keep to themselves and never send to any server.
  Each device bookmarks that address once.
- **From a password.** Without a key in the address, the page asks for a
  password. Each viewer has set up their own key on the server beforehand.
  The owner: "the user will be provided a prompt to enter a password if they
  didn't provide one. That part can fly in plaintext. They will need to have
  set up on the server their specific key beforehand." What flies in
  plaintext is the page and its prompt, never the password. The browser
  turns the password into the viewer's key itself, with a deliberately slow
  key-derivation function, so a guessed password costs real time to test.
  The server, which holds each viewer's key, makes a fresh key for the
  session and sends it locked (encrypted) with the viewer's key. The browser
  unlocks it, and every canvas in that session is decrypted with it.

The page decrypts with noble-ciphers, a copy of AES-256-GCM in plain
JavaScript (`docs/vendored-code.md`), because a browser switches on its
built-in decryption (Web Crypto) only for HTTPS pages or pages from the same
machine, and this page is neither.
