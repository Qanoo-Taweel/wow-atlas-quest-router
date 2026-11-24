/* ==========================================================================
   docs/assets/atlas.js
   JavaScript port of the addon's ATLAS planner (AtlasQuestRouter/Atlas/*,
   Routing/*). Same data, same rules, same tie-breaking: for the scenarios in
   tests/fixtures/parity.json it produces the exact same route as the Lua
   addon (checked by tests/parity.mjs in CI).

   ATLAS is the only routing algorithm on this website.
   ========================================================================== */
(function (root) {
  "use strict";

  // ---------------------------------------------------------------- Graph
  class Graph {
    constructor() { this.nodeOrder = []; this.nodeData = new Map(); this.out = new Map(); this.inCount = new Map(); this.edges = new Map(); this.total = 0; }
    addNode(id, data) {
      if (!this.nodeData.has(id)) { this.nodeOrder.push(id); this.nodeData.set(id, data || {}); this.out.set(id, []); this.inCount.set(id, 0); }
      return id;
    }
    addEdge(source, destination, weight, payload, label) {
      this.addNode(source); this.addNode(destination);
      this.total += 1;
      if (label === undefined) label = this.total;
      this.edges.set(label, { label, source, destination, weight: weight === undefined ? 1 : weight, payload: payload || {} });
      this.out.get(source).push(label);
      this.inCount.set(destination, this.inCount.get(destination) + 1);
      return label;
    }
    getEdge(l) { return this.edges.get(l); }
    nodes() { return this.nodeOrder; }
    edgeCount() { return this.total; }
    nodeCount() { return this.nodeOrder.length; }
    edgesFrom(n) { return this.out.get(n) || []; }
    successors(l) { return this.edgesFrom(this.edges.get(l).destination); }
    outDegree(n) { return (this.out.get(n) || []).length; }
    inDegree(n) { return this.inCount.get(n) || 0; }
    sortedLabels() { return [...this.edges.keys()].sort((a, b) => a - b); }
  }

  // -------------------------------------------------------- LazyArray (§3.4)
  class LazyArray {
    constructor() { this.values = new Map(); }
    get(i) { return this.values.get(i); }
    set(i, v) { this.values.set(i, v); }
    reset() { this.values.clear(); }
  }

  // ------------------------------------------------ DistanceMatrix (§3.4 APSP)
  class DistanceMatrix {
    constructor(graph) {
      const nodes = graph.nodes(), n = nodes.length, index = new Map();
      nodes.forEach((id, i) => index.set(id, i));
      const dist = [];
      for (let i = 0; i < n; i++) { const row = new Array(n).fill(Infinity); row[i] = 0; dist.push(row); }
      for (const l of graph.sortedLabels()) {
        const e = graph.getEdge(l), i = index.get(e.source), j = index.get(e.destination);
        if (e.weight < dist[i][j]) dist[i][j] = e.weight;
      }
      for (let k = 0; k < n; k++) { const rk = dist[k];
        for (let i = 0; i < n; i++) { const ri = dist[i], dik = ri[k];
          if (dik < Infinity) for (let j = 0; j < n; j++) { const c = dik + rk[j]; if (c < ri[j]) ri[j] = c; } } }
      this.index = index; this.dist = dist; this.nodes = nodes;
    }
    distance(a, b) { const i = this.index.get(a), j = this.index.get(b); if (i === undefined || j === undefined) return Infinity; return this.dist[i][j]; }
    maxDistanceTo(node) {
      const j = this.index.get(node); let best = 0; if (j === undefined) return 1;
      for (let i = 0; i < this.nodes.length; i++) {
        let d = this.dist[i][j]; if (d < Infinity && d > best) best = d;
        d = this.dist[j][i]; if (d < Infinity && d > best) best = d;
      }
      return best > 0 ? best : 1;
    }
  }

  // ------------------------------------------- Score components (eq. 1, 2, 3)
  const Components = {
    required: { weight: 1000, score: (l, c) => (c.requirements.isAvailable(l) ? 1 : 0) },
    connectivity: { weight: 0.5, score: (l, c) => { const d = c.graph.getEdge(l).destination; return c.graph.outDegree(d) + c.graph.inDegree(d); } },
    efficiency: { weight: 10, score: (l, c) => { const e = c.graph.getEdge(l); return (c.requirements.isAvailable(l) ? 1 : 0) / Math.max(e.weight, 1); } },
    savings: { weight: 50, score: (l, c) => {
      if (!c.distances) return 0; const e = c.graph.getEdge(l), d = c.distances;
      const a = d.distance(c.depot, e.source), b = d.distance(e.destination, c.depot);
      if (a === Infinity || b === Infinity) return 0; return (a + b - e.weight) / c.maxDepotDistance; } },
    regret: { weight: 100, score: (l, c) => (c.graph.outDegree(c.graph.getEdge(l).destination) <= 1 ? 1 : 0) },
    proximity: { weight: 20, score: (l, c) => {
      if (!c.distances) return 0; const d = c.distances.distance(c.graph.getEdge(l).destination, c.depot);
      if (d === Infinity) return 0; return 1 - d / c.maxDepotDistance; } },
  };
  const COMPONENT_ORDER = ["required", "connectivity", "efficiency", "savings", "regret", "proximity"];

  class EdgeScorer {
    constructor() { this.weights = {}; for (const k of COMPONENT_ORDER) this.weights[k] = Components[k].weight; }
    adaptTo(graph) {
      const v = Math.max(graph.nodeCount(), 1);
      const density = graph.edgeCount() / (v * Math.max(v - 1, 1));
      for (const k of COMPONENT_ORDER) {
        const base = Components[k].weight;
        if (density < 0.1) this.weights[k] = k === "regret" ? base * 1.5 : k === "savings" ? base * 1.2 : base;
        else this.weights[k] = k === "connectivity" ? base * 2 : base;
      }
      this.density = density; return this;
    }
    score(l, ctx) { let t = 0; for (const k of COMPONENT_ORDER) t = t + this.weights[k] * Components[k].score(l, ctx); return t; }
    breakdown(l, ctx) { const out = {}; for (const k of COMPONENT_ORDER) out[k] = this.weights[k] * Components[k].score(l, ctx); return out; }
  }

  // ------------------------------------------------------- DFS orderings
  const byWeight = (g, dir) => (a, b) => { const wa = g.getEdge(a).weight, wb = g.getEdge(b).weight; if (wa !== wb) return dir * (wa - wb); return a - b; };
  const Orderings = {
    insertion: { name: "insertion", order: (labels) => labels },
    cheapest: { name: "cheapest-first", order: (labels, g) => [...labels].sort(byWeight(g, 1)) },
    expensive: { name: "expensive-first", order: (labels, g) => [...labels].sort(byWeight(g, -1)) },
    required: { name: "required-first", order: (labels, g, req) => [...labels].sort((a, b) => {
      const ra = req && req.isAvailable(a) ? 1 : 0, rb = req && req.isAvailable(b) ? 1 : 0;
      if (ra !== rb) return rb - ra; return byWeight(g, 1)(a, b); }) },
  };

  // --------------------------------------------------- Local DAG (§3.1, §3.2)
  function buildLocalDag(graph, start, ordering, requirements, gate) {
    const children = (l) => { let s = graph.successors(l); if (gate) s = s.filter((x) => gate.allows(x)); return ordering.order(s, graph, requirements); };
    const visited = new Set([start]), post = [];
    const stack = [{ label: start, children: children(start), i: 0 }];
    while (stack.length) {
      const f = stack[stack.length - 1]; const child = f.children[f.i++];
      if (child === undefined) { post.push(f.label); stack.pop(); }
      else if (!visited.has(child)) { visited.add(child); stack.push({ label: child, children: children(child), i: 0 }); }
    }
    const order = post.reverse(), position = new Map();
    order.forEach((l, i) => position.set(l, i + 1));
    return { order, position };
  }

  // ------------------------------------------------------- RequirementSet
  class RequirementSet {
    constructor() { this.order = []; this.required = new Set(); this.prereqs = new Map(); this.served = new Set(); this.dropped = new Set(); }
    add(l, pre) { if (!this.required.has(l)) { this.order.push(l); this.required.add(l); } this.prereqs.set(l, pre || []); return this; }
    isAvailable(l) {
      if (!this.required.has(l) || this.served.has(l) || this.dropped.has(l)) return false;
      for (const p of this.prereqs.get(l)) if (!this.served.has(p)) return false;
      return true;
    }
    markServed(l) { this.served.add(l); }
    hasRemaining() { return this.order.some((l) => this.isAvailable(l)); }
    availableLabels() { return this.order.filter((l) => this.isAvailable(l)); }
    drop(l) { if (this.dropped.has(l)) return; this.dropped.add(l); for (const o of this.order) if (this.prereqs.get(o).includes(l)) this.drop(o); }
    pendingLabels() { return this.order.filter((l) => !this.served.has(l)); }
    clone() { const r = new RequirementSet(); r.order = [...this.order]; r.required = new Set(this.required); r.prereqs = new Map(this.prereqs); r.served = new Set(this.served); r.dropped = new Set(this.dropped); return r; }
  }

  class EdgeGate {
    constructor(graph) { this.graph = graph; this.closed = new Set(); }
    token(l) { return this.graph.getEdge(l).payload.consumable; }
    allows(l) { const t = this.token(l); return t === undefined || !this.closed.has(t); }
    onTraverse(l) { const t = this.token(l); if (t !== undefined) this.closed.add(t); }
  }

  // ------------------------------------------------- AtlasSolver (Algorithm 1)
  const DEFAULTS = { requiredValue: 150, costPenalty: 1, tieBreakWeight: 0.001, safetyFactor: 100 };

  class AtlasSolver {
    constructor(opts = {}) {
      Object.assign(this, DEFAULTS);
      for (const k of Object.keys(DEFAULTS)) if (opts[k] !== undefined) this[k] = opts[k];
      this.orderings = opts.orderings || [Orderings.cheapest];
      this.scorer = opts.scorer || null;
      this.trace = !!opts.trace;
      this.utility = new LazyArray(); this.cost = new LazyArray(); this.comeFrom = new LazyArray(); this.token = new LazyArray();
    }

    extend(graph, start, req, ordering, ctx, detail) {
      const gate = ctx.gate;
      const { order, position } = buildLocalDag(graph, start, ordering, req, gate);
      const U = this.utility, C = this.cost, F = this.comeFrom, K = this.token, lambda = this.costPenalty, gain = this.requiredValue;
      U.reset(); C.reset(); F.reset(); K.reset();
      U.set(start, 0); C.set(start, 0);
      const backEdges = detail ? [] : null;
      for (let i = 1; i <= order.length; i++) {
        const e = order[i - 1], ue = U.get(e);
        if (ue === undefined) continue;
        const ce = C.get(e);
        for (const n of graph.successors(e)) {
          const pn = position.get(n), tn = gate ? gate.token(n) : undefined;
          if (pn !== undefined && pn > i && !(tn !== undefined && K.get(e) === tn)) {
            const nu = ue + (req.isAvailable(n) ? gain : 0);
            const nc = ce + graph.getEdge(n).weight;
            const old = U.get(n);
            if (old === undefined || (nu - lambda * nc) > (old - lambda * C.get(n))) {
              U.set(n, nu); C.set(n, nc); F.set(n, e); K.set(n, tn !== undefined ? tn : K.get(e));
            }
          } else if (detail && pn !== undefined && pn <= i) backEdges.push([e, n]);
        }
      }
      let bestLabel, bestScore;
      for (let i = 2; i <= order.length; i++) {
        const e = order[i - 1], u = U.get(e);
        if (u !== undefined && u > 0 && req.isAvailable(e)) {
          let s = u - lambda * C.get(e);
          if (this.scorer) s = s + this.tieBreakWeight * this.scorer.score(e, ctx);
          if (bestScore === undefined || s > bestScore) { bestLabel = e; bestScore = s; }
        }
      }
      let table = null;
      if (detail) {
        table = order.map((l, idx) => ({ label: l, pos: idx + 1, utility: U.get(l), cost: C.get(l), comeFrom: F.get(l), available: req.isAvailable(l) }));
      }
      if (bestLabel === undefined) return detail ? { chain: null, order, table, backEdges, ordering: ordering.name } : null;
      const chain = []; let cur = bestLabel;
      while (cur !== start) { chain.unshift(cur); cur = F.get(cur); }
      return { chain, score: bestScore, utility: U.get(bestLabel), cost: C.get(bestLabel), ordering: ordering.name, dagSize: order.length, order, table, backEdges };
    }

    solve(graph, start, req, ctx = {}) {
      ctx.graph = graph; ctx.requirements = req;
      const tour = [start], unreachable = [], trace = [];
      let total = 0, iterations = 0;
      const limit = this.safetyFactor * Math.max(graph.edgeCount(), 1);
      while (req.hasRemaining() && iterations < limit) {
        iterations++;
        const current = tour[tour.length - 1];
        let best = null;
        for (const o of this.orderings) {
          const c = this.extend(graph, current, req, o, ctx, this.trace);
          if (c && c.chain && (best === null || c.score > best.score)) best = c;
        }
        if (best === null) {
          for (const l of req.availableLabels()) { unreachable.push(l); req.drop(l); }
        } else {
          const served = [];
          for (const l of best.chain) {
            tour.push(l); total += graph.getEdge(l).weight;
            if (ctx.gate) ctx.gate.onTraverse(l);
            if (req.isAvailable(l)) { req.markServed(l); served.push(l); }
          }
          if (this.trace) trace.push({ iteration: iterations, from: current, chain: best.chain, served, cost: best.cost, ordering: best.ordering, order: best.order, table: best.table, backEdges: best.backEdges, utility: best.utility, score: best.score });
        }
      }
      return { tour, cost: total, iterations, unreachable, trace };
    }
  }

  const SolverFactory = {
    create(profile = "quest", extra = {}) {
      if (profile === "quest") return new AtlasSolver(Object.assign({ scorer: new EdgeScorer(), orderings: [Orderings.cheapest, Orderings.required, Orderings.insertion, Orderings.expensive] }, extra));
      if (profile === "fast") return new AtlasSolver(Object.assign({ orderings: [Orderings.cheapest] }, extra));
      if (profile === "paper") return new AtlasSolver(Object.assign({ scorer: new EdgeScorer(), orderings: [Orderings.insertion] }, extra));
      throw new Error("Unknown ATLAS profile: " + profile);
    },
  };

  // ------------------------------------------------- World graph (Builder)
  function buildWorld(data, profile, quests, start) {
    const K = data.constants, loc = new Map(data.locations.map((l) => [l.id, l]));
    const order = data.locations.map((l) => l.id).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
    const dist = (a, b) => { const la = loc.get(a), lb = loc.get(b); const dx = la.x - lb.x, dy = la.y - lb.y; return Math.sqrt(dx * dx + dy * dy); };
    const g = new Graph(), req = new RequirementSet(), stepByLabel = new Map(), rejected = [];
    for (const id of order) g.addNode(id, loc.get(id));

    const seconds = (mode, a, b, spec) => {
      if (mode === "walk") return dist(a, b) * data.yardsPerUnit * K.roadFactor / (profile.groundSpeed || 7);
      if (mode === "flight") return K.boarding + dist(a, b) * data.yardsPerUnit * K.flightCurve / K.flightSpeed;
      if (mode === "boat" || mode === "zeppelin" || mode === "tram") return spec.ride + spec.interval / 2;
      return 10; // teleport, hearth
    };
    // Chain of Responsibility, same order as Travel/AccessRules.lua
    const allowed = (mode, spec) => {
      const faction = spec.faction || "Neutral";
      if (!(faction === "Neutral" || faction === profile.faction)) return "faction " + faction;
      if (spec.class && spec.class !== profile.class) return "class " + spec.class;
      if (mode === "hearth" && profile.cooldowns && profile.cooldowns.hearthstone > 0) return "hearthstone on cooldown";
      return null;
    };
    const addLink = (mode, a, b, spec = {}) => {
      const reason = allowed(mode, spec);
      if (reason) { rejected.push({ mode, a, b, reason }); return; }
      const s = seconds(mode, a, b, spec);
      const payload = { kind: "travel", mode, from: a, to: b, seconds: s };
      if (mode === "hearth") { payload.consumable = "hearthstone"; payload.penalty = K.hearthPenalty; }
      g.addEdge(a, b, s + (payload.penalty || 0), payload);
    };
    const both = (mode, a, b, spec) => { addLink(mode, a, b, spec); addLink(mode, b, a, spec); };

    // walking network
    const seen = new Set();
    const connect = (a, b) => { const k = a < b ? a + "|" + b : b + "|" + a; if (!seen.has(k)) { seen.add(k); both("walk", a, b); } };
    for (const id of order) {
      const here = loc.get(id);
      const near = order.filter((o) => o !== id && loc.get(o).landmass === here.landmass).map((o) => ({ id: o, d: dist(id, o) }));
      near.sort((x, y) => (x.d !== y.d ? x.d - y.d : x.id < y.id ? -1 : 1));
      for (let i = 0; i < Math.min(K.walkNeighbours, near.length); i++) connect(id, near[i].id);
    }
    for (const [a, b] of data.roads) connect(a, b);
    for (const faction of ["Alliance", "Horde"]) for (const [a, b] of data.flights[faction] || []) both("flight", a, b, { faction });
    for (const [mode, a, b, ride, interval, faction] of data.transports) both(mode, a, b, { ride, interval, faction });
    for (const [cls, dest, faction] of data.teleports) if (profile.class === cls) for (const id of order) if (id !== dest) addLink("teleport", id, dest, { class: cls, faction });
    if (profile.bindLocation && loc.has(profile.bindLocation)) for (const id of order) if (id !== profile.bindLocation) addLink("hearth", id, profile.bindLocation, {});

    // quest steps as required self-loops
    const turnIn = new Map(), labelOf = new Map();
    for (const q of quests) q.steps.forEach((s, idx) => {
      if (s.done) return;
      const label = g.addEdge(s.at, s.at, s.seconds, { kind: "step", quest: q, step: s, index: idx + 1, location: s.at, seconds: s.seconds });
      stepByLabel.set(label, { quest: q, step: s, index: idx + 1 }); labelOf.set(s, label);
      if (s.kind === "turnin") turnIn.set(q.id, label);
    });
    for (const q of quests) {
      let accept = null; const objectives = [];
      for (const s of q.steps) {
        const label = labelOf.get(s); if (label === undefined) continue;
        const pre = [];
        if (s.kind === "accept") { for (const r of q.requires || []) if (turnIn.has(r)) pre.push(turnIn.get(r)); accept = label; }
        else if (s.kind === "objective") { if (accept !== null) pre.push(accept); objectives.push(label); }
        else { if (accept !== null) pre.push(accept); pre.push(...objectives); }
        req.add(label, pre);
      }
    }
    const startLabel = g.addEdge(start, start, 0, { kind: "start", location: start, seconds: 0 });
    return { graph: g, requirements: req, startLabel, stepByLabel, rejected, locations: loc };
  }

  function plan(data, profile, quests, start, options = {}) {
    const model = buildWorld(data, profile, quests, start);
    const solver = SolverFactory.create(options.profile || "quest", { trace: !!options.trace });
    const distances = new DistanceMatrix(model.graph);
    if (solver.scorer) solver.scorer.adaptTo(model.graph);
    const ctx = { gate: new EdgeGate(model.graph), distances, depot: start, maxDepotDistance: distances.maxDistanceTo(start) };
    const t0 = (typeof performance !== "undefined" ? performance.now() : Date.now());
    const result = solver.solve(model.graph, model.startLabel, model.requirements, ctx);
    const elapsedMs = (typeof performance !== "undefined" ? performance.now() : Date.now()) - t0;
    const legs = []; let total = 0;
    for (let i = 1; i < result.tour.length; i++) {
      const e = model.graph.getEdge(result.tour[i]), p = e.payload;
      const s = p.seconds !== undefined ? p.seconds : e.weight; total += s;
      if (p.kind === "step") legs.push({ kind: "step", quest: p.quest, step: p.step, index: p.index, location: p.location, seconds: s });
      else if (p.kind === "travel") {
        const last = legs[legs.length - 1];
        if (last && last.kind === "travel" && last.mode === p.mode && (p.mode === "walk" || p.mode === "flight")) { last.to = e.destination; last.seconds += s; last.via.push(e.source); }
        else legs.push({ kind: "travel", mode: p.mode, from: e.source, to: e.destination, seconds: s, via: [] });
      }
    }
    const unreachable = model.requirements.pendingLabels().map((l) => model.stepByLabel.get(l));
    return { legs, totalSeconds: total, iterations: result.iterations, elapsedMs, unreachable, tour: result.tour, trace: result.trace,
             edges: model.graph.edgeCount(), nodes: model.graph.nodeCount(), required: model.requirements.order.length, model };
  }

  const API = { Graph, LazyArray, DistanceMatrix, EdgeScorer, Orderings, buildLocalDag, RequirementSet, EdgeGate, AtlasSolver, SolverFactory, buildWorld, plan, DEFAULTS };
  if (typeof module !== "undefined" && module.exports) module.exports = API;
  root.AtlasQR = API;
})(typeof window !== "undefined" ? window : globalThis);
