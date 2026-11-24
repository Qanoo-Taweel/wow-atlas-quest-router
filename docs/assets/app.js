/* docs/assets/app.js - website UI. All routing is done by AtlasQR (ATLAS). */
(function () {
  "use strict";
  const D = window.AQR_DATA, A = window.AtlasQR;
  const $ = (s) => document.querySelector(s);
  const NS = "http://www.w3.org/2000/svg";
  const el = (tag, attrs = {}, parent) => { const e = document.createElementNS(NS, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (parent) parent.appendChild(e); return e; };
  const LOC = new Map(D.locations.map((l) => [l.id, l]));
  const QUEST = new Map(D.quests.map((q) => [q.id, q]));
  const MODE = {
    walk: { color: "var(--walk)", hex: "#d8c9a3", icon: "🥾", dash: "2 6", width: 2.5 },
    flight: { color: "var(--flight)", hex: "#7fd4ff", icon: "🪶", dash: "", width: 3 },
    boat: { color: "var(--boat)", hex: "#5aa9e6", icon: "⛵", dash: "8 5", width: 3 },
    zeppelin: { color: "var(--zeppelin)", hex: "#e0a050", icon: "🎈", dash: "8 5", width: 3 },
    tram: { color: "var(--tram)", hex: "#b8b8c8", icon: "🚋", dash: "4 3", width: 3 },
    teleport: { color: "var(--teleport)", hex: "#c58cff", icon: "✨", dash: "1 6", width: 3 },
    hearth: { color: "var(--hearth)", hex: "#8fe388", icon: "🏠", dash: "1 6", width: 3 },
  };
  const fmt = (s) => { s = Math.round(s); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    return h ? `${h}h ${String(m).padStart(2, "0")}m` : m ? `${m}m ${String(r).padStart(2, "0")}s` : `${r}s`; };
  const DEMO = { Alliance: [1001, 1002, 1003, 1004, 1005, 1006], Horde: [3001, 3002, 3003, 3005, 3012] };
  const CAPITAL = { Alliance: "stormwind", Horde: "orgrimmar" };
  const stepText = (q, s) => s.kind === "accept" ? `Accept “${q.name}”` : s.kind === "turnin" ? `Turn in “${q.name}”` : `${q.name}: ${s.text}`;

  const state = { faction: "Alliance", selected: new Set(DEMO.Alliance), plan: null, playing: false };

  // ------------------------------------------------------------ controls
  function fillLocations() {
    const sorted = [...D.locations].filter((l) => l.kind !== "spot").sort((a, b) => a.name.localeCompare(b.name));
    for (const sel of [$("#startSel"), $("#bindSel")]) {
      sel.innerHTML = sorted.map((l) => `<option value="${l.id}">${l.name}</option>`).join("");
    }
    $("#startSel").value = CAPITAL[state.faction]; $("#bindSel").value = CAPITAL[state.faction];
  }
  function renderQuestList() {
    const list = D.quests.filter((q) => q.faction === state.faction || q.faction === "Neutral").sort((a, b) => a.level - b.level);
    $("#questList").innerHTML = list.map((q) => {
      const req = (q.requires || []).map((r) => QUEST.get(r)).filter(Boolean).map((r) => r.name);
      return `<label class="quest-item"><input type="checkbox" data-id="${q.id}" ${state.selected.has(q.id) ? "checked" : ""}>
        <span>${q.name}<small>${q.zone} · ${q.steps.length} steps${req.length ? ` · <span class="chain">after ${req.join(", ")}</span>` : ""}</small></span>
        <span class="lvl">${q.level}</span></label>`;
    }).join("");
    $("#questList").querySelectorAll("input").forEach((cb) => cb.addEventListener("change", () => {
      const id = +cb.dataset.id; cb.checked ? state.selected.add(id) : state.selected.delete(id);
    }));
  }
  $("#factionSeg").addEventListener("click", (e) => {
    const b = e.target.closest("button"); if (!b) return;
    state.faction = b.dataset.v;
    $("#factionSeg").querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
    state.selected = new Set(DEMO[state.faction]);
    $("#startSel").value = CAPITAL[state.faction]; $("#bindSel").value = CAPITAL[state.faction];
    renderQuestList(); drawBase(); runPlan();
  });
  $("#qAll").addEventListener("click", () => { $("#questList").querySelectorAll("input").forEach((cb) => state.selected.add(+cb.dataset.id)); renderQuestList(); });
  $("#qNone").addEventListener("click", () => { state.selected.clear(); renderQuestList(); });
  $("#planBtn").addEventListener("click", runPlan);

  function profile() {
    return { faction: state.faction, class: $("#classSel").value, groundSpeed: +$("#speedSel").value,
             bindLocation: $("#bindSel").value, cooldowns: { hearthstone: $("#hearthCd").checked ? 3600 : 0 } };
  }
  function questsFor(ids) { return [...ids].sort((a, b) => a - b).map((id) => JSON.parse(JSON.stringify(QUEST.get(id)))); }

  // ------------------------------------------------------------ map
  const svg = $("#map");
  let gRoute, gMarks, gTraveler;

  function hull(points) {
    const p = [...points].sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
    const lower = [], upper = [];
    for (const q of p) { while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], q) <= 0) lower.pop(); lower.push(q); }
    for (const q of p.reverse()) { while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], q) <= 0) upper.pop(); upper.push(q); }
    return lower.slice(0, -1).concat(upper.slice(0, -1));
  }
  function coast(points, pad, seed) {
    const pts = [];
    for (const [x, y] of points) for (let k = 0; k < 10; k++) { const a = (k / 10) * Math.PI * 2; pts.push([x + Math.cos(a) * pad, y + Math.sin(a) * pad]); }
    const h = hull(pts), out = [];
    for (let i = 0; i < h.length; i++) {
      const a = h[i], b = h[(i + 1) % h.length], len = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.max(1, Math.round(len / 22));
      const nx = (b[1] - a[1]) / (len || 1), ny = -(b[0] - a[0]) / (len || 1);
      for (let j = 0; j < n; j++) {
        const t = j / n, w = Math.sin((i * 7 + j) * 1.7 + seed) * 7 + Math.sin((i + j) * 0.6 + seed * 2) * 5;
        out.push([a[0] + (b[0] - a[0]) * t - nx * w, a[1] + (b[1] - a[1]) * t - ny * w]);
      }
    }
    let d = `M${out[0][0].toFixed(1)},${out[0][1].toFixed(1)}`;
    for (let i = 0; i < out.length; i++) {
      const p0 = out[(i - 1 + out.length) % out.length], p1 = out[i], p2 = out[(i + 1) % out.length], p3 = out[(i + 2) % out.length];
      const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6], c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
      d += ` C${c1[0].toFixed(1)},${c1[1].toFixed(1)} ${c2[0].toFixed(1)},${c2[1].toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
    }
    return d + "Z";
  }

  function drawBase() {
    svg.innerHTML = "";
    const defs = el("defs", {}, svg);
    const og = el("radialGradient", { id: "oceanGrad", cx: "50%", cy: "45%", r: "75%" }, defs);
    el("stop", { offset: "0%", "stop-color": "#15253d" }, og); el("stop", { offset: "100%", "stop-color": "#090f1a" }, og);
    const lg = el("linearGradient", { id: "landGrad", x1: 0, y1: 0, x2: 0, y2: 1 }, defs);
    el("stop", { offset: "0%", "stop-color": "#3b3524" }, lg); el("stop", { offset: "100%", "stop-color": "#2a2619" }, lg);
    el("rect", { x: 0, y: 0, width: 1000, height: 700, class: "ocean" }, svg);
    for (let i = 0; i < 9; i++) el("path", { d: `M0,${80 + i * 70} Q500,${60 + i * 70} 1000,${85 + i * 70}`, stroke: "#1a2b45", "stroke-width": 1, fill: "none", opacity: .45 }, svg);
    const masses = {};
    for (const l of D.locations) (masses[l.landmass] = masses[l.landmass] || []).push([l.x, l.y]);
    let seed = 1;
    for (const [name, pts] of Object.entries(masses)) {
      el("path", { d: coast(pts, name === "Teldrassil" ? 26 : 34, seed++), class: "land", fill: "url(#landGrad)" }, svg);
    }
    const lbl = (t, x, y) => { const e = el("text", { x, y, class: "landlabel" }, svg); e.textContent = t; };
    lbl("KALIMDOR", 120, 660); lbl("EASTERN KINGDOMS", 860, 640);
    const gFp = el("g", {}, svg);
    for (const [a, b] of D.flights[state.faction]) { const p = LOC.get(a), q = LOC.get(b); el("line", { x1: p.x, y1: p.y, x2: q.x, y2: q.y, class: "fp" }, gFp); }
    gRoute = el("g", {}, svg);
    const gLoc = el("g", {}, svg);
    for (const l of D.locations) {
      const g = el("g", { class: `loc ${l.kind}` }, gLoc);
      const r = l.kind === "city" ? 6 : l.kind === "spot" ? 3 : 4.2;
      const fill = l.kind === "spot" ? "#8a7d62" : l.kind === "city" ? "#f5d58a" : "#d9c89e";
      el("circle", { cx: l.x, cy: l.y, r, fill, "data-r": r }, g);
      const t = el("title", {}, g); t.textContent = `${l.name} (${l.zone})`;
      if (l.kind !== "spot" || true) { const tx = el("text", { x: l.x + r + 3, y: l.y + 3, "data-fs": 9.5, "data-sw": 3, "data-x0": l.x, "data-y0": l.y, "data-dx": r + 3, "data-dy": 3 }, g); tx.textContent = l.name; if (l.kind === "spot" || l.kind === "flight") tx.setAttribute("opacity", ".75"); }
      g.addEventListener("click", () => { $("#startSel").value = l.kind === "spot" ? $("#startSel").value : l.id; if (l.kind !== "spot") runPlan(); });
    }
    gMarks = el("g", {}, svg);
    gTraveler = el("g", {}, svg);
  }

  function legPath(leg) {
    const pts = [leg.from, ...leg.via, leg.to].map((id) => LOC.get(id));
    if (leg.mode === "walk") return "M" + pts.map((p) => `${p.x},${p.y}`).join(" L");
    let d = `M${pts[0].x},${pts[0].y}`;
    const bend = leg.mode === "flight" ? 0.12 : leg.mode === "teleport" || leg.mode === "hearth" ? 0.0 : 0.2;
    for (let i = 1; i < pts.length; i++) {
      const a = pts[i - 1], b = pts[i], mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2, dx = b.x - a.x, dy = b.y - a.y;
      d += ` Q${mx - dy * bend},${my + dx * bend} ${b.x},${b.y}`;
    }
    return d;
  }

  function drawRoute(plan) {
    gRoute.innerHTML = ""; gMarks.innerHTML = ""; gTraveler.innerHTML = "";
    plan.legs.forEach((leg, i) => {
      if (leg.kind !== "travel") return;
      const m = MODE[leg.mode];
      el("path", { d: legPath(leg), class: "route", stroke: "#000", "stroke-opacity": .55, "stroke-width": m.width + 3, "data-w": m.width + 3 }, gRoute);
      leg._path = el("path", { d: legPath(leg), class: "route", stroke: m.hex, "stroke-width": m.width, "data-w": m.width, "stroke-dasharray": m.dash, "data-leg": i }, gRoute);
    });
    const perLoc = new Map(); let n = 0;
    plan.legs.forEach((leg, i) => {
      if (leg.kind !== "step") return; n++;
      const k = perLoc.get(leg.location) || 0; perLoc.set(leg.location, k + 1);
      if (k > 3) return;
      const l = LOC.get(leg.location), g = el("g", { class: "stepmark", "data-mark": 1, "data-cx": l.x, "data-cy": l.y }, gMarks);
      const x = l.x + (k % 2 ? 12 : -12) * (k ? 1 : 0), y = l.y - 14 - Math.floor(k / 2) * 14;
      el("circle", { cx: x, cy: y, r: 7.5 }, g); const t = el("text", { x, y }, g); t.textContent = n;
      const tt = el("title", {}, g); tt.textContent = stepText(leg.quest, leg.step);
    });
    const s = LOC.get(plan.start);
    el("circle", { cx: s.x, cy: s.y, r: 9, "data-r": 9, fill: "none", stroke: "#fff", "stroke-width": 2, "data-w": 2, opacity: .85 }, gMarks);
    zoomTo(plan);
  }

  // zoom the map to the part of the world the route uses
  let zoomed = true;
  function zoomTo(plan) {
    if (!zoomed || !plan) { svg.setAttribute("viewBox", "0 0 1000 700"); applyScale(1); return; }
    const ids = new Set([plan.start]);
    for (const l of plan.legs) { if (l.kind === "step") ids.add(l.location); else { ids.add(l.from); ids.add(l.to); l.via.forEach((v) => ids.add(v)); } }
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (const id of ids) { const p = LOC.get(id); x0 = Math.min(x0, p.x); y0 = Math.min(y0, p.y); x1 = Math.max(x1, p.x); y1 = Math.max(y1, p.y); }
    let w = Math.max(x1 - x0 + 140, 300), h = Math.max(y1 - y0 + 110, 210);
    if (w / h > 10 / 7) h = w * 0.7; else w = h / 0.7;
    const cx = (x0 + x1) / 2 + 20, cy = (y0 + y1) / 2;
    const vx = Math.max(0, Math.min(1000 - w, cx - w / 2)), vy = Math.max(0, Math.min(700 - h, cy - h / 2));
    svg.setAttribute("viewBox", `${vx.toFixed(0)} ${vy.toFixed(0)} ${Math.min(w, 1000).toFixed(0)} ${Math.min(h, 700).toFixed(0)}`);
    applyScale(Math.pow(Math.min(w, 1000) / 1000, 0.6));
  }
  // keep labels, dots and lines the same size on screen whatever the zoom
  function applyScale(k) {
    svg.querySelectorAll("[data-r]").forEach((e) => { e.setAttribute("r", +e.dataset.r * k); e.style.strokeWidth = 1.5 * k; });
    svg.querySelectorAll("[data-w]").forEach((e) => e.setAttribute("stroke-width", +e.dataset.w * k));
    svg.querySelectorAll("[data-fs]").forEach((e) => { e.style.fontSize = (+e.dataset.fs * k) + "px"; if (e.dataset.sw) e.style.strokeWidth = (+e.dataset.sw * k) + "px"; });
    svg.querySelectorAll("[data-dx]").forEach((e) => { e.setAttribute("x", +e.dataset.x0 + +e.dataset.dx * k); e.setAttribute("y", +e.dataset.y0 + +e.dataset.dy * k); });
    svg.querySelectorAll("[data-mark]").forEach((g) => g.setAttribute("transform", `translate(${g.dataset.cx},${g.dataset.cy}) scale(${k}) translate(${-g.dataset.cx},${-g.dataset.cy})`));
  }
  $("#zoomBtn").addEventListener("click", () => { zoomed = !zoomed; $("#zoomBtn").textContent = zoomed ? "Whole world" : "Zoom to route"; zoomTo(state.plan); });

  function renderLegend() {
    $("#legend").innerHTML = Object.entries(MODE).map(([k, m]) => `<span><i style="background:${m.hex}"></i>${D.modeLabels[k]}</span>`).join("") + `<span><i style="background:var(--gold);height:10px;width:10px;border-radius:50%"></i>Quest step</span>`;
  }

  // ------------------------------------------------------------ plan + output
  function legLine(leg) {
    if (leg.kind === "step") return { title: stepText(leg.quest, leg.step), sub: LOC.get(leg.location).name };
    const via = leg.via.length ? ` via ${leg.via.map((v) => LOC.get(v).name).join(", ")}` : "";
    return { title: `${D.modeLabels[leg.mode]}: ${LOC.get(leg.from).name} → ${LOC.get(leg.to).name}`, sub: via.trim() };
  }

  function runPlan() {
    stopPlay();
    const start = $("#startSel").value;
    if (!state.selected.size) { $("#summary").innerHTML = `<div class="panel warn">Pick at least one quest.</div>`; return; }
    const plan = A.plan(D, profile(), questsFor(state.selected), start);
    plan.start = start; state.plan = plan;
    drawRoute(plan);
    const steps = plan.legs.filter((l) => l.kind === "step").length;
    const travel = plan.legs.filter((l) => l.kind === "travel").reduce((s, l) => s + l.seconds, 0);
    $("#summary").innerHTML = [
      [fmt(plan.totalSeconds), "total session time"], [fmt(travel), "of it travelling"],
      [`${steps}`, `quest steps · ${plan.legs.length} legs`], [`${plan.elapsedMs.toFixed(1)} ms`, `ATLAS · ${plan.iterations} iterations`],
    ].map(([b, s]) => `<div class="panel stat"><b>${b}</b><span>${s}</span></div>`).join("") +
      (plan.unreachable.length ? `<div class="panel warn">${plan.unreachable.length} step(s) cannot be reached by a ${state.faction} character: ${[...new Set(plan.unreachable.map((u) => u.quest.name))].join(", ")}.</div>` : "");
    let clock = 0;
    $("#itinerary").innerHTML = plan.legs.map((leg, i) => {
      clock += leg.seconds; const t = legLine(leg);
      const ic = leg.kind === "step" ? `<span class="leg-ic">${leg.step.kind === "accept" ? "!" : leg.step.kind === "turnin" ? "?" : "⚔"}</span>`
        : `<span class="leg-ic" style="background:${MODE[leg.mode].hex}">${MODE[leg.mode].icon}</span>`;
      return `<li class="${leg.kind === "step" ? "leg-step" : ""}" data-i="${i}">${ic}<span>${t.title}${t.sub ? `<span class="leg-sub">${t.sub}</span>` : ""}</span><span class="leg-t">${fmt(clock)}</span></li>`;
    }).join("");
    $("#itMeta").textContent = `graph: ${plan.nodes} places · ${plan.edges} edges · ${plan.required} required`;
  }

  // ------------------------------------------------------------ playback
  let raf = null;
  function stopPlay() { state.playing = false; if (raf) cancelAnimationFrame(raf); raf = null; $("#playBtn").textContent = "▶ Play route"; if (gTraveler) gTraveler.innerHTML = ""; }
  $("#playBtn").addEventListener("click", () => {
    if (state.playing) return stopPlay();
    const plan = state.plan; if (!plan) return;
    state.playing = true; $("#playBtn").textContent = "■ Stop";
    gTraveler.innerHTML = ""; const k = Math.pow(+svg.getAttribute("viewBox").split(" ")[2] / 1000, 0.6); const dot = el("circle", { r: 6 * k, class: "traveler", "stroke-width": 3 * k }, gTraveler);
    const s0 = LOC.get(plan.start); dot.setAttribute("cx", s0.x); dot.setAttribute("cy", s0.y);
    let i = 0, t0 = null;
    const items = [...$("#itinerary").children];
    const tick = (now) => {
      if (!state.playing) return;
      if (i >= plan.legs.length) { stopPlay(); return; }
      const leg = plan.legs[i];
      items.forEach((li, k) => li.classList.toggle("active", k === i));
      const dur = leg.kind === "step" ? 450 : Math.max(500, Math.sqrt(leg.seconds) * 110);
      if (t0 === null) t0 = now;
      const p = Math.min(1, (now - t0) / dur);
      if (leg.kind === "travel" && leg._path) {
        const L = leg._path.getTotalLength(), pt = leg._path.getPointAtLength(L * p);
        dot.setAttribute("cx", pt.x); dot.setAttribute("cy", pt.y);
      }
      if (p >= 1) { i++; t0 = null; }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
  });

  // ------------------------------------------------------------ hero
  function hero() {
    $("#heroStats").innerHTML = [[D.locations.length, "places on the map"], [D.quests.length, "quests in the catalogue"], ["11", "design patterns"], ["7 / 7", "FSMs identical to Java ATLAS"]]
      .map(([b, s]) => `<li><b>${b}</b><span>${s}</span></li>`).join("");
    const plan = A.plan(D, { faction: "Alliance", class: "WARRIOR", groundSpeed: 11.2, bindLocation: "stormwind", cooldowns: {} }, questsFor(DEMO.Alliance), "goldshire");
    const VERB = { walk: "Walk to", flight: "Fly to", boat: "Take the boat to", zeppelin: "Take the zeppelin to", tram: "Take the tram to", teleport: "Teleport to", hearth: "Hearthstone to" };
    const instr = (l) => l.kind === "step" ? stepText(l.quest, l.step) : `${VERB[l.mode]} ${LOC.get(l.to).name}`;
    const COMPASS = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"];
    let cur = 0;
    const show = () => {
      const l = plan.legs[cur], target = l.kind === "step" ? l.location : l.to, from = l.kind === "step" ? l.location : l.from;
      let left = 0; for (let i = cur; i < plan.legs.length; i++) left += plan.legs[i].seconds;
      $("#mockTotal").textContent = `${fmt(left)} left`;
      $("#mockIcon").textContent = l.kind === "step" ? (l.step.kind === "accept" ? "!" : l.step.kind === "turnin" ? "?" : "⚔") : MODE[l.mode].icon;
      $("#mockStep").textContent = instr(l);
      $("#mockDetail").textContent = l.kind === "step" ? `at ${LOC.get(l.location).name}` : `from ${LOC.get(l.from).name}, about ${fmt(l.seconds)}`;
      const a = LOC.get(from), b = LOC.get(target), ang = Math.atan2(b.x - a.x, -(b.y - a.y));
      if (from === target) { $("#mockArrow").style.opacity = .25; $("#mockDir").textContent = `You are there: ${b.name}`; }
      else { $("#mockArrow").style.opacity = 1; $("#mockArrow").style.transform = `rotate(${ang - Math.PI / 2}rad)`;
        $("#mockDir").textContent = `${b.name}, to the ${COMPASS[Math.round(((ang / (2 * Math.PI)) * 8 + 8)) % 8]}`; }
      $("#mockBar").style.width = `${(cur / plan.legs.length) * 100}%`;
      $("#mockLines").innerHTML = plan.legs.slice(cur + 1, cur + 4).map((x) => `<li>${instr(x)}</li>`).join("");
      $("#mockProg").textContent = `${cur + 1} / ${plan.legs.length}`;
    };
    show();
    setInterval(() => { cur = (cur + 1) % plan.legs.length; show(); }, 2600);
  }

  // ------------------------------------------------------------ step-by-step visualizer
  const V = {
    nodes: { sw: ["Stormwind", 95, 95], ns: ["Northshire", 370, 70], gs: ["Goldshire", 270, 200], fd: ["Fargodeep", 400, 320], sh: ["Sentinel Hill", 120, 290], mb: ["Moonbrook", 230, 375] },
    roads: [["sw", "gs", 60], ["sw", "ns", 90], ["gs", "ns", 70], ["gs", "fd", 50], ["sw", "sh", 80], ["sh", "mb", 45], ["gs", "sh", 110]],
    quests: [
      { id: 1, name: "Kobold Candles", steps: [["accept", "gs", 15], ["objective", "fd", 120, "candles"], ["turnin", "gs", 15]] },
      { id: 2, name: "Westfall Stew", steps: [["accept", "sh", 15], ["objective", "mb", 150, "stew"], ["turnin", "sh", 15]] },
      { id: 3, name: "Wolves", steps: [["accept", "sw", 15], ["objective", "ns", 90, "wolves"], ["turnin", "gs", 15]] },
    ],
  };
  function buildViz() {
    const g = new A.Graph(), req = new A.RequirementSet(), names = new Map();
    for (const id of Object.keys(V.nodes)) g.addNode(id);
    const start = g.addEdge("sw", "sw", 0, { kind: "start" }); names.set(start, "start@Stormwind");
    for (const [a, b, w] of V.roads) {
      const ab = g.addEdge(a, b, w, { kind: "road", a, b }); names.set(ab, `${V.nodes[a][0]}→${V.nodes[b][0]}`);
      const ba = g.addEdge(b, a, w, { kind: "road", a: b, b: a }); names.set(ba, `${V.nodes[b][0]}→${V.nodes[a][0]}`);
    }
    for (const q of V.quests) {
      const labels = [];
      for (const [kind, at, sec] of q.steps) {
        const l = g.addEdge(at, at, sec, { kind: "step", q, stepKind: kind, at }); labels.push(l);
        names.set(l, `★${kind === "accept" ? "Accept" : kind === "turnin" ? "Turn in" : "Do"} ${q.name}`);
      }
      req.add(labels[0], []); req.add(labels[1], [labels[0]]); req.add(labels[2], [labels[0], labels[1]]);
    }
    const solver = new A.AtlasSolver({ orderings: [A.Orderings.cheapest], trace: true });
    const result = solver.solve(g, start, req.clone(), {});
    return { g, req, start, names, result };
  }
  const viz = buildViz();
  const frames = [];
  viz.result.trace.forEach((t, k) => { frames.push({ it: k, phase: "dag" }); frames.push({ it: k, phase: "dp" }); frames.push({ it: k, phase: "chain" }); });
  frames.unshift({ it: -1, phase: "intro" }); frames.push({ it: viz.result.trace.length, phase: "done" });
  let vf = 0, vizTimer = null;

  function servedUntil(it, inclusive) {
    const s = new Set(); viz.result.trace.forEach((t, k) => { if (k < it || (inclusive && k === it)) t.served.forEach((l) => s.add(l)); }); return s;
  }
  function tourUntil(it, inclusive) {
    const out = [viz.start]; viz.result.trace.forEach((t, k) => { if (k < it || (inclusive && k === it)) out.push(...t.chain); }); return out;
  }
  function drawViz() {
    const f = frames[vf], s = $("#vizSvg"); s.innerHTML = "";
    const defs = el("defs", {}, s);
    const mk = el("marker", { id: "arr", viewBox: "0 0 10 10", refX: 9, refY: 5, markerWidth: 6, markerHeight: 6, orient: "auto-start-reverse" }, defs);
    el("path", { d: "M0,0 L10,5 L0,10 z", fill: "#f5d58a" }, mk);
    const trace = viz.result.trace[f.it];
    const chainRoads = new Set();
    if (trace && f.phase === "chain") trace.chain.forEach((l) => { const p = viz.g.getEdge(l).payload; if (p.kind === "road") chainRoads.add(l); });
    const dagSet = new Set(trace && f.phase !== "intro" ? trace.order : []);
    for (const [a, b, w] of V.roads) {
      const A1 = V.nodes[a], B1 = V.nodes[b];
      const inDag = [...dagSet].some((l) => { const e = viz.g.getEdge(l); return e.payload.kind === "road" && ((e.source === a && e.destination === b) || (e.source === b && e.destination === a)); });
      el("line", { x1: A1[1], y1: A1[2], x2: B1[1], y2: B1[2], stroke: inDag && f.phase === "dag" ? "#4fc3f7" : "#34405c", "stroke-width": 3, "stroke-linecap": "round" }, s);
      const t = el("text", { x: (A1[1] + B1[1]) / 2 + 6, y: (A1[2] + B1[2]) / 2 - 6, fill: "#9aa3b5", "font-size": 12, "font-family": "JetBrains Mono" }, s); t.textContent = `${w}s`;
    }
    for (const l of chainRoads) {
      const e = viz.g.getEdge(l), a = V.nodes[e.source], b = V.nodes[e.destination];
      const dx = b[1] - a[1], dy = b[2] - a[2], L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L;
      el("line", { x1: a[1] + ux * 16, y1: a[2] + uy * 16, x2: b[1] - ux * 18, y2: b[2] - uy * 18, stroke: "#f5d58a", "stroke-width": 4, "marker-end": "url(#arr)" }, s);
    }
    const served = servedUntil(f.it, f.phase === "chain" || f.phase === "done");
    const tour = f.phase === "intro" ? [viz.start] : tourUntil(f.it, f.phase === "chain" || f.phase === "done");
    const here = viz.g.getEdge(tour[tour.length - 1]).destination;
    const atNode = f.phase === "done" ? here : trace ? viz.g.getEdge(trace.from).destination : "sw";
    for (const [id, [name, x, y]] of Object.entries(V.nodes)) {
      if (id === atNode) el("circle", { cx: x, cy: y, r: 22, fill: "none", stroke: "#fff", "stroke-width": 2, "stroke-dasharray": "3 3" }, s);
      el("circle", { cx: x, cy: y, r: 13, fill: "#1b2232", stroke: "#f5d58a", "stroke-width": 2 }, s);
      const t = el("text", { x, y: y + 32, fill: "#e7e3d8", "font-size": 13, "text-anchor": "middle", "font-weight": 600 }, s); t.textContent = name;
      // quest step badges
      const steps = [];
      for (const [l, e] of viz.g.edges) if (e.payload.kind === "step" && e.payload.at === id) steps.push(l);
      steps.forEach((l, k) => {
        const done = served.has(l), e = viz.g.getEdge(l);
        const avail = !done && (() => { const r = viz.req.clone(); served.forEach((x) => r.markServed(x)); return r.isAvailable(l); })();
        const bx = x - 22 + k * 15, by = y - 30;
        el("circle", { cx: bx + 7, cy: by, r: 6.5, fill: done ? "#6fd08c" : avail ? "#e8b74e" : "#3a3f4d", stroke: "#0b0e14" }, s);
        const tt = el("title", {}, s); tt.textContent = viz.names.get(l);
        const q = el("text", { x: bx + 7, y: by + 3.5, "font-size": 9, "text-anchor": "middle", fill: "#0b0e14", "font-weight": 700 }, s);
        q.textContent = e.payload.stepKind === "accept" ? "!" : e.payload.stepKind === "turnin" ? "?" : "⚔";
      });
    }
    // side panel
    const nm = (l) => viz.names.get(l);
    $("#vizPos").textContent = `${vf + 1} / ${frames.length}`;
    $("#vizTour").textContent = tour.map(nm).join("  →  ");
    const det = $("#vizDetail");
    if (f.phase === "intro") {
      $("#vizPhase").textContent = "Setup"; $("#vizTitle").textContent = "Roads are edges, quest steps are required loops";
      $("#vizText").innerHTML = "Every road exists in both directions with its travel time. Each quest has three <em>required</em> self-loop edges: accept (!), objective (⚔), turn in (?). A gold badge is available now, grey is locked by precedence, green is done. We start in Stormwind.";
      det.innerHTML = `<div class="chips">${viz.req.order.map((l) => `<span class="chip req">${nm(l)}</span>`).join("")}</div>`;
    } else if (f.phase === "dag") {
      $("#vizPhase").textContent = `Iteration ${f.it + 1} · step 1 of 3`; $("#vizTitle").textContent = "Build the local DAG";
      $("#vizText").innerHTML = `Iterative DFS from <code>${nm(trace.from)}</code>, cheapest edge first. Its reverse post-order lists ${trace.order.length} reachable edges in topological order. <strong>${trace.backEdges.length}</strong> successor links point backwards (they would close a cycle) and are ignored this iteration.`;
      det.innerHTML = `<div class="chips">${trace.order.map((l, k) => `<span class="chip ${viz.req.required.has(l) ? "req" : ""}">${k + 1}. ${nm(l)}</span>`).join("")}</div>`;
    } else if (f.phase === "dp") {
      $("#vizPhase").textContent = `Iteration ${f.it + 1} · step 2 of 3`; $("#vizTitle").textContent = "Longest-path dynamic programming";
      $("#vizText").innerHTML = `In DAG order each edge takes the best predecessor: <code>utility += 150</code> per available quest step, <code>cost += seconds</code>, <code>score = utility − cost</code>. The best end edge is highlighted.`;
      const rows = trace.table.filter((r) => r.utility !== undefined && r.pos > 1).map((r) => ({ ...r, score: r.utility - r.cost }))
        .sort((a, b) => b.score - a.score).slice(0, 12);
      const bestEnd = trace.chain[trace.chain.length - 1];
      det.innerHTML = `<table class="dp"><tr><th>edge</th><th>utility</th><th>cost</th><th>score</th><th>from</th></tr>${rows.map((r) =>
        `<tr class="${r.label === bestEnd ? "best" : ""} ${r.available ? "req" : ""}"><td>${nm(r.label)}</td><td>${r.utility}</td><td>${r.cost}</td><td>${r.score}</td><td>${r.comeFrom !== undefined ? nm(r.comeFrom) : "—"}</td></tr>`).join("")}</table>`;
    } else if (f.phase === "chain") {
      $("#vizPhase").textContent = `Iteration ${f.it + 1} · step 3 of 3`; $("#vizTitle").textContent = "Backtrack and extend the tour";
      $("#vizText").innerHTML = `Following <code>comeFrom</code> back to the start gives the chain below (gold arrows). It is appended to the tour and <strong>${trace.served.length}</strong> quest step(s) are marked done, which unlocks the next step of those quests.`;
      det.innerHTML = `<div class="chips">${trace.chain.map((l) => `<span class="chip ${trace.served.includes(l) ? "req" : ""}">${nm(l)}</span>`).join("")}</div>`;
    } else {
      $("#vizPhase").textContent = "Finished"; $("#vizTitle").textContent = `All 9 steps covered in ${viz.result.iterations} iterations`;
      $("#vizText").innerHTML = `Total time <strong>${fmt(viz.result.cost)}</strong>. The real addon does the same on ${D.locations.length} places and ~500 edges, with four DFS orderings per iteration and the paper's edge score for ties.`;
      det.innerHTML = "";
    }
  }
  const vizGo = (d) => { vf = Math.max(0, Math.min(frames.length - 1, vf + d)); drawViz(); };
  $("#vizNext").addEventListener("click", () => vizGo(1));
  $("#vizPrev").addEventListener("click", () => vizGo(-1));
  $("#vizPlay").addEventListener("click", () => {
    if (vizTimer) { clearInterval(vizTimer); vizTimer = null; $("#vizPlay").textContent = "Auto-play"; return; }
    if (vf === frames.length - 1) vf = 0;
    $("#vizPlay").textContent = "Pause";
    vizTimer = setInterval(() => { if (vf >= frames.length - 1) { clearInterval(vizTimer); vizTimer = null; $("#vizPlay").textContent = "Auto-play"; return; } vizGo(1); }, 2200);
  });

  // ------------------------------------------------------------ architecture
  const PATTERNS = [
    ["Facade", "AtlasQuestRouter.lua", "Structural", "One small API (addQuest, plan, nextLeg) in front of ~15 classes. Slash commands, buttons, events and tests call only this object, so the subsystem can change without touching them."],
    ["Factory Method", "UI/UserInteractionFactory.lua", "Creational", "The abstract creator asks createInteraction(kind); WowUserInteractionFactory returns a chat printer and the guide window, the headless factory returns in-memory recorders for tests. The facade never knows which."],
    ["Factory Method", "Travel/TravelLinkFactory.lua · Atlas/AtlasSolverFactory.lua", "Creational", "The builder asks for a 'boat' link and gets a BoatLink; the planner asks for the 'quest' ATLAS profile and gets a fully wired solver. New modes and profiles register without editing callers."],
    ["Chain of Responsibility", "Travel/AccessRules.lua", "Behavioural", "Faction → Class → Level → Cooldown. Each rule rejects a travel link or passes it on, so adding a new restriction is one class and one link in the chain."],
    ["Chain of Responsibility + Command", "UI/Commands.lua", "Behavioural", "Each /aqr verb is a command object; the request walks the chain until a handler accepts it, and an UnknownCommand at the end always answers."],
    ["Builder", "Routing/WorldGraphBuilder.lua", "Creational", "The routing graph is assembled in readable steps (locations, walking, flights, transports, teleports, hearthstone, quest steps, start), each testable alone."],
    ["Strategy", "Atlas/DfsOrderings.lua · Atlas/ScoreComponents.lua", "Behavioural", "DFS visiting orders and each of the paper's six scoring terms are interchangeable objects behind small interfaces."],
    ["Composite", "Atlas/EdgeScorer.lua", "Structural", "EdgeScorer is an IScoreComponent made of IScoreComponents, so ATLAS asks one object for score(e)."],
    ["Observer", "Core/EventBus.lua · Domain/QuestLog.lua", "Behavioural", "The quest log publishes QUEST_ADDED, QUEST_REMOVED and similar events; the facade subscribes and drops a stale plan. The log knows no listeners."],
    ["Adapter", "Platform/GameApi.lua · Platform/GameEventBridge.lua", "Structural", "WowGameApi adapts WoW functions (UnitFactionGroup, GetQuestLogTitle…) to IGameApi; GameEventBridge turns WoW events (QUEST_ACCEPTED, ZONE_CHANGED…) into guide steps. Everything else runs in tests outside the client."],
    ["Repository", "Domain/QuestLog.lua", "Domain", "Stores tracked quests, serialises them to SavedVariables and restores them on login."],
    ["Value Object", "Domain/RoutePlan.lua · Graph/Graph.lua (Edge)", "Domain", "A plan is plain data plus a cursor: legs, total time, meta. Easy to render in chat, in the tracker and on this page."],
  ];
  $("#patterns").innerHTML = PATTERNS.map(([n, w, tag, why]) => `<article class="pattern"><span class="tag">${tag}</span><h3>${n}</h3><span class="where">${w}</span><p>${why}</p></article>`).join("");
  const SOLID = [
    ["S", "Single Responsibility", "Graph stores topology, AtlasSolver routes, WorldGraphBuilder builds, LocationResolver matches names, GuideInteraction draws. Each file opens with one sentence saying what it is for."],
    ["O", "Open / Closed", "New travel mode: subclass TravelLink and register it. New rule: add an AccessRule. New scoring term: add an IScoreComponent. New command: add a CommandHandler. Nothing existing is edited."],
    ["L", "Liskov Substitution", "Any TravelLink, AccessRule, UserInteraction or IDfsOrdering can stand in for another; tests swap WowGameApi for StubGameApi and the facade behaves the same."],
    ["I", "Interface Segregation", "Small interfaces: IScoreComponent has one method, IScheduler one, IRequirementSet five. AtlasSolver sees only IRequirementSet, not the whole quest model."],
    ["D", "Dependency Inversion", "The facade receives IGameApi, IScheduler, UserInteractionFactory and the planner through its constructor. ATLAS depends on interfaces, never on WoW or Domain classes."],
  ];
  $("#solidTable").innerHTML = SOLID.map(([l, n, t]) => `<tr><td>${l}</td><td>${n}</td><td>${t}</td></tr>`).join("");

  // ------------------------------------------------------------ diagrams
  const DIAGRAMS = [
    ["Simplified class diagram", "class-diagram-simplified", "12 classes, the important methods and the pattern of each, on one page."],
    ["Full class diagram", "class-diagram-full", "Every class, interface, attribute and method of the addon. Click to open full size."],
    ["Sequence: /aqr plan", "sequence-plan", "What happens between typing /aqr plan and seeing the route."],
    ["Layers", "packages", "Folders and the direction of dependencies."],
    ["ATLAS flowchart", "atlas-flow", "Algorithm 1 of the paper as implemented in Atlas/AtlasSolver.lua."],
  ];
  function showDiagram(i) {
    const [, f, note] = DIAGRAMS[i];
    $("#diagramImg").src = `diagrams/${f}.svg`; $("#diagramImg").alt = DIAGRAMS[i][0];
    $("#diagramLink").href = `diagrams/${f}.svg`; $("#diagramNote").innerHTML = `${note} · <a href="diagrams/${f}.png" style="color:#7a5a12">PNG for printing</a> · <a href="diagrams/${f}.mmd" style="color:#7a5a12">Mermaid source</a>`;
    $("#diagramTabs").querySelectorAll("button").forEach((b, k) => b.classList.toggle("on", k === i));
  }
  $("#diagramTabs").innerHTML = DIAGRAMS.map(([n], i) => `<button data-i="${i}">${n}</button>`).join("");
  $("#diagramTabs").addEventListener("click", (e) => { const b = e.target.closest("button"); if (b) showDiagram(+b.dataset.i); });

  // ------------------------------------------------------------ boot
  fillLocations(); renderQuestList(); renderLegend(); drawBase(); runPlan(); hero(); drawViz(); showDiagram(0);
})();
