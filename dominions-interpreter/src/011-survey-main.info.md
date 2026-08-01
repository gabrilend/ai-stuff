# 011-survey-main.lua

The entry point `./survey` runs. Takes its arguments the ordinary way and its
project directory from `DOMINIONS_INTERPRETER_DIR`.

It is a file rather than a string passed to `luajit -e` because arguments are
the point: `-e` treats the first thing after the option terminator as a script
name, so a command line built that way silently loses its first argument. This
was found by building it that way first.
