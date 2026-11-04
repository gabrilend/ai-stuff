# Core terms

The words this project uses for its own parts. Every other document, comment
and conversation uses these words and no others for these things.

| term | means |
| --- | --- |
| **owner** | gabrilend. The one person who answers requests and makes major decisions. |
| **near computer** | kuvalu, the owner's machine. Holds the monorepo of record. |
| **distant computer** | the Linode. Holds a clone of the monorepo and runs the steward. |
| **monorepo** | `/mnt/mtwo/programming/ai-stuff/` (reached as `/home/ritz/programming/ai-stuff/`), one git repository holding every project. |
| **link** | the SSH connection the courier opens from near to distant. It only ever goes in that direction. |
| **courier** | the program on the near computer that dials the link on a timer and carries requests in, answers out, `main` out, and a heartbeat. |
| **heartbeat** | a file on the distant computer that holds the time the courier last arrived. |
| **watchdog** | the program on the distant computer that reads the heartbeat's age and says **connected** or **waiting**. |
| **connected / waiting** | the two states of the distant computer. Waiting means the heartbeat is too old: the near computer may be gone. |
| **steward** | the Claude Code session running headless on the distant computer, working through issue files. |
| **voice** | one persona of the steward, with its own instructions and its own level of abstraction for talking to the owner (phase 7). The vision calls them "threaded experts". |
| **outbox** | the folder on the distant computer where the steward writes requests. |
| **request** | one file asking the owner for one thing. It has a kind, a reason, and a body. |
| **kind** | what sort of request it is: `commit`, `write`, `sudo`, `outward` or `decision`. Each kind has its own reader and applier. |
| **gate** | the folder of waiting requests on the near computer, plus the `gate` command that shows and answers them. |
| **approved / declined** | the two answers. (Declined, not "not approved".) |
| **applier** | the code that carries out an approved request of one kind. `outward` has none on purpose. |
| **ledger** | an append-only record of every request, every answer, and every applied change. Each entry carries the checksum of the one before it, so any edit to the past breaks the chain where it happened. |
| **placement** | where a file lives: **tracked**, **twinned** or **resident**. |
| **tracked** | in git, so on both computers. |
| **twinned** | a large file outside git, kept whole on both computers and matched by checksum. |
| **resident** | on one computer only. The other side holds a **stub** that names where it lives and its checksum, and fetches the file on request. |
| **owning side** | the computer a place belongs to. Every place has exactly one. |
| **crystallized** | the parts owned by whichever side is absent. Neither side touches the other's parts while the link is down, until they return or are given up by a request ("forced cooperativity by tying together two ankles"). `docs/datapath-link.md` lists who owns what. |
| **loose area** | a scratch folder on the distant computer that belongs to no project. The steward's place to work while waiting. |
| **budget** | the API spending ceiling set by the owner. The steward stops before it, not after. |
| **funding goal** | something the steward is working to afford, such as hiring a person for legal and business paperwork. A line in `goals/`, not a promise. |
| **hand-me-down** | a tool or piece of work the steward has outgrown, offered to someone who could use it, through an `outward` request. |
| **receipt** | `output/goodbye`, written last by every program on a clean exit. |
