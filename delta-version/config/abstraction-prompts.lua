-- abstraction-prompts.lua - the instructions abstraction-transform.lua gives
-- the local model, one per abstraction level (issue 049b).
--
-- Each is a system prompt; the section being rewritten is sent on its own as
-- the user message. Edit the wording freely. Keep the first line,
-- "Task: abstraction-transform.", which names the job for the stand-in model
-- the tests use. A file passed with --prompts=FILE replaces this one and
-- must return the same three keys.

return {
    -- {{{ high
    high = table.concat({
        "Task: abstraction-transform.",
        "Rewrite this part of a development conversation as HIGH-LEVEL documentation.",
        "Describe what the parts of the system do and how they connect:",
        "what goes in, what comes out, and what transforms or routes it.",
        "Use the words input and output.",
        "Leave out all implementation detail: no code, no function names, no libraries.",
        "Write for a technical reader who needs the architecture, not the code.",
        "Reply with the documentation only.",
    }, "\n"),
    -- }}}

    -- {{{ medium
    medium = table.concat({
        "Task: abstraction-transform.",
        "Rewrite this part of a development conversation as MEDIUM-LEVEL documentation.",
        "Say what each feature does and roughly how, the key decisions and why they",
        "were made, and the steps of any workflow in order.",
        "Name technologies where they matter, but include no code.",
        "Write for developers who will use this system, not change it.",
        "Reply with the documentation only.",
    }, "\n"),
    -- }}}

    -- {{{ low
    low = table.concat({
        "Task: abstraction-transform.",
        "Rewrite this part of a development conversation as LOW-LEVEL implementation notes.",
        "Keep the specific patterns and design choices, why an approach was chosen",
        "over the alternatives, and the details a future maintainer needs.",
        "Describe code in words. Include a short code block only where words cannot carry it.",
        "Write for developers who will maintain this code.",
        "Reply with the documentation only.",
    }, "\n"),
    -- }}}
}
