# libs/kml.lua

The Keyword Markup Language engine (KML 1.0, issue 017): finds `][keyword[]`
and `][keyword[p1,p2][]` placeholders in a template, runs each keyword's
configured bash command in a project folder, and puts its output in place.
Load with `dofile`; `process-template.lua` is its command line.

## Functions

| function | takes | gives |
| --- | --- | --- |
| `load_config(paths)` | list of configuration files, later ones layered over earlier; missing ones skipped | `{ keywords = { name = { command, section } }, settings = { error_mode, timeout, version } }`, or nil and a reason when none could be read |
| `scan(text)` | template text | list of pieces: strings (escapes already applied) and placeholders `{ name, params, raw, valid, why }` |
| `problem(placeholder, config)` | a placeholder from `scan`, a configuration | why it cannot be filled, or nil; runs nothing |
| `process(text, options)` | text; `{ config, project_dir, template_name, error_mode, timeout, ticket_id }` | filled text (nil when the mode is `fail` and something failed) and a report `{ keywords, commands, errors = { { name, raw, message } } }` |
| `params_needed(command)` | a configured command | the highest `PARAMn` in it: how many parameters a placeholder must give |
| `substitute_params(command, params)` | command, list | the command with `PARAM1`..`PARAM5` replaced |
| `run_command(command, dir, timeout)` | bash command, folder, seconds | its output without trailing newlines, or nil and why (`exit N: first line of stderr`, `timed out after Ns`) |
| `valid_name(name)`, `valid_param(p)` | a string | boolean |

## Rules it holds

- Names: lower-case letters, digits, `_`; first a letter; 2 to 32 characters.
- Parameters: at most 5, each non-empty, only letters, digits, `_ - . /`.
  They are pasted into shell commands, so nothing wider is accepted; such a
  placeholder is an error and nothing runs.
- A `][` followed directly by a name-like run and `[` starts a placeholder; one
  that breaks the rules is an error, not text, so a typo shows. `][` followed
  by anything else (a space, as in `][ name ][` markers) is text.
- `\][...` is the placeholder as literal text; `\\][...` is one backslash and
  the filled value; in general each pair of backslashes is one backslash.
- The configuration's command must use exactly as many `PARAMn` as the
  placeholder gives parameters.
- `[custom_keywords]` entries win over other sections' entries of the same
  name in that file; a later file wins over an earlier one.
- `kml_version`, `template_name`, `ticket_id` (default `T-YYYYMMDD-HHMMSS-xxxx`)
  and `generation_date` are the engine's own; configuration entries for them
  are ignored. `error` and `debug` are reserved and always an error.
- Each distinct command (after parameters) runs once per template, however
  many times it is used.
- Commands run with `bash -c`, `set +e`, standard input closed, under
  `timeout`; exit 124 is reported as a timeout.
