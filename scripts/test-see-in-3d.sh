#!/bin/bash
# test-see-in-3d.sh - proves see-in-3d refuses bad scenes properly and draws
# good ones faithfully.
#
# In general terms: this writes small scene files in RAM and checks that a
# scene with several mistakes is refused with every mistake listed at once,
# each with the nearest legal word; that the same scene always gives the same
# bytes, whether its views are drawn by one worker or four; that the PNG it
# writes decodes -- by a decoder written here and by ImageMagick -- to exactly
# the pixels that were drawn; that a shape to the camera's right lands on the
# right of the picture and one seen from above lands in the middle; and that
# the .obj model holds every triangle. Exercises issue A08.

DIR="${DIR:-/home/ritz/programming/ai-stuff/scripts}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/see-in-3d"
WORK="/dev/shm/ai-stuff-scripts/see-in-3d-test"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    local label="$1" ok="$2"
    if [ "$ok" = "yes" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ contains
function contains() {
    case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac
}
# }}}

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$WORK/bad.lua" <<'EOF'
scene{ what = "mistakes, four of them" }
box { size = {1, 1, 1}, colour = "#ff0000" }
cube { size = {1, 1, 1} }
sphere { at = {0, 1, 0} }
cylinder { radius = 1, height = 2, color = "red", glow = "yes" }
EOF
cat > "$WORK/marks.lua" <<'EOF'
scene{ what = "a red box in the middle and a blue ball to its right" }
box    { name = "middle", at = {0, 0.5, 0}, size = {1, 1, 1}, color = "#dd2222" }
sphere { name = "right ball", at = {1.6, 0.5, 0}, radius = 0.4, color = "#2244dd" }
EOF

echo "the wall:"
output=$("$TOOL" render "$WORK/bad.lua" 2>&1)
check "a bad scene is refused, all problems at once" "$(contains "$output" "refused (5 problems)")"
check "glow must be true or false" "$(contains "$output" "glow must be true or false")"
check "a misspelt field is given the nearest legal word" "$(contains "$output" 'no field "colour" (nearest: color)')"
check "an unknown shape is given the nearest legal word" "$(contains "$output" '"cube" is not a paintbrush word (nearest: cone)')"
check "a missing required field is named" "$(contains "$output" "needs radius")"
check "a malformed colour is named, with the form it needs" "$(contains "$output" 'color must be "#rrggbb"')"
check "nothing is drawn for a refused scene" "$([ -e "$WORK/bad.png" ] && echo no || echo yes)"

echo "drawing:"
# A project of the test's own, so a test render is never kept in a real one.
PROJECT="$WORK/project"
mkdir -p "$PROJECT/llm-transcripts"
kept=$("$TOOL" render "$WORK/marks.lua" --project="$PROJECT")
first=$(md5sum < "$WORK/marks.png")
"$TOOL" render "$WORK/marks.lua" --workers=1 --no-keep > /dev/null
check "the same scene gives the same bytes, with one worker or four" "$(same=$(md5sum < "$WORK/marks.png"); [ "$first" = "$same" ] && echo yes || echo no)"

echo "keeping:"
folder=$(ls -d "$PROJECT"/mind/imagination-portraits/*-marks-views 2>/dev/null | head -1)
check "a render is kept in the project's mind/imagination-portraits/" "$([ -n "$folder" ] && [ -f "$folder/views.jpg" ] && [ -f "$folder/scene.lua" ] && echo yes || echo no)"
check "what made it is written beside it" "$(grep -q '^Made by scripts/see-in-3d views' "$folder/visual.info" 2>/dev/null && echo yes || echo no)"
check "it says where it kept the picture, for the conversation to show" "$(contains "$kept" "see-in-3d: kept $folder/views.jpg | ")"
check "--no-keep keeps nothing" "$([ "$(ls -d "$PROJECT"/mind/imagination-portraits/* | wc -l)" = 1 ] && echo yes || echo no)"
output=$(cd "$WORK" && "$TOOL" render "$WORK/marks.lua" 2>&1)
check "with no project to keep it in, the render says so and how to name one" "$(contains "$output" "--project=DIR")"

decoded=$(luajit -e "
    -- an independent PNG reader for stored deflate blocks: chunks, the zlib
    -- header, each stored block's length, filter bytes stripped
    local data = io.open('$WORK/marks-front.png', 'rb'):read('*a')
    local function be32(s, i) return ((s:byte(i) * 256 + s:byte(i + 1)) * 256 + s:byte(i + 2)) * 256 + s:byte(i + 3) end
    local pos, width, height, idat = 9, 0, 0, {}
    while pos <= #data do
        local length, kind = be32(data, pos), data:sub(pos + 4, pos + 7)
        local body = data:sub(pos + 8, pos + 7 + length)
        if kind == 'IHDR' then width, height = be32(body, 1), be32(body, 5) end
        if kind == 'IDAT' then idat[#idat + 1] = body end
        pos = pos + 12 + length
    end
    local z, raw, p = table.concat(idat), {}, 3
    repeat
        local last = z:byte(p) % 2
        local len = z:byte(p + 1) + z:byte(p + 2) * 256
        raw[#raw + 1] = z:sub(p + 5, p + 4 + len)
        p = p + 5 + len
    until last == 1
    raw = table.concat(raw)
    local rows = {}
    for y = 0, height - 1 do rows[#rows + 1] = raw:sub(y * (width * 3 + 1) + 2, (y + 1) * (width * 3 + 1)) end
    local pixels = table.concat(rows)
    -- the same view drawn directly, before any encoding
    local P = dofile('$DIR/libs/see-in-3d-paintbrush.lua')
    local R = dofile('$DIR/libs/see-in-3d-render.lua')
    local direct = R.render(P.compile(P.read('$WORK/marks.lua')), R.views[1], 480)
    io.write(pixels == direct and 'same' or 'different')")
check "the PNG decodes to exactly the pixels drawn (decoder written here)" "$(contains "$decoded" same)"
check "ImageMagick reads the PNG too, at the right size" \
    "$(identify "$WORK/marks.png" | grep -q 'PNG 960x960' && echo yes || echo no)"

where=$(luajit -e "
    local P = dofile('$DIR/libs/see-in-3d-paintbrush.lua')
    local R = dofile('$DIR/libs/see-in-3d-render.lua')
    local model = P.compile(P.read('$WORK/marks.lua'))
    -- the mean column of blue pixels in a view, as a fraction of its width
    local function blue_column(view)
        local rgb, sum, count = R.render(model, R.views[view], 200), 0, 0
        for i = 0, 200 * 200 - 1 do
            local r, g, b = rgb:byte(i * 3 + 1, i * 3 + 3)
            if b > 120 and r < 100 then sum = sum + i % 200; count = count + 1 end
        end
        return count > 0 and sum / count / 200 or -1
    end
    local function centre_is_red(view)
        local rgb = R.render(model, R.views[view], 200)
        local r, g, b = rgb:byte((100 * 200 + 70) * 3 + 1, (100 * 200 + 70) * 3 + 3)
        return r > 120 and g < 90 and b < 90
    end
    io.write(string.format('%.2f %.2f %s', blue_column(1), blue_column(2), tostring(centre_is_red(3))))")
front_blue=$(echo "$where" | cut -d' ' -f1)
right_blue=$(echo "$where" | cut -d' ' -f2)
top_red=$(echo "$where" | cut -d' ' -f3)
check "seen from the front, the ball to the right is on the right ($front_blue of the width)" \
    "$(luajit -e "io.write(($front_blue > 0.6) and 'yes' or 'no')")"
check "seen from the right, the ball is near the middle ($right_blue of the width)" \
    "$(luajit -e "io.write(($right_blue > 0.35 and $right_blue < 0.65) and 'yes' or 'no')")"
check "seen from above, the red box is under the camera's left of centre" "$([ "$top_red" = true ] && echo yes || echo no)"
check "the .obj model holds every triangle (12 for the box + the ball's)" \
    "$(faces=$(grep -c '^f ' "$WORK/marks.obj"); triangles=$(luajit -e "local P=dofile('$DIR/libs/see-in-3d-paintbrush.lua'); io.write(#P.compile(P.read('$WORK/marks.lua')).cr)"); [ "$faces" = "$triangles" ] && echo yes || echo no)"
lit=$(luajit -e "
    local P = dofile('$DIR/libs/see-in-3d-paintbrush.lua')
    local R = dofile('$DIR/libs/see-in-3d-render.lua')
    local f = io.open('$WORK/glow.lua', 'w')
    f:write('scene{what = \"a lit panel and an unlit one\"}\n')
    f:write('box{at = {-0.6, 0.5, 0}, size = {1, 1, 0.1}, color = \"#ffffff\", glow = true}\n')
    f:write('box{at = {0.6, 0.5, 0}, size = {1, 1, 0.1}, color = \"#ffffff\"}\n')
    f:close()
    local rgb = R.render(P.compile(P.read('$WORK/glow.lua')), R.views[4], 200)
    local brightest_lit, brightest_unlit = 0, 0
    for i = 0, 200 * 200 - 1 do
        local x = i % 200
        local r = rgb:byte(i * 3 + 1)
        if x < 90 and r > brightest_lit then brightest_lit = r end
        if x > 110 and r > brightest_unlit then brightest_unlit = r end
    end
    io.write(brightest_lit, ' ', brightest_unlit)")
check "a glowing face shows its colour unshaded; a lit one does not ($lit)" \
    "$(set -- $lit; [ "$1" = 255 ] && [ "$2" -lt 255 ] && echo yes || echo no)"
output=$("$TOOL" brief "$WORK/marks.png")
check "brief names the picture and prints the paintbrush" "$(contains "$output" "Look at: $WORK/marks.png")"

echo "depth and imagining (no server needed):"
depth=$(luajit -e "
    local P = dofile('$DIR/libs/see-in-3d-paintbrush.lua')
    local R = dofile('$DIR/libs/see-in-3d-render.lua')
    local _, d = R.render(P.compile(P.read('$WORK/marks.lua')), R.views[1], 200)
    -- the box's front face is nearer the front camera than the floor's far edge,
    -- and the sky above the floor holds nothing
    local box = d:byte(120 * 200 + 70 + 1)
    local far_floor = d:byte(112 * 200 + 2 + 1)
    local sky = d:byte(2 * 200 + 2 + 1)
    io.write(box, ' ', far_floor, ' ', sky)")
set -- $depth
check "depth: a near shape is brighter than the far floor ($1 > $2)" "$([ "$1" -gt "$2" ] && echo yes || echo no)"
check "depth: where nothing is drawn, black ($3)" "$([ "$3" = 0 ] && echo yes || echo no)"
"$TOOL" imagine "$WORK/marks.lua" --view=front --picture="$WORK/marks.png" --seed=7 --dry-run > /dev/null
first=$(md5sum < "$WORK/marks-front-workflow.json")
"$TOOL" imagine "$WORK/marks.lua" --view=front --picture="$WORK/marks.png" --seed=7 --dry-run > /dev/null
check "the same scene and settings give the same workflow" "$([ "$first" = "$(md5sum < "$WORK/marks-front-workflow.json")" ] && echo yes || echo no)"
wiring=$(luajit -e "
    local I = dofile('$DIR/libs/see-in-3d-imagine.lua')
    local with = I.workflow{ prompt = 'p', seed = 1, prefix = 'x', depth_image = 'd.png', look_image = 'l.png' }
    local without = I.workflow{ prompt = 'p', seed = 1, prefix = 'x', depth_image = 'd.png' }
    -- every wire points at a node that exists
    local ok = true
    for _, graph in ipairs({ with, without }) do
        for _, node in pairs(graph) do
            for _, value in pairs(node.inputs) do
                if type(value) == 'table' and not graph[value[1]] then ok = false end
            end
        end
    end
    io.write(tostring(ok), ' ', with['11'].inputs.positive[1], ' ', without['11'].inputs.positive[1], ' ', tostring(without['8'] == nil))")
set -- $wiring
check "every wire in the workflow reaches a node" "$([ "$1" = true ] && echo yes || echo no)"
check "with a picture, the sampler takes the look ControlNet's output" "$([ "$2" = 9 ] && echo yes || echo no)"
check "without a picture, it takes the depth ControlNet's, and no picture is loaded" "$([ "$3" = 6 ] && [ "$4" = true ] && echo yes || echo no)"
output=$(luajit -e "local I = dofile('$DIR/libs/see-in-3d-imagine.lua'); io.write(I.json({ text = 'a \"q\" and\\nline', n = 0.5, list = { 1, 'two' } }))")
check "JSON: sorted keys, escaped quotes and line breaks" "$(same=$(printf '%s' '{"list":[1,"two"],"n":0.5,"text":"a \"q\" and\nline"}'); [ "$output" = "$same" ] && echo yes || echo no)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
