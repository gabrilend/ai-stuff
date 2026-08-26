/*
 * 067-view.js -- state in, a moving picture out.
 *
 * This holds no truth and is never trusted. Everything drawn arrived from the
 * server, which already decided what this person may know BY NOT SENDING
 * ANYTHING ELSE. Modifying this file cannot reveal an ambush, because it was
 * never told about one -- which is the entire reason the geometry runs on the
 * host's machine rather than here, where it would be far more convenient and
 * completely worthless.
 *
 * See docs/012-the-dynamic-picture.md and issues 503 through 507.
 */

'use strict';

/* The simulation counts thousandths of a metre. See 021-fixed-point.h. */
const WC_ONE = 1024;

/*
 * The picture speaks feet, rounded to the nearest foot, and NEVER converts back.
 * A command carries metres; two clients rounding differently would disagree
 * about where somebody stood.
 */
const METRES_TO_FEET = 3.28084;

const FULL_TURN = 65536;

/* ------------------------------------------------------------------------- *
 * Decoding
 *
 * An opcode, then a chain of flag words, then the operands in bit order. The
 * slot widths come from TABLES, which the bridge generated from the C header.
 * ------------------------------------------------------------------------- */

/* {{{ function decodeStream */
function decodeStream(bytes) {
    const out = [];
    let at = 0;

    while (at < bytes.length) {
        const opcode = bytes[at];
        const spec = TABLES.slots[opcode];

        at += 1;

        if (spec === undefined) {
            /* Not our language. Everything after it is read at the wrong offset. */
            return out;
        }

        /*
         * The flag chain. The first bit of every word says whether another
         * follows; every other bit is an independent question at a fixed
         * position. There is no length anywhere, which is why nobody can lie
         * about one.
         */
        const present = [];
        let word = 0;

        for (;;) {
            if (at >= bytes.length) return out;

            const flags = bytes[at];
            at += 1;

            for (let bit = 0; bit < 7; bit++) {
                if ((flags & (1 << (bit + 1))) !== 0) {
                    present.push((word * 7) + bit);
                }
            }

            word += 1;

            if ((flags & 1) === 0) break;
            if (word >= TABLES.maxFlagWords) return out;
        }

        const slot = {};
        let short = false;

        for (const index of present.sort((a, b) => a - b)) {
            const bits = spec[index];

            if (bits === undefined || bits === 0) { short = true; break; }

            let value = 0;
            for (let byte = 0; byte < bits / 8; byte++) {
                if (at >= bytes.length) { short = true; break; }
                value |= bytes[at] << (byte * 8);
                at += 1;
            }
            if (short) break;

            slot[index] = value >>> 0;
        }

        if (short) return out;

        out.push({ opcode, slot });
    }

    return out;
}
/* }}} */

/* {{{ function encodeCommand */
function encodeCommand(opcode, values) {
    const spec = TABLES.slots[opcode];
    if (spec === undefined) return null;

    const present = [];
    for (const key of Object.keys(values)) {
        present.push(Number(key));
    }
    present.sort((a, b) => a - b);

    const words = present.length === 0
        ? 1
        : Math.floor(present[present.length - 1] / 7) + 1;

    const bytes = [opcode];

    for (let word = 0; word < words; word++) {
        let flags = (word + 1 < words) ? 1 : 0;

        for (let bit = 0; bit < 7; bit++) {
            if (present.indexOf((word * 7) + bit) >= 0) {
                flags |= (1 << (bit + 1));
            }
        }

        bytes.push(flags);
    }

    for (const index of present) {
        const bits = spec[index] || 32;
        const value = values[index] >>> 0;

        for (let byte = 0; byte < bits / 8; byte++) {
            bytes.push((value >>> (byte * 8)) & 0xFF);
        }
    }

    return new Uint8Array(bytes);
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The world, as two snapshots
 * ------------------------------------------------------------------------- */

let older = null;
let newer = null;
let commandedBody = 0;

/*
 * Where we think our own body is, ahead of the server confirming it.
 *
 * THE ONE PLACE THIS FILE SHOWS SOMETHING UNCONFIRMED -- and not an exception to
 * the trust rule, because predicting where your own character is reveals nothing
 * you did not already know: you pressed the key.
 */
let predicted = null;

/* {{{ function emptyState */
function emptyState() {
    return { tick: 0, walls: [], things: new Map(), fan: [] };
}
/* }}} */

/* {{{ function applyUpdate */
function applyUpdate(instructions) {
    /*
     * An update is the whole picture, not a difference. Each one replaces what
     * was held rather than amending it -- which is why a dropped update costs a
     * beat of freshness and nothing else, and why a rollback desynchronises
     * nothing.
     */
    const state = emptyState();
    let sawEnd = false;

    for (const one of instructions) {
        switch (one.opcode) {
        case TABLES.op.TICK:
            state.tick = (one.slot[1] || 0) * 4294967296 + (one.slot[0] || 0);
            break;

        case TABLES.op.WALL:
            state.walls.push({
                ax: signed(one.slot[1]), ay: signed(one.slot[2]),
                bx: signed(one.slot[3]), by: signed(one.slot[4]),
                flags: one.slot[5] || 0
            });
            break;

        case TABLES.op.THING:
            state.things.set(one.slot[0], {
                index: one.slot[0],
                x: signed(one.slot[1]), y: signed(one.slot[2]),
                facing: one.slot[3] || 0,
                radius: one.slot[4] || 0,
                kind: one.slot[5] || 0,
                motion: one.slot[6] || 0,
                layers: []
            });
            break;

        case TABLES.op.LAYER: {
            /*
             * What it looks like, one shape at a time. The layers of a thing
             * always follow it, so the body they belong to is already here.
             *
             * A layer for a thing that never arrived is dropped rather than
             * kept: it would be an appearance with nothing wearing it, and the
             * only way to get one is a stream that was cut, which the missing
             * END already handles.
             */
            const wearer = state.things.get(one.slot[0]);

            if (wearer !== undefined) {
                wearer.layers.push({
                    shape: one.slot[2] || 0,
                    colour: one.slot[3] || 0,
                    /* Signed bytes through unsigned slots, the same way a
                     * coordinate travels. Forget the sign extension and every
                     * detail lands on one side, which is loud rather than
                     * subtle. */
                    ox: signedByte(one.slot[4]),
                    oy: signedByte(one.slot[5]),
                    radius: one.slot[6] || 0
                });
            }
            break;
        }

        case TABLES.op.FAN:
            state.fan.push({ angle: one.slot[0] || 0, distance: one.slot[1] || 0 });
            break;

        case TABLES.op.REFUSAL:
            say(TABLES.refusals[one.slot[2]] || 'refused, for a reason nobody wrote down');
            break;

        case TABLES.op.RECALL:
            /*
             * A stretch of time did not happen. Throw the prediction away rather
             * than trying to reconcile it -- something visible did happen, and a
             * visible correction is honest about that.
             */
            predicted = null;
            say('that turn was taken back');
            break;

        case TABLES.op.HELLO:
            commandedBody = one.slot[0] || 0;
            break;

        case TABLES.op.END:
            sawEnd = true;
            break;

        default:
            break;
        }
    }

    /* Never swap in a half-arrived update. */
    if (!sawEnd) return;

    older = newer;
    newer = state;
    newer.receivedAt = performance.now();
}
/* }}} */

/* {{{ function signed */
function signed(value) {
    /* Coordinates are int32 on the wire and arrive here unsigned. */
    if (value === undefined) return 0;
    return (value | 0);
}
/* }}} */

/*
 * The same, for a byte. A slot's width is the field's width, so an eight-bit
 * signed value arrives as 0 to 255 and the reader is the only thing that knows
 * it was negative.
 */
/* {{{ function signedByte */
function signedByte(value) {
    const v = value || 0;

    return (v & 0x80) ? v - 256 : v;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Interpolation
 * ------------------------------------------------------------------------- */

/* {{{ function shortWayRound */
function shortWayRound(from, to) {
    let difference = (to - from) & (FULL_TURN - 1);
    if (difference >= FULL_TURN / 2) difference -= FULL_TURN;
    return difference;
}
/* }}} */

/* {{{ function blend */
function blend(fraction) {
    /*
     * The world beats about twenty times a second and a browser draws sixty, so
     * drawing exactly what last arrived shows everything in visible steps. This
     * draws between the two most recent states, one beat behind live -- which
     * buys smooth motion for a fiftieth of a second of latency nobody notices.
     */
    if (newer === null) return [];
    if (older === null) return Array.from(newer.things.values());

    const drawn = [];

    for (const [index, now] of newer.things) {
        const before = older.things.get(index);

        if (before === undefined) {
            /*
             * IT APPEARED. Not moving quickly -- absent, and now present. Bodies
             * arrive and leave constantly here because the filter sends only what
             * is currently visible, and interpolating one from its old position
             * would slide a goblin out of a wall.
             */
            drawn.push(now);
            continue;
        }

        drawn.push({
            index,
            x: before.x + (now.x - before.x) * fraction,
            y: before.y + (now.y - before.y) * fraction,
            facing: before.facing + shortWayRound(before.facing, now.facing) * fraction,
            radius: now.radius,
            kind: now.kind,
            /* The appearance is not interpolated. It does not change, so there
             * is nothing between two of them to be. */
            motion: now.motion,
            layers: now.layers
        });
    }

    /* A body in only the older state is gone. It is simply not drawn. */

    return drawn;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Drawing
 * ------------------------------------------------------------------------- */

const board = document.getElementById('board');
const context = board.getContext('2d');
const panel = document.getElementById('panel');
const said = document.getElementById('said');

let scale = 14;          /* Screen pixels per world metre. */
let originX = 0;
let originY = 0;

/* {{{ function fitToWindow */
function fitToWindow() {
    board.width = window.innerWidth * devicePixelRatio;
    board.height = window.innerHeight * devicePixelRatio;
    context.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
}
/* }}} */

/*
 * Screen to world, in ONE function.
 *
 * The only arithmetic here the server will act on, so it lives in one place --
 * a conversion written twice is written differently twice, and the symptom is
 * clicks landing a metre from where somebody pointed.
 */
/* {{{ function screenToWorld */
function screenToWorld(px, py) {
    return {
        x: Math.round(((px - originX) / scale) * WC_ONE),
        y: Math.round(((originY - py) / scale) * WC_ONE)
    };
}
/* }}} */

/* {{{ function worldToScreen */
function worldToScreen(x, y) {
    return {
        px: originX + (x / WC_ONE) * scale,
        py: originY - (y / WC_ONE) * scale
    };
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The paintbrush, rendered
 *
 * THE VIEW RENDERS THE PAINTBRUSH; IT DOES NOT OWN IT. Four shapes, three of
 * which are two calls each. Nothing here holds an opinion about what a goblin
 * looks like -- only about how to draw a ring.
 *
 * That is why it is small. A view that had to know what a goblin looks like
 * would be a second generator, and two generators that disagree produce two
 * different pictures and no error anywhere.
 * ------------------------------------------------------------------------- */

/* Matching the shape numbers in 082-sprite.h. */
const SHAPE_CIRCLE = 0;
const SHAPE_RECT = 1;
const SHAPE_TRIANGLE = 2;
const SHAPE_RING = 3;

/* Matching the motion numbers. */
const MOTION_STILL = 0;
const MOTION_BOB = 1;
const MOTION_WALK = 2;
const MOTION_FLICKER = 3;
const MOTION_TURN = 4;

/* A sprite is described in hundredths of its own box, measured from the middle. */
const SPRITE_CANVAS = 100;

/* {{{ function hexColour */
function hexColour(packed) {
    return '#' + (packed & 0xFFFFFF).toString(16).padStart(6, '0');
}
/* }}} */

/*
 * How a motion displaces its sprite right now.
 *
 * DRIVEN BY THE FRAME CLOCK, NOT THE BEAT. A bob at twenty beats a second is a
 * stutter; a bob at sixty frames a second is a bob.
 *
 * And it is drawing, not simulation. The bob has no effect on anything, moves
 * nothing, and is never sent anywhere. Confusing the two would be the beginning
 * of a client that thinks it knows where a goblin is.
 */
/* {{{ function motionOf */
function motionOf(motion, index) {
    /* Offset per thing so that a room of goblins does not bob in unison, which
     * reads as one object rather than several. */
    const now = performance.now() / 1000 + index * 0.37;

    if (motion === MOTION_BOB) {
        return { dx: 0, dy: -Math.sin(now * 3.9) * 0.06, alpha: 1, spin: 0 };
    }
    if (motion === MOTION_WALK) {
        return { dx: Math.sin(now * 7.8) * 0.05, dy: 0, alpha: 1, spin: 0 };
    }
    if (motion === MOTION_FLICKER) {
        return { dx: 0, dy: 0, alpha: 0.72 + Math.sin(now * 12.5) * 0.28, spin: 0 };
    }
    if (motion === MOTION_TURN) {
        return { dx: 0, dy: 0, alpha: 1, spin: (now * 1.5) % (Math.PI * 2) };
    }

    return { dx: 0, dy: 0, alpha: 1, spin: 0 };
}
/* }}} */

/* {{{ function drawWornSprite */
function drawWornSprite(p, r, body) {
    /*
     * The sprite's own box is a hundred across and the body's radius is what it
     * is drawn to fill, so one hundredth of the box is this many screen pixels.
     */
    const unit = (r * 2.2) / SPRITE_CANVAS;
    const move = motionOf(body.motion, body.index);

    context.save();
    context.globalAlpha = move.alpha;
    context.translate(p.px + move.dx * r * 2, p.py + move.dy * r * 2);

    if (move.spin !== 0) {
        context.rotate(move.spin);
    }

    for (const layer of body.layers) {
        const cx = layer.ox * unit;
        const cy = layer.oy * unit;
        const size = layer.radius * unit;
        const colour = hexColour(layer.colour);

        context.beginPath();

        if (layer.shape === SHAPE_RECT) {
            context.rect(cx - size, cy - size, size * 2, size * 2);
            context.fillStyle = colour;
            context.fill();
        } else if (layer.shape === SHAPE_TRIANGLE) {
            context.moveTo(cx, cy - size);
            context.lineTo(cx - size, cy + size);
            context.lineTo(cx + size, cy + size);
            context.closePath();
            context.fillStyle = colour;
            context.fill();
        } else if (layer.shape === SHAPE_RING) {
            /* Only its edge. The reader on the other side tells a ring from a
             * circle the same way -- by there being nothing inside it. */
            context.arc(cx, cy, size, 0, Math.PI * 2);
            context.strokeStyle = colour;
            context.lineWidth = Math.max(1, unit * 4);
            context.stroke();
        } else {
            context.arc(cx, cy, size, 0, Math.PI * 2);
            context.fillStyle = colour;
            context.fill();
        }
    }

    /* The one thing this view adds that the sprite does not carry: which body is
     * yours. It is a ring around the outside rather than a tint, so it does not
     * argue with the sprite's own colours. */
    if (body.index === commandedBody) {
        context.beginPath();
        context.arc(0, 0, r * 1.35, 0, Math.PI * 2);
        context.strokeStyle = '#d8c89a';
        context.lineWidth = 2;
        context.stroke();
    }

    context.restore();
}
/* }}} */

/* {{{ function drawFrame */
function drawFrame() {
    requestAnimationFrame(drawFrame);

    const width = window.innerWidth;
    const height = window.innerHeight;

    context.fillStyle = '#0b0b0d';
    context.fillRect(0, 0, width, height);

    if (newer === null) return;

    /* Follow the commanded body, or the middle of what we can see. */
    const me = predicted || newer.things.get(commandedBody);
    if (me) {
        originX = width / 2 - (me.x / WC_ONE) * scale;
        originY = height / 2 + (me.y / WC_ONE) * scale;
    }

    const elapsed = performance.now() - (newer.receivedAt || 0);
    const fraction = Math.max(0, Math.min(1, elapsed / 50));

    /* --- Layer one: what is remembered. Desaturated, and still. --- */
    context.lineWidth = 3;
    context.strokeStyle = '#232228';
    context.beginPath();
    for (const wall of newer.walls) {
        const a = worldToScreen(wall.ax, wall.ay);
        const b = worldToScreen(wall.bx, wall.by);
        context.moveTo(a.px, a.py);
        context.lineTo(b.px, b.py);
    }
    context.stroke();

    /* --- Layer two: what is visible, clipped to the polygon. --- */
    if (newer.fan.length > 2 && me) {
        context.save();
        context.beginPath();

        /*
         * The polygon the server computed to decide what it was allowed to send.
         * It is also exactly what is needed to draw a clean edge between
         * torchlight and dark -- the geometry that made the fog secure is the
         * geometry that makes it look right.
         */
        const start = newer.fanStart || 0;
        let first = true;

        for (const point of newer.fan) {
            const angle = ((point.angle + start) & (FULL_TURN - 1)) / FULL_TURN * Math.PI * 2;
            const reach = point.distance / WC_ONE;
            const wx = me.x + Math.cos(angle) * reach * WC_ONE;
            const wy = me.y + Math.sin(angle) * reach * WC_ONE;
            const p = worldToScreen(wx, wy);

            if (first) { context.moveTo(p.px, p.py); first = false; }
            else { context.lineTo(p.px, p.py); }
        }

        context.closePath();
        context.clip();

        context.fillStyle = 'rgba(70, 62, 48, 0.30)';
        context.fillRect(0, 0, width, height);

        context.lineWidth = 3;
        context.strokeStyle = '#8a7f6b';
        context.beginPath();
        for (const wall of newer.walls) {
            const a = worldToScreen(wall.ax, wall.ay);
            const b = worldToScreen(wall.bx, wall.by);
            context.moveTo(a.px, a.py);
            context.lineTo(b.px, b.py);
        }
        context.stroke();

        context.restore();
    }

    /* --- Layer three: bodies. --- */
    for (const body of blend(fraction)) {
        const drawnAt = (body.index === commandedBody && predicted) ? predicted : body;
        const p = worldToScreen(drawnAt.x, drawnAt.y);
        const r = Math.max(3, (body.radius / WC_ONE) * scale);

        if (body.layers && body.layers.length > 0) {
            drawWornSprite(p, r, body);
        } else {
            /*
             * A body wearing nothing. Normal: a hand-built fixture has no
             * sprite and neither does a world written before things wore them.
             * Not a fallback hiding an error -- the correct picture of a thing
             * whose appearance nobody has decided.
             */
            context.beginPath();
            context.arc(p.px, p.py, r, 0, Math.PI * 2);
            context.fillStyle = (body.index === commandedBody) ? '#d8c89a' : '#9a6a5a';
            context.fill();
        }

        /* Which way it is looking. */
        const angle = (drawnAt.facing / FULL_TURN) * Math.PI * 2;
        context.beginPath();
        context.moveTo(p.px, p.py);
        context.lineTo(p.px + Math.cos(angle) * r * 1.9,
                       p.py - Math.sin(angle) * r * 1.9);
        context.strokeStyle = '#2a2620';
        context.lineWidth = 2;
        context.stroke();
    }

    /*
     * The readout speaks feet, rounded. The simulation never hears about them.
     */
    if (me) {
        panel.innerHTML =
            'beat <b>' + newer.tick + '</b>\n' +
            'you  <b>' + Math.round((me.x / WC_ONE) * METRES_TO_FEET) + ', ' +
            Math.round((me.y / WC_ONE) * METRES_TO_FEET) + '</b> ft\n' +
            'seen <b>' + newer.things.size + '</b> things, <b>' +
            newer.walls.length + '</b> walls';
    }
}
/* }}} */

/* {{{ function say */
let sayTimer = null;
function say(sentence) {
    said.textContent = sentence;
    said.classList.add('showing');

    if (sayTimer) clearTimeout(sayTimer);
    sayTimer = setTimeout(() => said.classList.remove('showing'), 2600);
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Keys and clicks
 * ------------------------------------------------------------------------- */

const held = new Set();
let socket = null;

/* {{{ function directionFromKeys */
function directionFromKeys() {
    let dx = 0;
    let dy = 0;

    if (held.has('w') || held.has('ArrowUp'))    dy += 1;
    if (held.has('s') || held.has('ArrowDown'))  dy -= 1;
    if (held.has('a') || held.has('ArrowLeft'))  dx -= 1;
    if (held.has('d') || held.has('ArrowRight')) dx += 1;

    if (dx === 0 && dy === 0) return null;

    /*
     * Two keys held is ONE direction, computed from both -- not two commands
     * that fight each other.
     */
    const angle = Math.atan2(dy, dx);
    let units = Math.round((angle / (Math.PI * 2)) * FULL_TURN);
    if (units < 0) units += FULL_TURN;

    return units;
}
/* }}} */

/* {{{ function sendMovement */
function sendMovement() {
    if (socket === null || socket.readyState !== 1) return;
    if (commandedBody === 0) return;

    const direction = directionFromKeys();

    /*
     * A held key is a STATE, not an event. Sent when the set of held keys
     * changes, and a stop when the last one lifts -- not one per frame. That is
     * what makes the server's standing-order model work rather than being
     * fought, and it bounds the command rate by how fast fingers move rather
     * than by a monitor.
     */
    if (direction === null) {
        socket.send(encodeCommand(TABLES.op.ORDER_STOP, { 0: commandedBody }));
        predicted = null;
    } else {
        socket.send(encodeCommand(TABLES.op.DRIVE, {
            0: commandedBody,
            1: direction,
            2: Math.round(WC_ONE / 3)
        }));
    }
}
/* }}} */

window.addEventListener('keydown', (event) => {
    if (held.has(event.key)) return;
    held.add(event.key);
    sendMovement();
});

window.addEventListener('keyup', (event) => {
    held.delete(event.key);
    sendMovement();
});

board.addEventListener('click', (event) => {
    if (socket === null || socket.readyState !== 1 || commandedBody === 0) return;

    const target = screenToWorld(event.clientX, event.clientY);

    socket.send(encodeCommand(TABLES.op.ORDER_MOVE, {
        0: commandedBody,
        1: target.x >>> 0,
        2: target.y >>> 0
    }));
});

window.addEventListener('resize', fitToWindow);

/* ------------------------------------------------------------------------- *
 * Prediction
 * ------------------------------------------------------------------------- */

/* {{{ function stepPrediction */
function stepPrediction() {
    if (newer === null || commandedBody === 0) return;

    const truth = newer.things.get(commandedBody);
    if (truth === undefined) { predicted = null; return; }

    const direction = directionFromKeys();

    if (direction === null) {
        predicted = null;
        return;
    }

    if (predicted === null) {
        predicted = { x: truth.x, y: truth.y, facing: truth.facing };
    }

    const angle = (direction / FULL_TURN) * Math.PI * 2;
    const step = WC_ONE / 3;

    predicted.x += Math.cos(angle) * step;
    predicted.y += Math.sin(angle) * step;
    predicted.facing = direction;

    /*
     * Ease toward the server's answer rather than snapping -- but CAP it. Past a
     * certain distance, jump: a large disagreement means the prediction was wrong
     * about something structural, like a wall, and easing across a room looks
     * worse than a snap and takes longer to stop being wrong.
     */
    const apart = Math.hypot(predicted.x - truth.x, predicted.y - truth.y);

    if (apart > WC_ONE * 3) {
        predicted.x = truth.x;
        predicted.y = truth.y;
    } else {
        predicted.x += (truth.x - predicted.x) * 0.25;
        predicted.y += (truth.y - predicted.y) * 0.25;
    }
}
/* }}} */

setInterval(stepPrediction, 50);

/* ------------------------------------------------------------------------- *
 * The socket
 * ------------------------------------------------------------------------- */

/* {{{ function connect */
function connect() {
    socket = new WebSocket('ws://' + location.host + '/socket');
    socket.binaryType = 'arraybuffer';

    socket.onopen = () => { panel.textContent = 'connected'; };

    socket.onmessage = (event) => {
        applyUpdate(decodeStream(new Uint8Array(event.data)));
    };

    socket.onclose = () => {
        panel.textContent = 'the bridge went away';
        socket = null;
        /*
         * Reconnect, but say so. A view that silently retries forever looks
         * exactly like a server that is quietly not sending.
         */
        setTimeout(connect, 1000);
    };
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The action bar
 *
 * The previous session's engraving, hung on the wall. Fetched once, because it
 * is what the LAST session left -- the current one has no statistics yet and
 * will not until it ends. That is what a carving on a wall is.
 *
 * Shown as it is. Not parsed into a table and re-rendered: the carving IS the
 * table, and reading the engraving and reading the database are the same act.
 * ------------------------------------------------------------------------- */

/* {{{ function hangTheEngraving */
function hangTheEngraving() {
    const bar = document.getElementById('bar');

    fetch('/engraving')
        .then((answer) => answer.text())
        .then((text) => { bar.textContent = text.replace(/^vtt-engraving[^]*?\n\n/, ''); })
        .catch(() => {
            /*
             * Said out loud rather than left blank. A bar that shows nothing is
             * indistinguishable from a bar that failed to load, and one of those
             * is a first session and the other is a bug.
             */
            bar.textContent = 'the bridge is not serving an engraving';
        });
}
/* }}} */

fitToWindow();
hangTheEngraving();
connect();
requestAnimationFrame(drawFrame);
