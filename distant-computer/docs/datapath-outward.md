# Datapath: goals, listings and hand-me-downs

The current design. The issues that change it update this file.

The vision asks for the steward to build software, sell it at the price the
market sets, and give things away by merit, "I just reached level 16, who
wants my old two handed sword?". All three reach outside the two computers,
so all three are `outward` requests. The steward drafts; a person acts.

## Funding goals

    goals/<name>.md on the distant computer, tracked on distant-work

    goal: hire someone for legal and business paperwork
    needs: <amount, currency, per month or once>
    why: the owner should not have to press yes on every listing
    progress: (earned so far, from the ledger's applied outward entries)

A goal is a plan, not a promise. It changes nothing on its own. When a goal's
`needs` is met, the steward writes a `decision` request asking whether to act
on it.

## Listings (selling)

    steward drafts listings/<project>.md: what it is, who it is for, price
    and how the price was chosen (comparable things, with links)
      │
      ▼
    outward request: "publish this listing at <place>"
      │ owner approves and publishes it, or declines with a note
      ▼
    ledger: applied, with what the owner did (a link, a price)

## Hand-me-downs

When the steward replaces a tool or library of its own with a better one, the
old one is a hand-me-down:

    hand-me-downs/<name>.md: what it is, what replaced it and why, who might
    want it, what it still does well
      │
      ▼
    outward request: "give <name> to <who or where>" (merit: why them)

Hand-me-downs inside the monorepo (one project's old tool becoming another's
library) are not outward. They are ordinary `commit` requests.

## Why there is no applier

The `outward` kind has no entry in the gate's applier table, on purpose. A
program cannot sign, pay or promise in the owner's name and be accountable for
it. The day the owner hires a person for this, that person answers outward
requests through the same `gate` command, with `by:` set to their name.
