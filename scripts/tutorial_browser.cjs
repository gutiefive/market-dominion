#!/usr/bin/env node
/* Real-canvas local tutorial regression. Requires Playwright, Pillow and tesseract.
 * All moves use mouse/keyboard. No engine hooks, API moves, or private-state reads.
 */
const { chromium } = require("playwright");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const out = process.env.MD_BROWSER_EVIDENCE || "/tmp/md-tutorial-browser";
fs.mkdirSync(out, { recursive: true });
const result = path.join(out, "result.json");
if (fs.existsSync(result)) fs.unlinkSync(result);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let page;
async function read() {
  const image = path.join(out, "current.png");
  await page.screenshot({ path: image });
  const binary = path.join(out, "ocr.png");
  const primary = path.join(out, "primary-ocr.png");
  execFileSync("python3", [
    "-c",
    `from PIL import Image,ImageChops
import sys
im=Image.open(sys.argv[1]).convert('RGB');im=im.resize((im.width*2,im.height*2));gray=im.convert('L')
gray.point(lambda v:0 if v>110 else 255).save(sys.argv[2])
r,g,b=im.split()
m=ImageChops.multiply(ImageChops.multiply(r.point(lambda v:255 if v<100 else 0),g.point(lambda v:255 if v>130 else 0)),b.point(lambda v:255 if v>100 else 0))
text=Image.new('L',im.size,255);start=None
for y in range(im.height+1):
 active=y<im.height and sum(m.crop((0,y,im.width,y+1)).get_flattened_data())>255*40
 if active and start is None:start=y
 if not active and start is not None:
  if y-start>=20:
   box=m.crop((0,start,im.width,y)).getbbox()
   if box:
    rect=(box[0],start,box[2],y)
    text.paste(gray.crop(rect).point(lambda v:255 if v>90 else 0),rect)
  start=None
text.save(sys.argv[3])`,
    image,
    binary,
    primary,
  ]);
  let rows = [];
  for (const file of [binary, primary]) {
    const tsv = execFileSync(
      "tesseract",
      [file, "stdout", "--psm", "11", "tsv"],
      {
        encoding: "utf8",
        env: { ...process.env, OMP_THREAD_LIMIT: "1" },
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
    const groups = new Map();
    for (const line of tsv.trim().split("\n").slice(1)) {
      const c = line.split("\t");
      if (c[0] !== "5" || !c[11]?.trim()) continue;
      const key = c.slice(1, 5).join(":");
      const x = +c[6] / 2,
        y = +c[7] / 2,
        r = x + +c[8] / 2,
        b = y + +c[9] / 2;
      let group = groups.get(key);
      if (!group) {
        group = { text: "", x, y, r, b, words: [] };
        groups.set(key, group);
      }
      group.words.push({ text: c[11].replace(/\bAl\b/g, "AI"), x, y, r, b });
      group.text += (group.text ? " " : "") + c[11];
      group.x = Math.min(group.x, x);
      group.y = Math.min(group.y, y);
      group.r = Math.max(group.r, r);
      group.b = Math.max(group.b, b);
    }
    rows.push(
      ...[...groups.values()].map((g) => ({
        ...g,
        text: g.text.replace(/\bAl\b/g, "AI"),
      })),
    );
  }
  return rows;
}
async function click(pattern, rows = null) {
  for (let attempt = 0; attempt < 4; attempt++) {
    const current = rows || (await read());
    rows = null;
    let match = current.find((r) => pattern.test(r.text));
    if (!match) {
      const candidates = [];
      for (const line of current)
        for (let start = 0; start < line.words.length; start++)
          for (
            let length = 1;
            length <= 8 && start + length <= line.words.length;
            length++
          ) {
            const words = line.words.slice(start, start + length);
            const text = words.map((w) => w.text).join(" ");
            if (pattern.test(text))
              candidates.push({
                text,
                x: words[0].x,
                y: Math.min(...words.map((w) => w.y)),
                r: words.at(-1).r,
                b: Math.max(...words.map((w) => w.b)),
              });
          }
      match = candidates.sort((a, b) => b.y - a.y)[0];
    }
    if (match) {
      await page.mouse.click((match.x + match.r) / 2, (match.y + match.b) / 2);
      await sleep(200);
      return match.text;
    }
    await page.mouse.move(page.viewportSize().width - 20, 500);
    await page.mouse.wheel(0, attempt === 2 ? -3000 : 500);
    await sleep(150);
  }
  throw Error("Canvas control not found: " + pattern);
}
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_BIN || "/usr/bin/chromium",
    headless: true,
    args: [
      "--no-sandbox",
      "--enable-unsafe-swiftshader",
      "--disable-dev-shm-usage",
    ],
  });
  const requests = new Set();
  let completed = false,
    chart = false,
    bought = false,
    sold = false,
    turns = 0,
    events = 0,
    decisions = 0;
  try {
    const context = await browser.newContext({
      viewport: { width: 1280, height: 900 },
    });
    page = await context.newPage();
    const url =
      process.env.MD_BROWSER_WEB || "http://127.0.0.1:8097/index.html";
    page.on("request", (r) => requests.add(new URL(r.url()).origin));
    await page.goto(url);
    await sleep(5000);
    await click(/Learn Classic/);
    await click(/Look at your tiles/);
    for (let action = 0; action < 180; action++) {
      const rows = await read();
      const text = rows.map((r) => r.text).join("\n");
      if (/Action not applied|SCRIPT ERROR/i.test(text))
        throw Error("Game rejected a tutorial move");
      if (/Guided match complete/.test(text)) {
        completed = true;
        break;
      }
      if (
        /Round event/.test(text) &&
        rows.some((r) => /^Continue$/.test(r.text))
      ) {
        await click(/^Continue$/, rows);
        events++;
        continue;
      }
      if (/Confirm market action/.test(text)) {
        await click(/^Confirm$/, rows);
        continue;
      }
      if (/Found a company|Choose the surviving company/i.test(text)) {
        await click(
          /NOVA AI.*\bNA\b|ORBIT PAY.*\bOP\b|VOLT GRID.*\bVG\b|PULSE MEDIA.*\bPM\b|EVERMART.*\bEM\b/,
          rows,
        );
        decisions++;
        continue;
      }
      if (/Show a tile in my hand/.test(text)) {
        await click(/Show a tile in my hand/, rows);
        await click(/^Place selected$/);
        turns++;
        console.log("TUTORIAL_PLACEMENT", turns);
        continue;
      }
      if (/Pass the market/.test(text)) {
        if (!bought) {
          await click(/^Buy BYTE$/, rows);
          bought = true;
          continue;
        }
        if (bought && !sold && turns > 1) {
          await click(/^Sell BYTE$/, rows);
          sold = true;
          continue;
        }
        if (!chart && turns > 2) {
          await click(/^Price history$/, rows);
          const history = await read();
          assert(
            history.some((r) => /Recorded changes/.test(r.text)),
            "real history text missing",
          );
          await page.screenshot({
            path: path.join(out, "recorded-history.png"),
          });
          chart = true;
          if (process.env.MD_TUTORIAL_SMOKE) {
            const report = {
              completed: false,
              smoke: true,
              browser: browser.version(),
              placements: turns,
              boughtByte: bought,
              soldByte: sold,
              openedRecordedHistory: true,
            };
            fs.writeFileSync(result, JSON.stringify(report, null, 2));
            console.log(
              "M10_TUTORIAL_BROWSER_SMOKE_OK",
              JSON.stringify(report),
            );
            return;
          }
        }
        await click(/^Pass the market$/);
        continue;
      }
      throw Error("Unrecognized tutorial screen");
    }
    assert(completed, "tutorial did not finish");
    let final = (await read()).map((r) => r.text).join("\n");
    assert(
      /Market:/.test(final) && /Merger bonuses/.test(final),
      "post-match analysis missing",
    );
    assert(
      !/history\s+is\s+incomplete/.test(final),
      "cash reconciliation failed",
    );
    await page.screenshot({ path: path.join(out, "analysis-desktop.png") });
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(300);
    await page.screenshot({ path: path.join(out, "analysis-phone-top.png") });
    await page.mouse.move(200, 500);
    await page.mouse.wheel(0, 1500);
    await sleep(200);
    await page.screenshot({
      path: path.join(out, "analysis-phone-bottom.png"),
    });
    const bottom = (await read()).map((r) => r.text).join("\n");
    assert(
      /Play again|Back to lobby/.test(bottom),
      "phone standings actions unreachable",
    );
    assert(
      [...requests].every(
        (origin) => origin === new URL(url).origin || origin === "null",
      ),
      "unexpected external application request",
    );
    const report = {
      completed,
      automated: true,
      browser: browser.version(),
      placements: turns,
      eventDialogs: events,
      companyLabelClickAttempts: decisions,
      boughtByte: bought,
      soldByte: sold,
      openedRecordedHistory: chart,
      desktopAnalysis: true,
      phoneAnalysisActionsReachable: true,
      externalApplicationRequests: 0,
    };
    fs.writeFileSync(result, JSON.stringify(report, null, 2));
    console.log("M10_TUTORIAL_BROWSER_OK", JSON.stringify(report));
  } catch (e) {
    if (page)
      await page
        .screenshot({ path: path.join(out, "failure.png") })
        .catch(() => {});
    console.error("M10_TUTORIAL_BROWSER_FAILED", e.message);
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();
