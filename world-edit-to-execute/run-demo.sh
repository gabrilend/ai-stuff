#!/bin/bash
# World Edit to Execute - Demo Menu
#
# Tech demos of what the engine does today, for showing people: pick a
# category, pick a demo, and it runs. One demo per run of this script.
#
# Every demo is one line of the registry below (DEMOS): an id, a category,
# a title, what the audience sees, and one line of bash that sets up the
# environment and runs it. The menu is read from the registry, so a demo
# added there is in the menu with its category's count.
#
# Usage:
#   ./run-demo.sh [DIR] [OPTIONS] [DEMO]
#
#   ./run-demo.sh                  the menu
#   ./run-demo.sh play-daow        one demo by its id (see -l)
#   ./run-demo.sh 2.3              one demo by category.number, as the menu shows it
#   ./run-demo.sh 3                (a bare number: the old phase demos, phase3)
#   ./run-demo.sh -l               every demo, by category
#   ./run-demo.sh -n DEMO          unattended: graphical demos quit after
#                                  DEMO_SECONDS (default 40), text demos skip prompts
#   ./run-demo.sh -c [DEMO...]     check demos: each runs unattended (under
#                                  xvfb-run when there's no display), a
#                                  screenshot taken, pass/fail listed
#   ./run-demo.sh -t               the validation tests
#   ./run-demo.sh -s               project statistics
#   ./run-demo.sh -h               this help
#
# Environment:
#   RAYLIB_PATH    raylib's src/ folder (raylib.h, libraylib.a); raylib 5.0's API
#   DEMO_CACHE     where the viewer is built and demo maps are made
#                  (default ~/.cache/world-edit-to-execute)
#   DEMO_SECONDS   how long an unattended (-n, -c) graphical demo runs
#   and every variable the scenes read (WC3_*, MODEL_GALLERY_*, SCENE_*),
#   which pass through to the demo.

# {{{ DIR and paths
if [[ -n "$1" && -d "$1" ]]; then
    DIR="$(cd "$1" && pwd)"
    shift
else
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

MAPS="${DIR}/assets"
DAOW="${MAPS}/DAoW-5.4b-PUBLIC-TEST.w3x"
DAOW_OLDEST="${MAPS}/Daow1.23.1B.w3x"
DAOW_NEWEST="${MAPS}/DaoW-(HvA)-7.5.w3x"
DAOW_EDIT="${MAPS}/Daow4.4.w3x"
# ATTENTION(local): raylib 5.0 is the API the renderer is written against
# (6.x removed GetMouseRay, which input.c uses). Point RAYLIB_PATH at a 5.0
# build if the owner's usual place holds another version.
export RAYLIB_PATH="${RAYLIB_PATH:-/home/ritz/programming/c/libs/raylib/src}"
CACHE="${DEMO_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/world-edit-to-execute}"
VIEWER_BIN="${CACHE}/scene_viewer"
THREADED_BIN="${CACHE}/threaded_demo"
DEMO_SECONDS="${DEMO_SECONDS:-40}"

NON_INTERACTIVE=false
NI=""          # "-n" in unattended runs, for the text demos that take it
# }}}

# {{{ Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# {{{ Helpers the demo lines use
# {{{ need
# need CMD WHY: stop the demo, saying why, when a program is missing
need() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}This demo needs '$1' (${2}), which isn't installed.${NC}" >&2
        return 1
    fi
}
# }}}

# {{{ lj
# lj ARGS...: LuaJIT from the project root. LuaJIT only: maps are read
# through StormLib (issue 114), whose binding needs LuaJIT's FFI.
lj() {
    need luajit "maps are read through StormLib, which needs LuaJIT's FFI" || return 1
    (cd "${DIR}" && luajit "$@")
}
# }}}

# {{{ build_c
# build_c OUT SOURCES...: compile the renderer's C files (src/render) with
# raylib and LuaJIT into OUT, only when OUT is missing or older than any of
# src/render's .c and .h files.
build_c() {
    local out="$1"
    shift
    local src="${DIR}/src/render"
    if [[ -x "${out}" ]] && [[ -z "$(find "${src}" -maxdepth 1 -name '*.[ch]' -newer "${out}" -print -quit)" ]]; then
        return 0
    fi
    need gcc "the renderer is C" || return 1
    if [[ ! -f "${RAYLIB_PATH}/raylib.h" ]]; then
        echo -e "${RED}raylib not found in ${RAYLIB_PATH} (set RAYLIB_PATH to raylib 5.0's src/ folder)${NC}" >&2
        return 1
    fi
    mkdir -p "$(dirname "${out}")"
    echo -e "${DIM}building $(basename "${out}") ...${NC}"
    local lj_cflags lj_libs
    lj_cflags=$(pkg-config --cflags luajit 2>/dev/null || echo "-I/usr/include/luajit-2.1")
    lj_libs=$(pkg-config --libs luajit 2>/dev/null || echo "-lluajit-5.1")
    if ! (cd "${src}" && gcc -pthread -Wall -O2 -o "${out}" "$@" \
            -I"${RAYLIB_PATH}" ${lj_cflags} \
            -L"${RAYLIB_PATH}" -lraylib ${lj_libs} \
            -lGL -lm -lpthread -ldl -lrt -lX11 > "${CACHE}/build.log" 2>&1); then
        echo -e "${RED}Compilation failed; see ${CACHE}/build.log${NC}" >&2
        tail -5 "${CACHE}/build.log" >&2
        return 1
    fi
}
# }}}

# {{{ viewer
# viewer SCENE [ARG]: the scene viewer (src/render/scene_viewer.c) running a
# scene script, as src/render/run-map, run-fort and run-editor do; built
# once into the cache. WC3_VIEWER lets the editor's Test button (F5) play
# the map with the same viewer.
viewer() {
    build_c "${VIEWER_BIN}" scene_viewer.c geometry.c landscape.c ui2d.c models.c fog.c \
        bridge.c slots.c terrain.c input.c ui.c || return 1
    WC3_VIEWER="${VIEWER_BIN}" "${VIEWER_BIN}" "${DIR}" "$@"
}
# }}}

# {{{ threaded
# threaded: the multi-threaded renderer (src/render/main.c, src/render/run):
# updater, workers, sync and draw threads, the profiler and the threading
# overlay.
# ATTENTION(local): main.c's inline Lua loads the map from the hardcoded
# /mnt/mtwo/... project root; elsewhere it shows its demo cubes only.
threaded() {
    build_c "${THREADED_BIN}" main.c threading.c slots.c bridge.c terrain.c input.c ui.c \
        profiler.c demo_threading.c geometry.c landscape.c ui2d.c models.c fog.c || return 1
    # it has no timer of its own: unattended runs stop it after SCENE_QUIT_AT
    if [[ -n "${SCENE_QUIT_AT}" ]]; then
        (cd "${DIR}/src/render" && timeout "${SCENE_QUIT_AT%.*}" "${THREADED_BIN}")
        [[ $? -eq 124 ]] && return 0
        return 1
    fi
    (cd "${DIR}/src/render" && "${THREADED_BIN}")
}
# }}}

# {{{ newmap
# newmap NAME [new_map.lua options]: a new map made from nothing (issue
# 911b) in the cache, remade each run; prints its path.
newmap() {
    local out="${CACHE}/maps/$1.w3x"
    shift
    mkdir -p "${CACHE}/maps"
    lj src/editor/new_map.lua "${out}" "$@" >&2 || return 1
    echo "${out}"
}
# }}}

# {{{ every
# every SECONDS ACTION...: a SCENE_ACTIONS script, one action every SECONDS
# of game time, starting at 1s ("1:a;7:b;13:c" for every 6 a b c).
every() {
    local step="$1" t=1 out=""
    shift
    for a in "$@"; do
        out="${out}${t}:${a};"
        t=$((t + step))
    done
    echo "${out%;}"
}
# }}}

# {{{ random_map
# random_map: one of the maps in assets/, a different one each run
random_map() {
    find "${MAPS}" -maxdepth 1 -name '*.w3[xm]' | shuf -n 1
}
# }}}
# }}}

# {{{ Places on DAoW 5.4b, for the camera
# the start locations of its twelve kingdoms (WC3 coordinates, x,y), read
# from the map's war3map.w3i
KINGDOMS=(
    "19968,18304"   # 0  Lordaeron (you)
    "-25088,3904"   # 1  Night Elves
    "6592,-17024"   # 2  Blood Elves
    "21824,19776"   # 3  The Scourge
    "17664,-2304"   # 4  Khaz Modan
    "-12480,-10432" # 5  Kul Tiras & Theramore
    "23936,-17664"  # 6  Trolls
    "11968,-28928"  # 7  Illidari
    "-13184,-4160"  # 8  Darkspear Trolls & Tauren
    "11584,28224"   # 9  The Forsaken
    "17600,-9536"   # 10 Stormwind
    "-13248,3072"   # 11 The Horde
)
# }}}

# {{{ DEMOS
# One demo a line:   id | category | title | what the audience sees | command
# The command is the rest of the line after the fourth "|" (so it may use
# pipes), run by bash from the project root with the helpers above. The
# menu lists categories in the order they first appear here.
#
# ATTENTION(local): the art. Without the owner's Warcraft III install
# (wc3-installs/frozen-throne, or WC3_INSTALL) and its patch layers
# (wc3-installs/patch-layers, WC3_LAYERS; scripts/fetch-patch-programs.sh,
# src/cli/build-patch-layer.lua), the demos draw the maps' own imported
# models and textures plus geometry stand-ins. With the install linked the
# stock models, ground tiles and unit stats come from it (src/assets/init.lua,
# src/gamedata/). Check the "[models] install:" and "[stats] stock tables:"
# lines each map demo prints.
DEMOS=$(cat <<'EOF'
play-daow        | Play a Map        | Dark Ages of Warcraft            | A 481x481 twelve-kingdom map run from its .w3x like an emulator runs a ROM: its JASS script, eleven computer players, heroes, economy and fog. You are Lordaeron. | viewer src/demo/wc3map/main.lua "$DAOW"
play-scourge     | Play a Map        | ... as the Scourge               | The same map from another seat: play the Scourge while the other kingdoms (Lordaeron included) are run by their AI profiles. | WC3_PLAYER=3 viewer src/demo/wc3map/main.lua "$DAOW"
play-horde       | Play a Map        | ... as the Horde                 | The same map as the Horde, the orcs' capital in the west. | WC3_PLAYER=11 viewer src/demo/wc3map/main.lua "$DAOW"
play-oldest      | Play a Map        | The oldest version (1.23.1B)     | The map's earliest release in assets/, years older, read and played by the same engine. | viewer src/demo/wc3map/main.lua "$DAOW_OLDEST"
play-newest      | Play a Map        | The newest version (HvA 7.5)     | The map's latest release (Humans vs Alliance) in assets/. | viewer src/demo/wc3map/main.lua "$DAOW_NEWEST"
play-random      | Play a Map        | A random map from assets/        | Any of the map versions in assets/, a different one each run. | viewer src/demo/wc3map/main.lua "$(random_map)"
play-sandbox     | Play a Map        | Sandbox: no computer players     | DAoW with the computer players left idle: build, train and explore in peace. | WC3_AI=none viewer src/demo/wc3map/main.lua "$DAOW"
play-newmap      | Play a Map        | A map made from nothing          | The editor's "New Map" writes a four-player melee map from scratch (w3i, w3e, wpm, script, MPQ) and the game plays it at once. | viewer src/demo/wc3map/main.lua "$(newmap skirmish --name 'Convention Skirmish' --size 96 --tileset A --players human,orc:computer,undead:computer,nightelf:computer)"
tour-kingdoms    | Attract Mode      | Tour of the twelve kingdoms      | Hands-free: the camera visits each kingdom's capital in turn while the AI players build and fight. Arrows pan, Esc quits. | SCENE_ACTIONS="$(every 7 $(printf 'camera:%s,2000 ' "${KINGDOMS[@]}"))" viewer src/demo/wc3map/main.lua "$DAOW"
tour-heroes      | Attract Mode      | Heroes and spell art             | Hands-free: your hero is picked, raised to level 10 learning its skills, then the spell art's lightning (chain, drain, forked, finger of death, healing wave...) arcs across its capital. | SCENE_CAMERA=19968,18304,1100 SCENE_ACTIONS="$(every 2 select:hero herolevel:10 camera:19968,18104,1400 lightning:CLPB:19468,18304,20468,18304 lightning:DRAL:19968,17804,19968,18804 lightning:FORK:19468,17804,20468,18804 lightning:AFOD:19468,18804,20468,17804 lightning:HWPB:19568,18604,20368,18004 lightning:CHIM:19568,18004,20368,18604 lightning:SPLK:19468,18304,20468,18304 lightning:MFPB:19968,17804,19968,18804 lightning:LEAS:19468,17804,20468,18804 select:hero lightning:CLPB)" viewer src/demo/wc3map/main.lua "$DAOW"
tour-battle      | Attract Mode      | To war                           | Hands-free: your army is gathered and attack-moves on the nearest enemy; the fights run on WC3's combat, pathing and building rules. | SCENE_ACTIONS="$(every 4 select:army order:attack_nearest select:army order:attack_nearest select:army order:attack_nearest select:army order:attack_nearest)" viewer src/demo/wc3map/main.lua "$DAOW"
tour-interface   | Attract Mode      | The WC3 interface                | Hands-free: a building's command card, a worker's, a hero's, then the map script's quests (F9), the menu (F10), allies (F11) and the message log (F12). | SCENE_ACTIONS="$(every 4 select:building select:worker select:hero key:F9 key:ESCAPE key:F11 key:ESCAPE key:F12 key:ESCAPE key:F10 key:ESCAPE select:army)" viewer src/demo/wc3map/main.lua "$DAOW"
tour-flyover     | Attract Mode      | High flyover                     | Hands-free: the camera pulls far out over the continent and sweeps across it, fog of war lifted. | WC3_FOG=0 SCENE_ACTIONS="$(every 6 camera:0,0,6000 camera:-20000,20000,6000 camera:20000,20000,6000 camera:20000,-20000,6000 camera:-20000,-20000,6000 camera:0,0,6000 camera:19968,18304,1600)" viewer src/demo/wc3map/main.lua "$DAOW"
render-designs   | Rendering         | Community look: geometry only    | The whole map drawn with the engine's own procedural geometry designs instead of any Blizzard model: the "community visuals" idea. | WC3_MODELS=0 viewer src/demo/wc3map/main.lua "$DAOW"
render-flat      | Rendering         | Plain colours                    | Ground in its tiles' plain colours and units as designs: the map's data drawn as directly as it gets. | WC3_TILES=0 WC3_MODELS=0 viewer src/demo/wc3map/main.lua "$DAOW"
render-standin   | Rendering         | Stand-in ground textures         | The ground textured with generated stand-ins for every tileset, even where the install's textures exist. | WC3_TILES=standin viewer src/demo/wc3map/main.lua "$DAOW"
render-nofog     | Rendering         | No fog of war                    | The map with the fog of war off: every kingdom visible, every AI's moves on show. | WC3_FOG=0 viewer src/demo/wc3map/main.lua "$DAOW"
render-still     | Rendering         | Still life                       | Models in their rest pose, no animation: compare with the animated default. | WC3_ANIMATE=0 viewer src/demo/wc3map/main.lua "$DAOW"
render-unscripted| Rendering         | The map without its script       | The units read from the script's text instead of running it: the map as the editor saved it, before its triggers run. | WC3_SCRIPT=0 WC3_AI=none viewer src/demo/wc3map/main.lua "$DAOW"
models-gallery   | Models & Animation| Model gallery                    | Every model the map carries, decoded from MDX with its textures, in rows, all playing Stand, Walk, Attack, Spell, Death ... in turn. | viewer src/demo/models/main.lua "$DAOW"
models-walk      | Models & Animation| Everyone walks                   | The gallery with every model on its Walk sequence. | MODEL_GALLERY_ANIM=walk viewer src/demo/models/main.lua "$DAOW"
models-attack    | Models & Animation| Everyone attacks                 | The gallery with every model on its Attack sequence. | MODEL_GALLERY_ANIM=attack viewer src/demo/models/main.lua "$DAOW"
models-death     | Models & Animation| Everyone dies                    | The gallery with every model on its Death sequence. | MODEL_GALLERY_ANIM=death viewer src/demo/models/main.lua "$DAOW"
models-textured  | Models & Animation| Fully textured only              | Only the models whose every texture was found, closer together. | MODEL_GALLERY_TEXTURED=1 MODEL_GALLERY_SPACING=300 viewer src/demo/models/main.lua "$DAOW"
models-newest    | Models & Animation| Gallery of the newest version    | The models imported into the newest version (HvA 7.5). | viewer src/demo/models/main.lua "$DAOW_NEWEST"
models-glb       | Models & Animation| glTF models beside MDX           | glTF (.glb) models (e.g. the asset forge's, W05) set out beside the map's MDX models, fitted to a unit's height. Set DEMO_GLB to the files. | MODEL_GALLERY_GLB="${DEMO_GLB:?set DEMO_GLB to one or more .glb files}" MODEL_GALLERY_GLB_HEIGHT=200 viewer src/demo/models/main.lua "$DAOW"
editor-daow      | World Editor      | Edit Dark Ages of Warcraft       | The map editor on DAoW 4.4: terrain brushes, doodads, units, regions, cameras, the object, trigger, AI, sound and import editors. Test (F5) plays your edit. | EDITOR_OUT="$CACHE/maps/daow-edited.w3x" viewer src/editor/main.lua "$DAOW_EDIT"
editor-newmap    | World Editor      | New map, then edit it            | A blank Northrend map made from nothing, opened in the editor to build on live. | viewer src/editor/main.lua "$(newmap blank --name 'Live Build' --size 64 --tileset N --players human,undead:computer)"
editor-sculpt    | World Editor      | Terraforming                     | The editor raises hills, cuts cliffs, floods water and paints ground by itself on a new map, then hands you the brushes. | SCENE_ACTIONS="1:camera:0,0,2600;2:tool:raise;2.5:stroke:-600,0;3:stroke:-500,100;3.5:stroke:-400,0;4:tool:cliff_up;4.5:stroke:500,300;5:stroke:600,300;6:tool:water;6.5:stroke:0,-600;7:stroke:100,-600;8:tool:paint;8.5:stroke:-200,400;9:stroke:0,400;10:tool:smooth;10.5:stroke:-500,50;11:tool:select" viewer src/editor/main.lua "$(newmap sculpt --name 'Terraforming' --size 48 --tileset L --players human,orc:computer)"
editor-triggers  | World Editor      | The trigger editor               | DAoW's own triggers opened as blocks, written back as JASS; its Lua view edits the same triggers as code. | SCENE_ACTIONS="1:press:Triggers;6:press:Lua (all)" viewer src/editor/main.lua "$DAOW_EDIT"
editor-ai        | World Editor      | The AI editor                    | The computer players' AI profiles, tab by tab as the World Editor's AI Editor shows them. | SCENE_ACTIONS="1:press:AI" viewer src/editor/main.lua "$DAOW_EDIT"
editor-sounds    | World Editor      | The sound editor                 | The map's sounds and music, named from the script, previewed and edited. | SCENE_ACTIONS="1:press:Sounds" viewer src/editor/main.lua "$DAOW_EDIT"
editor-imports   | World Editor      | The import manager               | Every file the map imports, named from what refers to it, checked, renamed, exported. | SCENE_ACTIONS="1:press:Files" viewer src/editor/main.lua "$DAOW_EDIT"
editor-roundtrip | World Editor      | Make, test, edit, play           | The Phase 9 pipeline: a new melee map, the editor's integration test on it (edit, save, reopen, play), then the editor. | bash issues/completed/demos/run_phase9.sh "$DIR"
engine-threads   | Engine Internals  | Threaded renderer                | The staged renderer: updater, worker, sync and draw threads. F5 shows the threading overlay; T/H/S inject tasks, 1-9 set a load; F3/F4 the profiler. | threaded
engine-fort      | Engine Internals  | Fort: geometry painting          | A fort painted stone by stone from the geometry kit, bowmen manning its walls by WC3's movement and range rules. R cycles range rings. | FORT_MAP=none viewer src/demo/fort/main.lua
engine-fort-map  | Engine Internals  | Fort on a real map's ground      | The same fort laid on DAoW's terrain. | FORT_MAP="$DAOW" viewer src/demo/fort/main.lua
engine-ecs       | Engine Internals  | ECS, pathfinding and collision   | The phase 4 runtime drawn live (LOVE 2D): entities path round walls with A*, steer and collide. | need love "the phase 4 visual demo runs in LOVE 2D" && love issues/completed/demos/phase4_love
hood-tests       | Under the Hood    | Validation tests                 | The phase 1-4 test suites, streamed with pass/fail. | run_tests
hood-mapdump     | Under the Hood    | Map dump                         | A map's info, strings, terrain and files, read straight from the MPQ. | MAPDUMP_DIR="$DIR" lj src/cli/mapdump.lua "$DAOW" -c all | ${PAGER:-less}
hood-mpq         | Under the Hood    | Inside the MPQ                   | Every file in the map's archive with sizes and compression, through StormLib. | lj src/cli/mpq-extract.lua --dir "$DIR" list "$DAOW" | ${PAGER:-less}
hood-stats       | Under the Hood    | Project statistics               | Issues, phases, test maps and the source tree. | show_statistics
phase0           | Under the Hood    | Phase 0: tooling                 | The issue splitter's TUI (vim keys, checkbox selection). | "$DIR/src/cli/issue-splitter.sh" -I
phase1           | Under the Hood    | Phase 1: file formats            | MPQ, w3i, wts, w3e parsed and shown. | lj issues/completed/demos/phase1_demo.lua $NI
phase2           | Under the Hood    | Phase 2: game objects            | Doodads, units, regions, cameras and sounds as game objects. | lj issues/completed/demos/phase2_demo.lua $NI
phase3           | Under the Hood    | Phase 3: triggers and JASS       | The map's JASS lexed, parsed, transpiled to Lua and run. | bash issues/completed/demos/run_phase3.sh $NI
phase4           | Under the Hood    | Phase 4: runtime                 | Game loop, timers, ECS, pathfinding, resources, players. | bash issues/completed/demos/run_phase4.sh $NI
phase5           | Under the Hood    | Phase 5: threading tests         | The threading architecture's C tests. | bash issues/completed/demos/run_phase5.sh "$DIR" -t
EOF
)
# ATTENTION(local): demos the codebase isn't ready for yet, to add here
# once they are:
#   - Phase W (issues W01-W07): a WC3 map built into the WoW 3.3.5a client,
#     WoW models (M2) with WC3 unit behaviour, the real/open client
#     comparison. Needs the client's archives read and extracted (W01) and
#     a model resolver for M2 (W03) first.
#   - Imported/install models drawn in the game view (src/assets/gpu.lua,
#     src/parsers/mdx.lua): with the install linked, check that
#     play-daow's "[models] placed with models" count covers most units.
# }}}

# {{{ Registry queries
# {{{ registry
# the registry without comments or blank lines, fields trimmed:
# id<TAB>category<TAB>title<TAB>blurb<TAB>command
registry() {
    echo "${DEMOS}" | awk -F'|' '
        /^[[:space:]]*(#|$)/ { next }
        {
            cmd = $0
            for (i = 1; i <= 4; i++) sub(/^[^|]*\|/, "", cmd)
            for (i = 1; i <= 4; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
            gsub(/^[ \t]+|[ \t]+$/, "", cmd)
            printf "%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, cmd
        }'
}
# }}}

# {{{ categories
# each category once, in order, with its number of demos: count<TAB>name
categories() {
    registry | awk -F'\t' '
        !($2 in n) { order[++k] = $2 }
        { n[$2]++ }
        END { for (i = 1; i <= k; i++) printf "%d\t%s\n", n[order[i]], order[i] }'
}
# }}}

# {{{ demos_in
# the demos of the Nth category, in order (registry lines)
demos_in() {
    local cat
    cat=$(categories | sed -n "${1}p" | cut -f2)
    [[ -z "${cat}" ]] && return 1
    registry | awk -F'\t' -v c="${cat}" '$2 == c'
}
# }}}

# {{{ find_demo
# the registry line of a demo named by id, by "category.number", or (old
# phase demos) by a bare phase number
find_demo() {
    local want="$1"
    if [[ "${want}" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        demos_in "${BASH_REMATCH[1]}" | sed -n "${BASH_REMATCH[2]}p"
        return
    fi
    [[ "${want}" =~ ^[0-9]$ ]] && want="phase${want}"
    registry | awk -F'\t' -v id="${want}" '$1 == id'
}
# }}}
# }}}

# {{{ run_demo
# run one demo (a registry line): its title and what it shows, then its
# command, from the project root
run_demo() {
    local id cat title blurb cmd
    IFS=$'\t' read -r id cat title blurb cmd <<< "$1"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${title}${NC}  ${DIM}(${cat} / ${id})${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo "${blurb}" | fold -s -w 76
    echo ""
    echo -e "${DIM}\$ ${cmd}${NC}"
    echo ""
    cd "${DIR}" || return 1
    eval "${cmd}"
}
# }}}

# {{{ Menu
# {{{ banner
banner() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}                         WORLD EDIT TO EXECUTE${NC}"
    echo -e "${CYAN}       Warcraft III maps run like ROMs: script, AI, models, editor${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}
# }}}

# {{{ menu_categories
# the categories with their counts; prints the chosen category's number,
# "q" to quit
menu_categories() {
    local total n=0 count name
    total=$(registry | wc -l)
    banner >&2
    echo -e "${BOLD}Choose a category${NC} ${DIM}(${total} demos)${NC}" >&2
    echo "" >&2
    while IFS=$'\t' read -r count name; do
        n=$((n + 1))
        printf "  ${BOLD}[%d]${NC} %-28s ${DIM}%2d demo%s${NC}\n" "${n}" "${name}" "${count}" \
            "$([[ ${count} -eq 1 ]] || echo s)" >&2
    done < <(categories)
    echo "" >&2
    echo -e "  ${BOLD}[q]${NC} Quit" >&2
    echo "" >&2
    echo -n "Category: " >&2
    local choice
    read -r choice
    echo "${choice}"
}
# }}}

# {{{ menu_demos
# the demos of category N; prints the chosen registry line, "b" for back,
# "q" to quit
menu_demos() {
    local lines n=0 id cat title blurb cmd
    lines=$(demos_in "$1") || return 1
    cat=$(echo "${lines}" | head -1 | cut -f2)
    banner >&2
    echo -e "${BOLD}${cat}${NC}" >&2
    echo "" >&2
    while IFS=$'\t' read -r id cat title blurb cmd; do
        n=$((n + 1))
        printf "  ${BOLD}[%d]${NC} %-34s ${DIM}%s${NC}\n" "${n}" "${title}" "${id}" >&2
        echo -e "${DIM}$(echo "${blurb}" | fold -s -w 68 | sed 's/^/        /')${NC}" >&2
    done <<< "${lines}"
    echo "" >&2
    echo -e "  ${BOLD}[b]${NC} Back   ${BOLD}[q]${NC} Quit" >&2
    echo "" >&2
    echo -n "Demo: " >&2
    local choice
    read -r choice
    case "${choice}" in
        [bBqQ]) echo "${choice}" ;;
        *[!0-9]*|"") echo "?" ;;
        *) echo "${lines}" | sed -n "${choice}p" | grep . || echo "?" ;;
    esac
}
# }}}

# {{{ menu
# categories, then demos, until one is chosen; runs it and returns
menu() {
    local cat pick
    while true; do
        cat=$(menu_categories)
        case "${cat}" in
            [qQ]) return 0 ;;
            *[!0-9]*|"") continue ;;
        esac
        demos_in "${cat}" > /dev/null || continue
        while true; do
            pick=$(menu_demos "${cat}")
            case "${pick}" in
                [qQ]) return 0 ;;
                [bB]) break ;;
                "?") continue ;;
                *) run_demo "${pick}"; return $? ;;
            esac
        done
    done
}
# }}}
# }}}

# {{{ list_demos
list_demos() {
    local n=0 count name
    while IFS=$'\t' read -r count name; do
        n=$((n + 1))
        echo -e "${BOLD}${n}. ${name}${NC} ${DIM}(${count})${NC}"
        demos_in "${n}" | awk -F'\t' -v c="${n}" '{ printf "   %d.%-3d %-18s %s\n", c, NR, $1, $3 }'
    done < <(categories)
}
# }}}

# {{{ check_demos
# run demos unattended (all graphical ones when none are named), each
# quitting after DEMO_SECONDS with screenshots at a third and two thirds of
# the way, under xvfb-run when there's no display; lists pass/fail and where
# the screenshots are
check_demos() {
    local ids=("$@") id line out status shots pass=0 fail=0
    if [[ ${#ids[@]} -eq 0 ]]; then
        mapfile -t ids < <(registry | awk -F'\t' '$5 ~ /(^| )(viewer|threaded)( |$)/ && $1 != "models-glb" { print $1 }')
    fi
    local wrap=()
    if [[ -z "${DISPLAY}" ]]; then
        need xvfb-run "no display: checks run in a virtual one" || return 1
        wrap=(xvfb-run -a -s "-screen 0 1280x720x24")
    fi
    for id in "${ids[@]}"; do
        line=$(find_demo "${id}")
        if [[ -z "${line}" ]]; then
            echo -e "  ${YELLOW}?${NC} ${id}: no such demo"
            continue
        fi
        out="${CACHE}/check/${id}"
        rm -rf "${out}"
        mkdir -p "${out}"
        printf "  %-18s " "${id}"
        SCENE_SHOT_DIR="${out}" SCENE_SHOTS="$((DEMO_SECONDS / 3)),$((DEMO_SECONDS * 2 / 3))" \
            SCENE_QUIT_AT="${DEMO_SECONDS}" DIR="${DIR}" \
            timeout $((DEMO_SECONDS * 10 + 120)) "${wrap[@]}" "$0" "${DIR}" -n "${id}" > "${out}/log" 2>&1 < /dev/null
        status=$?
        shots=$(find "${out}" -name '*.png' | wc -l)
        if [[ ${status} -eq 0 && ${shots} -gt 0 ]] || [[ ${status} -eq 0 && "${line}" != *viewer* ]]; then
            pass=$((pass + 1))
            echo -e "${GREEN}ok${NC}   ${DIM}${shots} shot(s) in ${out}${NC}"
        else
            fail=$((fail + 1))
            echo -e "${RED}FAIL${NC} ${DIM}exit ${status}, ${shots} shot(s); log: ${out}/log${NC}"
        fi
    done
    echo ""
    echo -e "${GREEN}${pass} ok${NC}, $([[ ${fail} -gt 0 ]] && echo -e "${RED}${fail} failed${NC}" || echo "0 failed")"
    [[ ${fail} -eq 0 ]]
}
# }}}

# {{{ run_test_file
# Run a test file and stream output with colorization
# Writes pass/fail counts to temp file
run_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .lua)

    if [[ ! -f "$test_file" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${test_name} (not found)"
        return
    fi

    echo -e "  ${CYAN}▶${NC} ${test_name}"

    need luajit "maps are read through StormLib, which needs LuaJIT's FFI" || return 1

    # Run and stream output, colorizing PASS/FAIL
    # Handle both "PASS" and "PASS: description" formats
    luajit "$test_file" 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ PASS:\ (.+) ]]; then
            # "PASS: description" format
            echo -e "    ${GREEN}✓${NC} ${BASH_REMATCH[1]}"
            printf "P" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ \.\.\.\ *PASS$ ]]; then
            # "Testing name... PASS" format
            local desc="${line%...*}"
            desc="${desc#Testing }"
            echo -e "    ${GREEN}✓${NC} ${desc}"
            printf "P" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ FAIL:\ (.+) ]]; then
            # "FAIL: description" format
            echo -e "    ${RED}✗${NC} ${BASH_REMATCH[1]}"
            printf "F" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ \.\.\.\ *FAIL$ ]]; then
            # "Testing name... FAIL" format (unlikely)
            local desc="${line%...*}"
            desc="${desc#Testing }"
            echo -e "    ${RED}✗${NC} ${desc}"
            printf "F" >> "$TEMP_COUNTS"
        elif [[ "$line" == "==="* ]]; then
            # Section header - show abbreviated
            local section="${line//=/}"
            section="${section## }"
            section="${section%% }"
            if [[ -n "$section" ]]; then
                echo -e "    ${BLUE}─${NC} ${section}"
            fi
        fi
    done
}
# }}}

# {{{ run_tests
run_tests() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}ALL PHASE VALIDATION TESTS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"

    # Create temp file for counting pass/fail
    TEMP_COUNTS=$(mktemp)
    export TEMP_COUNTS
    trap "rm -f $TEMP_COUNTS" EXIT

    # Phase 1: File Parsing (MPQ, W3I, WTS, W3E)
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 1: File Parsing ─────────────────────────────────────────────────┐${NC}"
    for test in test_mpq test_w3i test_wts test_w3e test_data; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 2: Data Model (Doodads, Units, Regions, Registry)
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 2: Data Model ───────────────────────────────────────────────────┐${NC}"
    for test in test_doo test_unitsdoo test_w3r test_gameobjects test_registry; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 3: Triggers and JASS
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 3: Triggers and JASS ────────────────────────────────────────────┐${NC}"
    for test in test_jass_lexer test_parser test_transpiler test_triggers; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 4: Runtime
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 4: Runtime ──────────────────────────────────────────────────────┐${NC}"
    for test in test_phase4_core test_phase4_player test_gameloop test_resources; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Count results from temp file (counts P and F characters)
    local total_passed=0
    local total_failed=0
    if [[ -f "$TEMP_COUNTS" ]]; then
        local counts
        counts=$(cat "$TEMP_COUNTS")
        # Count P and F characters
        total_passed=$(echo -n "$counts" | tr -cd 'P' | wc -c)
        total_failed=$(echo -n "$counts" | tr -cd 'F' | wc -c)
    fi

    # Summary
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    if [[ $total_failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All tests passed!${NC} ${GREEN}${total_passed}${NC} tests"
    else
        echo -e "Results: ${GREEN}${total_passed} passed${NC}, ${RED}${total_failed} failed${NC}"
    fi
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    rm -f "$TEMP_COUNTS"
    [[ $total_failed -eq 0 ]]
}
# }}}

# {{{ show_statistics
show_statistics() {
    echo -e "${BOLD}Project Vision:${NC}"
    echo "  A WC3-compatible game engine that reads Warcraft 3 map files (.w3x/.w3m)"
    echo "  like an emulator reads ROMs. Community-supplied visuals rather than"
    echo "  recreating original aesthetics."
    echo ""

    echo -e "${BOLD}Architecture:${NC}"
    echo "  src/mpq/        MPQ archives (StormLib)          src/parsers/   w3i w3e doo mdx blp ..."
    echo "  src/jass/       JASS lexer, parser, VM           src/runtime/   loop, ECS, pathing"
    echo "  src/demo/wc3map the game: combat, heroes, AI ..  src/ui/wc3/    WC3's interface"
    echo "  src/render/     raylib renderer (C)              src/editor/    the World Editor"
    echo "  src/assets/     models, textures, animation      src/ai/        computer players"
    echo ""

    local total_issues completed_issues test_maps lua_lines c_lines
    total_issues=$(find "${DIR}/issues" -maxdepth 1 -name "*.md" | wc -l)
    completed_issues=$(find "${DIR}/issues/completed" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    test_maps=$(find "${DIR}/assets" -name "*.w3[xm]" 2>/dev/null | wc -l)
    lua_lines=$(find "${DIR}/src" -name '*.lua' -exec cat {} + 2>/dev/null | wc -l)
    c_lines=$(find "${DIR}/src" -name '*.[ch]' -exec cat {} + 2>/dev/null | wc -l)

    echo -e "${BOLD}Metrics:${NC}"
    echo "  Open issues:      $total_issues"
    echo "  Completed:        $completed_issues"
    echo "  Test maps:        $test_maps"
    echo "  Lua lines:        $lua_lines"
    echo "  C lines:          $c_lines"
    echo "  Demos:            $(registry | wc -l)"
    echo ""
    echo "  Per-phase status: docs/roadmap.md, issues/progress.md"
}
# }}}

# {{{ usage
usage() {
    sed -n '2,/^# {{{ DIR/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}
# }}}

# {{{ main
main() {
    local check=false args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -I|--interactive) ;;
            -n|--non-interactive) NON_INTERACTIVE=true; NI="-n" ;;
            -c|--check) check=true ;;
            -l|--list) list_demos; exit 0 ;;
            -t|--tests) run_tests; exit $? ;;
            -s|--stats) show_statistics; exit 0 ;;
            -h|--help) usage; exit 0 ;;
            -*) echo "Unknown option: $1 (-h for help)"; exit 1 ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    if [[ "${check}" == "true" ]]; then
        check_demos "${args[@]}"
        exit $?
    fi

    # unattended: graphical demos quit on their own
    if [[ "${NON_INTERACTIVE}" == "true" ]]; then
        export SCENE_QUIT_AT="${SCENE_QUIT_AT:-${DEMO_SECONDS}}"
    fi

    if [[ ${#args[@]} -gt 0 ]]; then
        local line
        line=$(find_demo "${args[0]}")
        if [[ -z "${line}" ]]; then
            echo -e "${RED}No demo '${args[0]}'.${NC} ./run-demo.sh -l lists them."
            exit 1
        fi
        run_demo "${line}"
        exit $?
    fi

    if [[ "${NON_INTERACTIVE}" == "true" ]]; then
        echo "Non-interactive mode needs a demo: $0 -n DEMO (-l lists them)"
        exit 1
    fi
    menu
}
# }}}

main "$@"
