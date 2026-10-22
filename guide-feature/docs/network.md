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
to map its port (`rmail.lua`, the address and port-mapping code). Whether a
mailbox can be told not to do either has not been checked. If it cannot,
those requests will fail under these rules and show up in rmail's log.

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

Two things still need the owner's decision (`docs/open-questions.md`): whether
viewers from outside need a key to read the canvas, and whether the causeway
should be encrypted (HTTPS). Without encryption, everything on the canvas
crosses the internet as readable text.
