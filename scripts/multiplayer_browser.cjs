#!/usr/bin/env node
/* Optional real-canvas acceptance runner. Requires Playwright, tesseract, and Python Pillow.
 * No API commands or engine test hooks: all game actions use mouse/keyboard.
 * WebSocket observations stay in memory; do not write raw traffic or tokens.
 */
const { chromium } = require("playwright");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const out = process.env.MD_BROWSER_EVIDENCE || "/tmp/market-dominion-browser";
const web = process.env.MD_BROWSER_WEB || "http://127.0.0.1:8097/index.html";
const api = process.env.MD_BROWSER_API || "http://127.0.0.1:8742";
fs.mkdirSync(out, { recursive: true });
// A failed run must not leave a previous success report looking current.
const resultPath = path.join(out, "result.json");
if (fs.existsSync(resultPath)) fs.unlinkSync(resultPath);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(f, label, ms = 20000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (errors.length) throw Error(JSON.stringify(errors));
    if (f()) return;
    await sleep(100);
  }
  throw Error("Timeout: " + label);
}
const snaps = [null, null],
  errors = [],
  sent = [[], []],
  counts = {
    commands: 0,
    placed: [0, 0],
    bought: [0, 0],
    sold: [0, 0],
    events: 0,
    mergers: 0,
  };
const tokens = [null, null];
function inspect(e, i) {
  const payload = e.payload || {};
  if (e.event === "error") errors.push({ seat: i, code: payload.code });
  if (e.event === "state_snapshot") {
    assert.equal(payload.state.seed, 0, "shuffle seed leaked");
    assert(
      !JSON.stringify(payload.state).match(
        /"(?:hand|hands|your_hand|session_token|token)"/,
      ),
      "private fields in public state",
    );
    if (snaps[i]?.you) assert.equal(payload.you, snaps[i].you, "changed seat");
    snaps[i] = payload;
  }
  if (payload.session_token) {
    assert.equal(e.event, "room_updated");
    tokens[i] = payload.session_token;
  }
  if (tokens[1 - i])
    assert(
      !JSON.stringify(e).includes(tokens[1 - i]),
      "other seat token leaked",
    );
  if (e.event !== "state_snapshot" && e.event !== "room_updated")
    assert(
      !JSON.stringify(e).match(
        /"(?:hand|hands|your_hand|session_token|token)"/,
      ),
      "private public event",
    );
}
function observe(p, i) {
  p.on("response", async (r) => {
    if (r.url().endsWith("/v1/rooms/commands")) {
      try {
        for (const e of (await r.json()).events || []) inspect(e, i);
      } catch (e) {
        errors.push({ code: "response_assertion", message: e.message });
      }
    }
  });
  p.on("websocket", (ws) => {
    ws.on("framereceived", (f) => {
      try {
        inspect(JSON.parse(f.payload), i);
      } catch (e) {
        errors.push({ code: "frame_assertion", message: e.message });
      }
    });
    ws.on("framesent", (f) => {
      try {
        const c = JSON.parse(f.payload);
        sent[i].push(c.command);
      } catch {}
    });
  });
}
async function read(p) {
  await p.bringToFront();
  const img = path.join(out, "current.png");
  await p.screenshot({ path: img });
  execFileSync("python3", [
    "-c",
    "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('L').point(lambda v: 0 if v>145 else 255).save(sys.argv[2])",
    img,
    path.join(out, "ocr.png"),
  ]);
  const tsv = execFileSync(
    "tesseract",
    [path.join(out, "ocr.png"), "stdout", "--psm", "11", "tsv"],
    {
      env: { ...process.env, OMP_THREAD_LIMIT: "1" },
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    },
  );
  const groups = new Map();
  const words = [];
  for (const line of tsv.trim().split("\n").slice(1)) {
    const c = line.split("\t");
    if (c[0] !== "5" || !c[11]?.trim()) continue;
    const key = c.slice(1, 5).join(":");
    let g = groups.get(key);
    const x = +c[6],
      y = +c[7],
      w = +c[8],
      h = +c[9];
    if (/^[A-I][1-9]$/i.test(c[11]))
      words.push({ text: c[11].toUpperCase(), x, y, r: x + w, b: y + h });
    if (!g) {
      g = { text: "", x, y, r: x + w, b: y + h };
      groups.set(key, g);
    }
    g.text += (g.text ? " " : "") + c[11];
    g.x = Math.min(g.x, x);
    g.y = Math.min(g.y, y);
    g.r = Math.max(g.r, x + w);
    g.b = Math.max(g.b, y + h);
  }
  return [...groups.values(), ...words]
    .map((g) => ({ ...g, text: g.text.replace(/\bAl\b/g, "AI") }))
    .sort((a, b) => a.y - b.y);
}
async function click(p, pattern, { bottom = false, scroll = true } = {}) {
  for (let attempt = 0; attempt < (scroll ? 5 : 1); attempt++) {
    const lines = await read(p);
    let found = lines.filter((l) => pattern.test(l.text));
    if (found.length) {
      const l = bottom ? found.at(-1) : found[0];
      console.log("CLICK", l.text);
      await p.mouse.click((l.x + l.r) / 2, (l.y + l.b) / 2);
      await sleep(200);
      return l.text;
    }
    await p.mouse.move(
      p.viewportSize().width - 20,
      Math.min(650, p.viewportSize().height - 50),
    );
    await p.mouse.wheel(0, attempt === 3 ? -2400 : 550);
    await sleep(150);
  }
  throw Error("Canvas text not found: " + pattern);
}
const dismissed = ["", ""];
async function dismissEvents(p, i) {
  const last =
    snaps[i].state.action_log
      .filter((x) => x.outcome.startsWith("Round event:"))
      .at(-1)?.outcome || "";
  if (!last || last === dismissed[i]) return;
  const lines = await read(p);
  if (lines.some((l) => /^Continue$/.test(l.text))) {
    await click(p, /^Continue$/, { scroll: false });
    counts.events++;
    dismissed[i] = last;
    await sleep(100);
  }
}
(async () => {
  let browser;
  let pages = [];
  try {
    browser = await chromium.launch({
      executablePath: process.env.CHROMIUM_BIN || "/usr/bin/chromium",
      headless: true,
      args: [
        "--no-sandbox",
        "--enable-unsafe-swiftshader",
        "--disable-dev-shm-usage",
        "--disable-background-timer-throttling",
        "--disable-renderer-backgrounding",
      ],
    });
    const ca = await browser.newContext({
      viewport: { width: 1280, height: 900 },
      permissions: ["clipboard-read", "clipboard-write"],
    });
    const cb = await browser.newContext({
      viewport: { width: 1280, height: 900 },
    });
    await ca.addInitScript(() => {
      const sockets = [];
      const Native = window.WebSocket;
      window.WebSocket = class extends Native {
        constructor(...args) {
          super(...args);
          sockets.push(this);
        }
      };
      window.__mdDropSockets = () => sockets.forEach((s) => s.close());
    });
    const a = await ca.newPage(),
      b = await cb.newPage();
    pages = [a, b];
    observe(a, 0);
    observe(b, 1);
    await a.goto(web + "?server=" + encodeURIComponent(api));
    await sleep(5000);
    await click(a, /Create private room/);
    await until(() => snaps[0], "host created");
    await click(a, /Copy invitation link/);
    const link = await a.evaluate(() => navigator.clipboard.readText());
    assert(new URL(link).searchParams.get("invite"));
    assert(!/token/i.test(link));
    await b.goto(link);
    await sleep(5000);
    await click(b, /^Rowan$/);
    await b.keyboard.press("Control+A");
    await b.keyboard.type("Player B");
    await click(b, /Join with invite/);
    await until(() => snaps[1], "first join");
    assert.equal(errors.length, 0, JSON.stringify(errors));
    await click(a, /^Ready$/);
    await click(b, /^Ready$/);
    await until(
      () => snaps.every((s) => s.state.players.every((p) => p.is_ready)),
      "both ready",
    );
    await click(a, /Start match/);
    await until(
      () => snaps.every((s) => s.state.phase === "playing"),
      "match start",
    );
    assert.notEqual(snaps[0].you, snaps[1].you);
    assert.equal(snaps[0].your_hand.length, 5);
    assert.equal(snaps[1].your_hand.length, 5);
    assert.notDeepEqual(snaps[0].your_hand, snaps[1].your_hand);
    assert.deepEqual(snaps[0].state, snaps[1].state);
    await a.screenshot({ path: path.join(out, "a-start.png") });
    await b.screenshot({ path: path.join(out, "b-start.png") });
    await a.setViewportSize({ width: 768, height: 1024 });
    await sleep(300);
    await a.screenshot({ path: path.join(out, "tablet-768.png") });
    await b.setViewportSize({ width: 390, height: 844 });
    await sleep(300);
    await b.screenshot({ path: path.join(out, "phone-390.png") });
    if (!process.env.MD_VIEWPORT_ACCEPTANCE) {
      await a.setViewportSize({ width: 1280, height: 900 });
      await b.setViewportSize({ width: 1280, height: 900 });
    }
    await sleep(200);
    console.log(
      "BROWSER_MATCH_STARTED first join, ready, start, separate hands",
    );
    let refreshed = false,
      reconnected = false;
    for (let n = 0; n < 500 && snaps[0].state.phase !== "completed"; n++) {
      await until(
        () => snaps[0].state.version === snaps[1].state.version,
        "sync",
      );
      assert.deepEqual(snaps[0].state, snaps[1].state);
      const i = snaps.findIndex((s) => s.you === s.state.active_player_id),
        p = pages[i],
        s = snaps[i];
      await dismissEvents(p, i);
      let command;
      if (s.step === "place") {
        const cells = s.state.board
          .filter((c) => c.occupied)
          .map((c) => c.coordinate);
        // Prefer adjacent hand tiles to exercise company founding and mergers.
        const score = (t) =>
          cells.filter(
            (c) =>
              Math.abs(c.charCodeAt(0) - t.charCodeAt(0)) +
                Math.abs(+c.slice(1) - +t.slice(1)) ===
              1,
          ).length;
        const hand = [...s.your_hand].sort((a, b) => score(b) - score(a));
        if (!hand.length) {
          await click(p, /Skip placement/);
          command = "end_turn";
        } else if (process.env.MD_VIEWPORT_ACCEPTANCE) {
          await p.bringToFront();
          let placed = false;
          for (let attempt = 0; attempt < 6 && !placed; attempt++) {
            const lines = await read(p);
            const caption = lines.find((l) => /Your tiles/.test(l.text));
            const tile =
              caption &&
              lines.find((l) => l.y > caption.y && hand.includes(l.text));
            if (tile) {
              await p.mouse.click((tile.x + tile.r) / 2, (tile.y + tile.b) / 2);
              placed = true;
            } else {
              await p.mouse.move(p.viewportSize().width - 20, 400);
              await p.mouse.wheel(0, 400);
              await sleep(150);
            }
          }
          assert(placed, "narrow viewport hand control not found");
          command = "place_tile";
          counts.placed[i]++;
        } else {
          // Real grid click, calibrated for the 1280x900 desktop layout captured above.
          // Server snapshots assert the clicked tile was actually placed; no game API is invoked.
          await p.bringToFront();
          await p.mouse.move(600, 400);
          await p.mouse.wheel(0, -20000);
          await sleep(150);
          await p.mouse.click(
            101 + 61 * (hand[0].charCodeAt(0) - 65),
            360 + 61 * (+hand[0].slice(1) - 1),
          );
          command = "place_tile";
          counts.placed[i]++;
        }
      } else if (s.step === "choose_founder" || s.step === "choose_survivor") {
        const names = {
          nova_ai: "NOVA AI",
          orbit_pay: "ORBIT PAY",
          volt_grid: "VOLT GRID",
          pulse_media: "PULSE MEDIA",
          evermart: "EVERMART",
        };
        await click(p, new RegExp(names[s.pending_options[0]]), {
          scroll: false,
        });
        command =
          s.step === "choose_founder"
            ? "choose_founder"
            : "choose_merger_survivor";
        if (s.step === "choose_survivor") counts.mergers++;
      } else if (s.step === "market") {
        const me = s.state.players.find((x) => x.id === s.you);
        const owned = s.state.corporations.find(
          (c) => c.active && me.holdings_by_corp[c.id] > 0,
        );
        const buy = s.state.corporations.find(
          (c) => c.active && c.bank_shares > 0 && me.cash >= c.share_price,
        );
        if (owned && counts.bought[i] > 0 && counts.sold[i] === 0) {
          await click(p, new RegExp("^Sell " + owned.name + "$"));
          command = "market_sell_share";
          counts.sold[i]++;
        } else if (buy && counts.bought[i] === 0) {
          await click(p, new RegExp("^Buy " + buy.name + "$"));
          command = "market_buy_share";
          counts.bought[i]++;
        } else {
          await click(p, /^Pass$/);
          command = "pass_market_action";
        }
        await click(p, /^Confirm$/, { scroll: false });
      } else throw Error("Unhandled step " + s.step);
      const version = s.state.version;
      await until(
        () => snaps[i].state.version > version || errors.length,
        command,
      );
      if (command === "place_tile")
        assert(
          snaps[i].state.board.filter((c) => c.occupied).length >
            s.state.board.filter((c) => c.occupied).length,
          "grid click did not place a tile",
        );
      assert.equal(errors.length, 0, JSON.stringify(errors));
      counts.commands++;
      console.log(
        "ACTION",
        counts.commands,
        "seat",
        i + 1,
        command,
        "version",
        snaps[i].state.version,
      );
      if (
        !process.env.MD_VIEWPORT_ACCEPTANCE &&
        !refreshed &&
        counts.placed[1] >= 2
      ) {
        const hand = JSON.stringify(snaps[1].your_hand),
          prev = snaps[1];
        snaps[1] = null;
        dismissed[1] = "";
        await b.reload();
        await until(() => snaps[1], "refresh recovery");
        assert.equal(JSON.stringify(snaps[1].your_hand), hand);
        assert.equal(snaps[1].you, prev.you);
        refreshed = true;
        console.log("BROWSER_REFRESH_RECOVERED");
      }
      if (
        !process.env.MD_VIEWPORT_ACCEPTANCE &&
        !reconnected &&
        counts.placed[0] >= 3
      ) {
        const prev = snaps[0];
        snaps[0] = null;
        await ca.setOffline(true);
        await a.evaluate(() => window.__mdDropSockets());
        await sleep(3500);
        await ca.setOffline(false);
        await until(() => snaps[0], "offline recovery", 30000);
        assert.equal(snaps[0].you, prev.you);
        assert.deepEqual(snaps[0].your_hand, prev.your_hand);
        reconnected = true;
        console.log("BROWSER_OFFLINE_RECOVERED");
      }
      if (
        process.env.MD_MAX_ACTIONS &&
        counts.commands >= +process.env.MD_MAX_ACTIONS
      )
        break;
      if (process.env.MD_VIEWPORT_ACCEPTANCE && counts.commands >= 10) break;
    }
    const completed = snaps.every((s) => s.state.phase === "completed");
    for (let i = 0; i < 2; i++) {
      await pages[i].mouse.move(600, 400);
      await pages[i].mouse.wheel(0, -20000);
      await sleep(150);
      await pages[i].screenshot({ path: path.join(out, `final-${i}.png`) });
    }
    if (!process.env.MD_MAX_ACTIONS && !process.env.MD_VIEWPORT_ACCEPTANCE) {
      assert(completed, "match did not complete");
      assert(refreshed && reconnected);
      assert(
        counts.bought.every((x) => x > 0) && counts.sold.every((x) => x > 0),
      );
      assert.deepEqual(snaps[0].state, snaps[1].state);
    }
    if (process.env.MD_VIEWPORT_ACCEPTANCE)
      assert(
        counts.placed.every((x) => x > 0),
        "both narrow viewports must place",
      );
    const report = {
      viewportAcceptance: !!process.env.MD_VIEWPORT_ACCEPTANCE,
      completed,
      refreshed,
      reconnected,
      counts,
      errors,
      browser: browser.version(),
      finalVersion: snaps[0].state.version,
      commands: sent,
    };
    fs.writeFileSync(
      path.join(out, "result.json"),
      JSON.stringify(report, null, 2),
    );
    console.log(JSON.stringify(report));
  } catch (e) {
    for (let i = 0; i < pages.length; i++) {
      try {
        await pages[i].screenshot({ path: path.join(out, `failure-${i}.png`) });
      } catch {}
    }
    console.error(
      "BROWSER_ACCEPTANCE_FAILED",
      e.message,
      JSON.stringify(errors),
    );
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
  }
})();
