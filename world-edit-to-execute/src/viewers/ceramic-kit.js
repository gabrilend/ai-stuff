// ceramic-kit.js - the chart and data helpers the ceramic report pages share
//
// Spliced into each page's script at the marker @@KIT-JS, after the page
// declares ROWS (the measurement rows), MACHINE and FRAME. Plain SVG, no
// library: pick/all find rows; svg/add/tip/scale build drawings; lineChart
// draws axes, grid, series (solid or dashed, dotted...) and hover notes.

// {{{ data helpers
const pick = (sweep, way, units, workers) => ROWS.find(r => r.sweep === sweep && r.way === way &&
  (units === undefined || r.units === units) && (workers === undefined || r.workers === workers));
const all = (sweep, way) => ROWS.filter(r => r.sweep === sweep && (!way || r.way === way));
const ms = us => (us / 1000).toFixed(us < 1000 ? 2 : 1);
const fmtUs = us => us >= 1000 ? `${(us / 1000).toFixed(2)} ms` : `${us.toFixed(0)} µs`;
const el = id => document.getElementById(id);
// }}}

// {{{ svg helpers
const NS = "http://www.w3.org/2000/svg";
function svg(w, h) { const s = document.createElementNS(NS, "svg"); s.setAttribute("viewBox", `0 0 ${w} ${h}`); s.setAttribute("role", "img"); return s; }
function add(parent, tag, attrs, text) {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  if (text !== undefined) e.textContent = text;
  parent.appendChild(e);
  return e;
}
function tip(e, text) { add(e, "title", {}, text); return e; }
// A scale: linear or log, domain -> range.
function scale(d0, d1, r0, r1, log) {
  if (log) { const a = Math.log(d0), b = Math.log(d1); return v => r0 + (Math.log(v) - a) / (b - a) * (r1 - r0); }
  return v => r0 + (v - d0) / (d1 - d0) * (r1 - r0);
}
// A line chart: series [{color, points:[[x,y,label]], dash, width}], axes with ticks.
function lineChart(target, o) {
  const W = 860, H = o.height || 320, L = 64, R = 20, T = 16, B = 44;
  const s = svg(W, H);
  const x = scale(o.x.min, o.x.max, L, W - R, o.x.log), y = scale(o.y.min, o.y.max, H - B, T, o.y.log);
  for (const t of o.y.ticks) {
    add(s, "line", { x1: L, x2: W - R, y1: y(t), y2: y(t), stroke: "var(--grid)", "stroke-width": 1 });
    add(s, "text", { x: L - 8, y: y(t) + 4, "text-anchor": "end" }, o.y.fmt(t));
  }
  for (const t of o.x.ticks) {
    add(s, "line", { x1: x(t), x2: x(t), y1: H - B, y2: H - B + 5, stroke: "var(--rule)" });
    add(s, "text", { x: x(t), y: H - B + 18, "text-anchor": "middle" }, o.x.fmt(t));
  }
  add(s, "text", { x: (L + W - R) / 2, y: H - 6, "text-anchor": "middle" }, o.x.title);
  add(s, "text", { x: 14, y: T + (H - B - T) / 2, "text-anchor": "middle", transform: `rotate(-90 14 ${T + (H - B - T) / 2})` }, o.y.title);
  if (o.before) o.before(s, x, y, { L, R, T, B, W, H });
  for (const ser of o.series) {
    const d = ser.points.map((p, i) => `${i ? "L" : "M"}${x(p[0]).toFixed(1)},${y(p[1]).toFixed(1)}`).join("");
    add(s, "path", { d, fill: "none", stroke: ser.color, "stroke-width": ser.width || 2.5, "stroke-dasharray": ser.dash || "none", "stroke-linejoin": "round" });
    if (!ser.noDots) for (const p of ser.points) tip(add(s, "circle", { cx: x(p[0]), cy: y(p[1]), r: ser.dash ? 3 : 4, fill: ser.dash ? "var(--sheet)" : ser.color, stroke: ser.dash ? ser.color : "var(--sheet)", "stroke-width": 1.5 }), p[2]);
    if (ser.end) { const p = ser.points[ser.points.length - 1]; add(s, "text", { x: x(p[0]) - 6, y: y(p[1]) - 9, "text-anchor": "end", class: "label", style: `fill:${ser.color}` }, ser.end); }
  }
  if (o.after) o.after(s, x, y, { L, R, T, B, W, H });
  target.replaceChildren(s);
}
// }}}
