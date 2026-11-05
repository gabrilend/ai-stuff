// 079-test-html-page.js - the HTML page's own JavaScript, run in node.
//
// Started by src/078-test-html-page.lua, which has the canvas server running
// and hands over everything in one JSON file (its path is the only
// argument). It fetches the page as the server sends it, runs its script
// with no browser around it, and checks:
//   - the parser against the test canvases every viewer shares
//     (assets/test-canvases/) and against the Lua reader's answer (022) for
//     each of 078's own canvases, refused ones by their line;
//   - the decryptor against the GCM specification's test cases, the password
//     key against RFC 7914's PBKDF2 examples;
//   - a whole session against the real server: a key in the address, a
//     password, a wrong password, an unknown viewer, a new version arriving,
//     a session that ended, one version for a screenshot;
//   - what the page paints: each cell's colour, which letters are new, and
//     where it lays the canvas out.
// The browser's own part (drawing into the page) is checked in Firefox on
// the owner's machine (issues/completed/803-the-html-page.md).
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const { execFileSync } = require("child_process");

const config = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const BASE = "http://127.0.0.1:" + config.port;
let passed = 0, failed = 0;
function check(name, ok, detail) {
  if (ok) { passed++; console.log("  ok    " + name); }
  else { failed++; console.log("  FAIL  " + name + (detail === undefined ? "" : "\n        " + String(detail).slice(0, 600))); }
}
const hex = (bytes) => Buffer.from(bytes).toString("hex");
const fromHex = (text) => Uint8Array.from(Buffer.from(text, "hex"));
const firstDifference = (a, b) => {
  for (let i = 0; i < Math.max(a.length, b.length); i++) if (a[i] !== b[i]) return (i + 1) + ": got " + a[i] + ", expected " + b[i];
  return null;
};

// {{{ the page's script, from the page the server sends
async function loadPage() {
  const answer = await fetch(BASE + "/");
  const html = await answer.text();
  const script = /<script>([\s\S]*)<\/script>/.exec(html)[1];
  const context = { TextEncoder, TextDecoder, setTimeout, console };
  vm.createContext(context);
  vm.runInContext(script + "\n;globalThis.GF = GF; globalThis.nobleRequire = nobleRequire;", context);
  return { html, GF: context.GF, nobleRequire: context.nobleRequire };
}
// }}}

// {{{ a view written as the .expected files are
function viewLines(view) {
  const lines = ["version " + view.version, "size " + view.width + "x" + view.height, "voices " + view.voices.join(" ")];
  view.cells.forEach((row, r) => row.forEach((cell, c) => {
    let line = "cell " + (r + 1) + " " + (c + 1) + " " + cell.ch.codePointAt(0);
    if (cell.mark) line += " " + cell.mark.voice + " " + cell.mark.version + " " + cell.mark.kind + " " + cell.mark.age;
    lines.push(line);
  }));
  return lines;
}
function answer(GF, bytes) {
  let view;
  try { view = GF.parse(bytes); } catch (e) { return { lines: ["refused " + e.line], error: e }; }
  return { lines: viewLines(view), view };
}
const readLines = (file) => fs.readFileSync(file, "utf8").split("\n").filter((l) => l !== "" && !l.startsWith("#"));
// }}}

// {{{ get(url): as the page's own fetch, and a synchronous one (a browser's XMLHttpRequest)
const getAsync = async (url) => { const r = await fetch(BASE + url, { cache: "no-store" }); return { status: r.status, text: await r.text() }; };
const getSync = (url) => JSON.parse(execFileSync(process.execPath, ["-e",
  "fetch(process.argv[1]).then(async (r) => process.stdout.write(JSON.stringify({ status: r.status, text: await r.text() })))",
  BASE + url]).toString());
// }}}

// {{{ writing a new version as the blitter does: history first, then current, by rename
function publish(text, version) {
  const name = String(version).padStart(6, "0");
  fs.writeFileSync(path.join(config.canvas, "history", "." + name), text);
  fs.renameSync(path.join(config.canvas, "history", "." + name), path.join(config.canvas, "history", name));
  fs.writeFileSync(path.join(config.canvas, ".current"), text);
  fs.renameSync(path.join(config.canvas, ".current"), path.join(config.canvas, "current"));
}
// }}}

async function main() {
  const { html, GF, nobleRequire } = await loadPage();

  console.log("\n=== the page as sent ===");
  // {{{
  check("its script runs with no browser around it, and starts nothing there", typeof GF.parse === "function");
  const outside = html.replace(/<script>[\s\S]*<\/script>/, "");
  check("it asks no other address for anything: no src= or href= in the page, no import() or fetch of a full address in its script",
    !/\ssrc=|\shref=|<link/.test(outside) && !/import\(|fetch\("http|fetch\('http/.test(html),
    (outside.match(/\ssrc=[^ >]*|\shref=[^ >]*|<link[^>]*/) || html.match(/import\(|fetch\(.http/) || [])[0]);
  // }}}

  console.log("\n=== the parser: the test canvases every viewer shares ===");
  // {{{
  const names = fs.readdirSync(config.assets).filter((f) => f.endsWith(".canvas")).map((f) => f.slice(0, -7)).sort();
  check("six test canvases", names.length === 6, names.join(" "));
  for (const name of names) {
    const want = readLines(path.join(config.assets, name + ".expected"));
    const got = answer(GF, fs.readFileSync(path.join(config.assets, name + ".canvas")));
    if (got.view) {
      const previousLine = want.find((l) => l.startsWith("previous "));
      const previousName = previousLine && previousLine !== "previous none" ? previousLine.slice(9) : null;
      got.lines.push("previous " + (previousName || "none"));
      const previous = previousName ? GF.parse(fs.readFileSync(path.join(config.assets, previousName))) : null;
      for (const c of GF.changed(got.view, previous)) {
        got.lines.push("changed " + c.row + " " + c.column + " " + (c.was === undefined ? "-" : c.was.codePointAt(0)) + " " + c.now.codePointAt(0));
      }
    }
    check(name + ": the page's answer matches, line for line", firstDifference(got.lines, want) === null, firstDifference(got.lines, want));
  }
  // }}}

  console.log("\n=== the parser: each of 078's canvases, as the Lua reader (022) reads it ===");
  // {{{
  const cases = fs.readdirSync(config.cases).filter((f) => f.endsWith(".canvas")).sort();
  let agreed = 0;
  const disagreed = [];
  for (const file of cases) {
    const want = readLines(path.join(config.cases, file.replace(/\.canvas$/, ".lua-says")));
    const got = answer(GF, fs.readFileSync(path.join(config.cases, file)));
    if (firstDifference(got.lines, want) === null) agreed++;
    else disagreed.push(file + " " + firstDifference(got.lines, want));
  }
  check("all " + cases.length + " agree, refused ones on the same line", disagreed.length === 0 && cases.length >= 30, disagreed.join("; "));
  let message = "";
  try { GF.parse(fs.readFileSync(path.join(config.assets, "06-refused-too-wide.canvas"))); } catch (e) { message = e.message; }
  check("a refusal says which line and why", /^line 8: row 1 is \d+ characters, over the width of \d+$/.test(message), message);
  // }}}

  console.log("\n=== the locks: the standards' published examples ===");
  // {{{
  const ZERO = "0".repeat(64), K = "feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308";
  const P = "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255";
  const C = "522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662898015ad";
  const gcmCases = [
    ["13", ZERO, "000000000000000000000000", "", "530f8afbc74536b9a963b4f1c4cb738b", ""],
    ["14", ZERO, "000000000000000000000000", "cea7403d4d606b6e074ec5d3baf39d18", "d0d1c8a799996bf0265b98b5d48ab919", "0".repeat(32)],
    ["15", K, "cafebabefacedbaddecaf888", C, "b094dac5d93471bdec1a502270e3cc6c", P],
  ];
  for (const [name, key, nonce, ciphertext, tag, plain] of gcmCases) {
    let got;
    try { got = hex(GF.unlock(fromHex(key), nonce + ciphertext + tag, "")); } catch (e) { got = e.message; }
    check("GCM test case " + name + ": the page unlocks it", got === plain, got);
  }
  const aes = nobleRequire("ciphers/aes.js");
  const sixteen = aes.gcm(fromHex(K), fromHex("cafebabefacedbaddecaf888"), fromHex("feedfacedeadbeeffeedfacedeadbeefabaddad2"));
  check("GCM test case 16 (additional data), through the copied noble-ciphers",
    hex(sixteen.decrypt(fromHex(C.slice(0, 120) + "76fc6ece0f4e1768cddf8853bb2d551b"))) === P.slice(0, 120));
  let refusal = "";
  try { GF.unlock(fromHex(K), "cafebabefacedbaddecaf888" + C + "b094dac5d93471bdec1a502270e3cc6d", ""); } catch (e) { refusal = e.message; }
  check("a changed tag does not unlock, and the page says what that means", /would not unlock: the key or password is wrong/.test(refusal), refusal);
  try { refusal = ""; GF.unlock(fromHex(K), "cafebabefacedbaddecaf888" + C + "b094dac5d93471bdec1a502270e3cc6c", "other words"); } catch (e) { refusal = e.message; }
  check("other words beside it (another session) do not unlock", refusal !== "", refusal);
  check("a password key, RFC 7914: passwd, salt, 1 round (its first 32 bytes)",
    hex(await GF.passwordKey("passwd", hex(Buffer.from("salt")), 1)) === "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc");
  check("a password key, RFC 7914: Password, NaCl, 80000 rounds",
    hex(await GF.passwordKey("Password", hex(Buffer.from("NaCl")), 80000)) === "4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56");
  // }}}

  console.log("\n=== a session against the real server ===");
  // {{{
  const shown = [], reports = [], requests = [];
  // logs each request; once `spoil` is set, the next canvas request names a
  // session the server never made, as if this one had ended
  let spoil = false;
  const logged = (get) => async (url) => {
    if (spoil && url.startsWith("/canvas")) { spoil = false; url = url.replace(/session=[0-9a-f]+/, "session=" + "0".repeat(32)); }
    requests.push(url);
    return get(url);
  };
  const current = fs.readFileSync(path.join(config.canvas, "current"));
  const firstVersion = GF.parse(current).version;
  const watching = GF.follow({ viewer: config.keyViewer, key: fromHex(config.key) }, logged(getAsync),
    (view, previous) => shown.push({ view, previous, at: Date.now() }), (text, problem) => reports.push((problem ? "! " : "") + text));
  watching.catch((e) => reports.push("! stopped: " + e.message));
  const until = async (test, ms) => { const end = Date.now() + ms; while (Date.now() < end && !test()) await new Promise((d) => setTimeout(d, 20)); return test(); };
  check("a key in the address: a session, then the newest version, the server's own bytes unlocked",
    await until(() => shown.length >= 1, 5000) && firstDifference(viewLines(shown[0].view), answer(GF, current).lines) === null
    && shown[0].view.version === firstVersion && requests[0] === "/session?viewer=" + config.keyViewer
    && /^\/canvas\?session=[0-9a-f]{32}$/.test(requests[1]), JSON.stringify(requests) + " " + reports.join(" | "));
  check("it says how it is going", reports.includes("signed in as " + config.keyViewer)
    && reports.some((r) => r.startsWith("version " + firstVersion + ", ")), reports.join(" | "));
  check("then it waits for a newer one", await until(() => requests.some((u) => u.startsWith("/canvas?after=" + firstVersion + "&session=")), 3000), JSON.stringify(requests));
  const newer = fs.readFileSync(path.join(config.assets, "03-dog.canvas"), "utf8").replace(/^canvas: 3$/m, "canvas: " + (firstVersion + 1)).replace(/ 3 (word|sentence)$/gm, " " + (firstVersion + 1) + " $1");
  const publishedAt = Date.now();
  publish(newer, firstVersion + 1);
  check("a new version written is drawn, with the one before it to write over",
    await until(() => shown.length >= 2, 4000) && shown[1].view.version === firstVersion + 1 && shown[1].previous === shown[0].view,
    shown.map((s) => s.view.version).join(" "));
  check("within a second of being written (the server looks every check-seconds)", shown[1] && shown[1].at - publishedAt < 1000, shown[1] && shown[1].at - publishedAt);
  const sessions = () => requests.filter((u) => u.startsWith("/session")).length;
  spoil = true;
  check("a session the server no longer has (403) is begun again by itself",
    await until(() => sessions() >= 2, config.waitSeconds * 1000 + 3000)
    && requests.some((u) => u.includes("session=" + "0".repeat(32))), JSON.stringify(requests.slice(-4)));
  publish(newer.replace(/^canvas: \d+$/m, "canvas: " + (firstVersion + 2)), firstVersion + 2);
  check("and goes on drawing in the new one", await until(() => shown.length >= 3, 4000) && shown[2].view.version === firstVersion + 2,
    shown.map((s) => s.view.version).join(" ") + " " + reports.slice(-3).join(" | "));

  const passwordShown = [];
  const passwordStart = { viewer: config.passwordViewer, password: config.password, version: 1 };
  const one = await GF.follow(passwordStart, getAsync, (view) => passwordShown.push(view), () => {});
  check("a password: its key made in the page, version 1 drawn", one && one.version === 1 && passwordShown.length === 1);
  check("the page forgets the password once its key is made", passwordStart.password === null);
  let wrong = "";
  await GF.follow({ viewer: config.passwordViewer, password: config.password + "x" }, getAsync, () => {}, () => {}).catch((e) => { wrong = e.message; });
  check("a wrong password: nothing drawn, and the page says the password is wrong", /the key or password is wrong/.test(wrong), wrong);
  let unknown = "";
  await GF.follow({ viewer: "nobody", password: "x" }, getAsync, () => {}, () => {}).catch((e) => { unknown = e.message; });
  check("a viewer the server does not have: it says so", unknown === "this server has no viewer called nobody", unknown);
  let keyed = "";
  await GF.follow({ viewer: config.keyViewer, password: "x" }, getAsync, () => {}, () => {}).catch((e) => { keyed = e.message; });
  check("a key viewer asked for a password: it says to use the address", /signs in with a key in the address/.test(keyed), keyed);

  const still = [];
  const stillView = await GF.follow({ viewer: config.keyViewer, key: fromHex(config.key), version: 2 }, getSync, (view) => still.push(view), () => {});
  check("#NAME:KEY:2: version 2 only, fetched synchronously (before a page has loaded), then it stops",
    stillView && stillView.version === 2 && still.length === 1
    && firstDifference(viewLines(stillView), answer(GF, fs.readFileSync(path.join(config.canvas, "history", "000002"))).lines) === null);
  // }}}

  console.log("\n=== what it paints ===");
  // {{{
  const aging = GF.parse(fs.readFileSync(path.join(config.assets, "04-aging.canvas")));
  const painted = GF.paint(aging, null);
  check("a voice's word mark, age 0: its colour at 0.85", painted[0][0].background === "rgba(74, 120, 224, 0.85)", painted[0][0].background);
  check("an older word mark is fainter (age 2: 0.55)", painted[1][0].background === "rgba(224, 80, 80, 0.55)", painted[1][0].background);
  check("a sentence mark is fainter than a word (age 2: 0.15, the last step)", painted[1][4].background === "rgba(224, 80, 80, 0.15)", painted[1][4].background);
  check("an old sentence mark takes the last step", painted[1][7].background === "rgba(64, 176, 96, 0.15)", painted[1][7].background);
  check("an orphan is drawn as a sentence mark (age 1: 0.25)", painted[2][3].background === "rgba(64, 176, 96, 0.25)", painted[2][3].background);
  check("kuvalu's mark in its own colour", painted[2][5].background === "rgba(176, 80, 200, 0.85)", painted[2][5].background);
  check("a cell with no mark has nothing behind it", painted[0][3].background === "");
  check("a two-byte letter is one cell", painted[2][3].ch === "é" && painted[2].length === 16);
  check("with nothing before it, every letter is new and no space is",
    painted.flat().every((cell) => cell.new === (cell.ch !== " ")));
  const kitten = GF.parse(fs.readFileSync(path.join(config.assets, "02-kitten.canvas")));
  const dog = GF.parse(fs.readFileSync(path.join(config.assets, "03-dog.canvas")));
  const over = GF.paint(dog, kitten);
  check("over the kitten, only the changed cells of the dog are new",
    over[0].map((c) => c.new ? "^" : ".").join("") === "....^^^^^^..............", over[0].map((c) => c.new ? "^" : ".").join(""));
  for (const [width, height, letter, want] of config.layouts) {
    const got = GF.layout({ width: 16, height: 3 }, width, height, letter);
    const near = (a, b) => a === b || (typeof a === "number" && typeof b === "number" && Math.abs(a - b) < 1e-9);
    const same = ["size", "width", "height", "left", "top", "problem"].every((k) => near(got[k], want[k]));
    check("laid out in " + width + "x" + height + " as 022's viewer.layout lays it out", same, JSON.stringify(got) + " vs " + JSON.stringify(want));
  }
  // }}}

  console.log("\n=== the page in a pretend browser: start(), drawing, signing in ===");
  { // {{{ its own block: these names are used above too
  const browse = (hash, width, height) => {
    class Element {
      constructor(tag) {
        this.tagName = tag; this.children = []; this.style = {}; this.hidden = tag === "form";
        this.className = ""; this.listeners = {}; this.classes = new Set(); this.text = "";
        this.classList = { add: (c) => this.classes.add(c), remove: (c) => this.classes.delete(c) };
      }
      appendChild(child) { this.children.push(child); return child; }
      removeChild(child) { this.children = this.children.filter((c) => c !== child); return child; }
      set textContent(value) { this.children = []; this.text = value; }
      get textContent() { return this.children.length ? this.children.map((c) => c.textContent).join("") : this.text; }
      getBoundingClientRect() { return { width: 60 }; }    // an M at 100px is 60px across
      get offsetWidth() { return 0; }
      addEventListener(type, listener) { this.listeners[type] = listener; }
    }
    const nodes = { grid: new Element("div"), status: new Element("p"), "sign-in": new Element("form") };
    nodes["sign-in"].viewer = { value: "" };
    nodes["sign-in"].password = { value: "" };
    const document = { getElementById: (id) => nodes[id], createElement: (tag) => new Element(tag),
      createTextNode: (text) => ({ textContent: text }) };
    class XMLHttpRequest {
      open(method, url) { this.url = url; }
      send() { const a = getSync(this.url); this.status = a.status; this.responseText = a.text; }
    }
    const context = { TextEncoder, TextDecoder, setTimeout, console, document, location: { hash },
      innerWidth: width, innerHeight: height, addEventListener: () => {}, XMLHttpRequest,
      fetch: (url, options) => fetch(BASE + url, options) };
    vm.createContext(context);
    vm.runInContext(/<script>([\s\S]*)<\/script>/.exec(html)[1], context);
    return nodes;
  };
  const spans = (grid) => grid.children.filter((c) => c.tagName === "span");
  const rowsOf = (grid) => grid.textContent.split("\n").slice(0, -1);
  const newest = GF.parse(fs.readFileSync(path.join(config.canvas, "current")));
  const inAddress = browse("#" + config.keyViewer + ":" + config.key, 1024, 768);
  check("a key in the address: it draws the newest version, one span a cell, row by row",
    await until(() => inAddress.status.textContent.startsWith("version " + newest.version + ", "), 4000)
    && spans(inAddress.grid).length === newest.width * newest.height
    && rowsOf(inAddress.grid).join("|") === newest.cells.map((row) => row.map((c) => c.ch).join("")).join("|"),
    inAddress.status.textContent + " / " + JSON.stringify(rowsOf(inAddress.grid)));
  const drawn = spans(inAddress.grid);
  const expectedCells = GF.paint(newest, null).flat();
  check("each span has its colour behind it, and the new letters fade in",
    drawn.every((span, i) => (span.style.backgroundColor || "") === expectedCells[i].background && span.classes.has("new") === expectedCells[i].new)
    && drawn.some((span) => span.style.backgroundColor));
  check("laid out at the largest letter size that fits, up to 32px, centred",
    inAddress.grid.style.fontSize === "32px" && inAddress.grid.style.left === Math.floor((1024 - newest.width * 0.6 * 32) / 2) + "px"
    && !inAddress.grid.hidden, JSON.stringify(inAddress.grid.style));
  const small = browse("#" + config.keyViewer + ":" + config.key, 60, 40);
  check("a window too small for the canvas: no squeezing, the grid hidden and the error naming the size",
    await until(() => small.status.className === "problem", 4000) && small.grid.hidden
    && /^the canvas is \d+x\d+; this window holds it only at letter size [\d.]+, below the smallest of 6$/.test(small.status.textContent),
    small.status.textContent);
  const still = browse("#" + config.keyViewer + ":" + config.key + ":2", 1024, 768);
  await new Promise((done) => setImmediate(done));
  check("#NAME:KEY:2 is drawn before anything else can happen (so before a page's load event)",
    still.status.textContent.startsWith("version 2, ") && spans(still.grid).length > 0, still.status.textContent);
  const bare = browse("", 1024, 768);
  check("no key in the address: the sign-in form, and a word saying so",
    bare["sign-in"].hidden === false && bare.status.textContent === "sign in to watch the canvas");
  bare["sign-in"].viewer.value = config.passwordViewer;
  bare["sign-in"].password.value = config.password;
  let prevented = false;
  bare["sign-in"].listeners.submit({ preventDefault: () => { prevented = true; } });
  check("signing in: the form goes, the password box is emptied at once, and the canvas comes",
    prevented && bare["sign-in"].hidden && bare["sign-in"].password.value === ""
    && await until(() => bare.status.textContent.startsWith("version "), 6000), bare.status.textContent);
  const wrongly = browse("", 1024, 768);
  wrongly["sign-in"].viewer.value = config.passwordViewer;
  wrongly["sign-in"].password.value = "not it";
  wrongly["sign-in"].listeners.submit({ preventDefault: () => {} });
  check("a wrong password: the form comes back, with what went wrong",
    await until(() => wrongly.status.className === "problem" && !wrongly["sign-in"].hidden, 6000)
    && /the key or password is wrong/.test(wrongly.status.textContent), wrongly.status.textContent);
  const odd = browse("#phone", 1024, 768);
  check("something after # that is not NAME:KEY: it says so, and offers to sign in",
    /is not NAME:KEY/.test(odd.status.textContent) && odd["sign-in"].hidden === false, odd.status.textContent);
  } // }}}

  console.log("\nnode: " + passed + " passed, " + failed + " failed");
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => { console.log("  FAIL  the page's checks stopped: " + e.stack); console.log("\nnode: " + passed + " passed, " + (failed + 1) + " failed"); process.exit(1); });
