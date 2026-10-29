# Open questions

Every question that surfaced while designing. Each is waiting for the owner
until it has an answer written under it. A task touching one is in progress,
not finished, until it is answered.

## 1. What is crystallized?

The vision says that while waiting, the steward may use unused resources,
"never touching the ones that are crystallized". The design takes
crystallized to mean the monorepo clone plus anything listed in
`input/crystallized`. Is that the meaning? Or is crystallized something
else: work that has been approved, files that have stopped changing,
finished projects?

## 2. Should the steward have any work it may land without the gate?

The design gates every change that reaches kuvalu. Some kinds might be safe
to let through: a new file in a project's `desire/` or `llm-transcripts/`, or
a new issue file. Should any kind be let through without approval, or
should every change wait for you?

## 3. Cloud session, or Claude Code on the Linode?

"Claude-cloud session" could mean Anthropic's hosted sessions, or Claude Code
running on the Linode. The design uses the second (`docs/roads-not-taken.md`
says why). Did you mean the hosted kind specifically?

## 4. The shared repository: kuvalu, GitHub, or both?

The monorepo already pushes to `github.com/gabrilend/ai-stuff`. The design
syncs kuvalu and the distant computer directly over the link, and leaves
GitHub to you. Should the distant computer also be able to push its
`distant-work` branch to GitHub, where you could read it from anywhere?

## 5. The budget

What is the API spending ceiling per month, and should the steward stop at
it, or ask for more with a `decision` request first?

## 6. "Possibly others"

The vision names `/home/ritz/programming/ai-stuff/` and "possibly others".
Which other folders, when the time comes?

## 7. Which projects first?

Should the steward work across every project with open issues, or start with
a short list you choose?
