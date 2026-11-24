// tests/parity.mjs - the website's JavaScript ATLAS must equal the Lua addon.
//   node tests/parity.mjs
import { readFileSync } from "node:fs";
import vm from "node:vm";

const sandbox = { window: {}, console, performance };
vm.createContext(sandbox);
vm.runInContext(readFileSync("docs/assets/data.js", "utf8"), sandbox);
vm.runInContext(readFileSync("docs/assets/atlas.js", "utf8"), sandbox);
const { AQR_DATA: data, AtlasQR: atlas } = sandbox.window;
const expected = JSON.parse(readFileSync("tests/fixtures/parity.json", "utf8"));
const byId = new Map(data.quests.map((q) => [q.id, q]));

let failed = 0;
expected.forEach((exp, i) => {
  const s = exp.scenario;
  const quests = s.quests.map((id) => JSON.parse(JSON.stringify(byId.get(id))));
  const plan = atlas.plan(data, { faction: s.faction, class: s.class, groundSpeed: s.speed, bindLocation: s.bind, cooldowns: {} }, quests, s.start);
  const legs = plan.legs.map((l) => (l.kind === "step" ? `step:${l.quest.id}:${l.index}` : `${l.mode}:${l.from}>${l.to}`));
  const same = JSON.stringify(legs) === JSON.stringify(exp.legs) && JSON.stringify(plan.tour) === JSON.stringify(exp.tour)
    && Math.abs(plan.totalSeconds - exp.totalSeconds) < 0.01 && plan.iterations === exp.iterations;
  console.log(`${same ? "ok  " : "FAIL"} scenario ${i + 1} (${s.faction} ${s.class}, ${s.quests.length} quests): ${legs.length} legs, ${Math.round(plan.totalSeconds)} s`);
  if (!same) {
    failed++;
    const k = legs.findIndex((x, j) => x !== exp.legs[j]);
    console.log("   first difference at leg", k, "js:", legs[k], "lua:", exp.legs[k]);
  }
});
process.exit(failed ? 1 : 0);
