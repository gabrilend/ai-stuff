# The network

The owner sets the network rules in the router, not this project. This
document records them and works out what each part of guide-feature needs
from them.

## The rules, in the owner's words

> Each system will have an r-mail mailbox, and they are wired to only accept
> connections from each other in the router settings. They can reach out to
> external LLM providers, but then they only accept exactly them as well, and
> only if we reached out first this session.

In firewall terms:

- **Between the four machines** (192.168.1.100, .11, .12, .13): connections
  allowed in both directions.
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
| a browser, phone or watch → kuvalu's canvas server | from outside the four | **no**, as the rules stand |
| rmail's public-address check and port mapping (it asks outside websites for the public IP, and the router for a port) | outward to services that are not language-model providers | **unclear** |
| installing software on the mini-computers | outward to package mirrors | **unclear** |

The three rows marked no or unclear are open questions
(`docs/open-questions.md`). The remote viewers (HTML page, Android, Apple
Watch) depend on the first. rmail asks outside websites for the public
address and uses UPnP or NAT-PMP to map its port (`rmail.lua`, the address
and port-mapping code). Whether a mailbox can be told not to do either has
not been checked yet. If it cannot, those requests will fail under these
rules, and they will show up in rmail's log.
