// phase-8-page.js - the HTML page's own script, run by the phase 8 demo in node.
//
// The demo has no person at a browser, so for the page's numbers it runs the
// page's own script, as the canvas server sends it, against the demo's canvas
// server: the same session, the same long poll, the same unlocking and
// parsing. Firefox, where it is installed, takes the page's real screenshot
// (phase-8-demo.lua). Two ways to run:
//
//   node phase-8-page.js follow PORT VIEWER KEY LOG STOP
//       follows the canvas, writing "drew version N at SECONDS" to LOG for
//       each version drawn, until the file STOP appears
//   node phase-8-page.js still PORT VIEWER KEY VERSION OUT
//       draws that one version as the page paints it, into OUT.html (the
//       page's own style, a span a cell with its colour) and OUT.txt (the rows)
"use strict";

const fs = require("fs");
const vm = require("vm");

const [mode, port, viewer, key] = process.argv.slice(2, 6);
const BASE = "http://127.0.0.1:" + port;
const get = async (url) => { const r = await fetch(BASE + url, { cache: "no-store" }); return { status: r.status, text: await r.text() }; };
const keyBytes = Uint8Array.from(Buffer.from(key, "hex"));

async function page() {
  const html = await (await fetch(BASE + "/")).text();
  const context = { TextEncoder, TextDecoder, setTimeout, console };
  vm.createContext(context);
  vm.runInContext(/<script>([\s\S]*)<\/script>/.exec(html)[1] + "\n;globalThis.GF = GF;", context);
  return { html, GF: context.GF };
}

const escape = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

async function main() {
  const { html, GF } = await page();
  if (mode === "follow") {
    const [log, stop] = process.argv.slice(6, 8);
    fs.writeFileSync(log, "");
    const done = new Promise((finish) => {
      const look = setInterval(() => { if (fs.existsSync(stop)) { clearInterval(look); finish(); } }, 100);
    });
    GF.follow({ viewer, key: keyBytes }, get,
      (view) => fs.appendFileSync(log, "drew version " + view.version + " at " + (Date.now() / 1000).toFixed(3) + "\n"),
      (text, problem) => { if (problem) fs.appendFileSync(log, "problem: " + text + "\n"); })
      .catch((e) => fs.appendFileSync(log, "stopped: " + e.message + "\n"));
    await done;
    process.exit(0);
  }
  if (mode === "still") {
    const [version, out] = process.argv.slice(6, 8);
    let shown = null;
    await GF.follow({ viewer, key: keyBytes, version: Number(version) }, get, (view) => { shown = view; }, () => {});
    if (!shown) { console.error("the page drew no version " + version); process.exit(1); }
    const style = /<style>([\s\S]*?)<\/style>/.exec(html)[1];
    const rows = GF.paint(shown, null).map((row) => row.map((cell) =>
      "<span" + (cell.background ? " style=\"background-color: " + cell.background + "\"" : "") + ">" + escape(cell.ch) + "</span>").join(""));
    fs.writeFileSync(out + ".html", "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n"
      + "<title>The HTML page, version " + shown.version + "</title>\n<style>" + style + "</style></head>\n<body>\n"
      + "<div id=\"grid\" style=\"font-size: 24px; left: 16px; top: 16px\">" + rows.join("\n") + "\n</div>\n"
      + "<p id=\"status\">version " + shown.version + ", " + shown.headers.written + ", as the page paints it (drawn by the page's own script in node)</p>\n"
      + "</body></html>\n");
    fs.writeFileSync(out + ".txt", shown.cells.map((row) => row.map((cell) => cell.ch).join("")).join("\n") + "\n");
    process.exit(0);
  }
  console.error("phase-8-page.js: follow or still");
  process.exit(2);
}

main().catch((e) => { console.error("phase-8-page.js: " + e.message); process.exit(1); });
