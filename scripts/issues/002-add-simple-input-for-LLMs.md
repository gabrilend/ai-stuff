the LLM-transcript functionality should also generate an additional
file which stores just the user submitted prompts, one per line. Then,
when the LLM is restoring it's old context, it'll have the capability of
seeing exactly what the user requested, and examining their old responses
for clarification if they ever request a specific modification that seems
out of place or undefined. This file should be stored alongside the
transcript files.
