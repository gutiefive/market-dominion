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
  for (const [file, mode] of [[binary, "11"], [primary, "11"], [primary, "6"]]) {
    const tsv = execFileSync(
      "tesseract",
      [file, "stdout", "--psm", mode, "tsv"],
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
    const candidates = current.filter((r) => pattern.test(r.text));
    {
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
    }
    const match = candidates.sort((a, b) => b.y - a.y)[0];
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
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || "/usr/bin/chromium", headless: true,
    args: ["--no-sandbox", "--enable-unsafe-swiftshader", "--disable-dev-shm-usage"] });
  const requests = new Set();
  // An acceptance itinerary, executed only through visible canvas controls.
  const itinerary = [
    ["place", "A1"], ["buy_byte"], ["sell_byte"], ["demo"], ["event"],
    ["place", "A2"], ["founder", "NOVA AI"], ["buy_share", "NA"], ["sell_share", "NA"], ["demo"], ["event"],
    ["place", "C1"], ["pass"], ["pass"], ["demo"], ["event"],
    ["place", "C2"], ["founder", "VOLT GRID"], ["buy_share", "VG"], ["buy_share", "NA"], ["demo"], ["event"],
    ["place", "B2"], ["survivor", "NOVA AI"], ["buy_byte"], ["pass"], ["demo"], ["event"],
    ["place", "A3"], ["sell_byte"], ["pass"], ["demo"], ["event"], ["fast_forward"],
    ["place", "A8"], ["pass"], ["pass"], ["demo"], ["finish"]
  ];
  let teachingSteps = 0, placements = 0, events = 0;
  try {
    page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const url = process.env.MD_BROWSER_WEB || "http://127.0.0.1:8097/index.html";
    page.on("request", r => requests.add(new URL(r.url()).origin));
    await page.goto(url);
    await sleep(5000);
    await click(/Learn Classic/);
    await click(/Look at your tiles/);
    for (const [action, arg] of itinerary) {
      if (teachingSteps === 0 || teachingSteps === 6) {
        await page.setViewportSize(teachingSteps === 0 ? { width: 1024, height: 768 } : { width: 390, height: 844 });
        await sleep(400);
      }
      const rows = await read();
      const text = rows.map(row => row.text).join("\n");
      assert(new RegExp("Lesson " + (teachingSteps + 1) + "\\s*/\\s*39").test(text), "Teaching step missing: " + (teachingSteps + 1) + "\n" + text);
      assert(!/Action not applied|SCRIPT ERROR/i.test(text), "tutorial rejected a move");
      if ([6, 16, 23, 33, 38].includes(teachingSteps))
        await page.screenshot({ path: path.join(out, `lesson-${teachingSteps + 1}.png`) });
      if (action === "demo") await click(/^Watch Ada$/, rows);
      else if (action === "event") { await click(/have read the event/, rows); events++; }
      else if (action === "fast_forward") await click(/Watch the middle game/, rows);
      else if (action === "finish") await click(/Review final standings/, rows);
      else {
        await click(/^Try this step$/, rows);
        if (teachingSteps === 0 || teachingSteps === 6)
          await page.screenshot({ path: path.join(out, teachingSteps === 0 ? "tablet-placement.png" : "phone-founding.png") });
        if (action === "place") {
          await page.keyboard.press("1");
          await click(/^Place selected$/);
          placements++;
        } else if (action === "founder" || action === "survivor") {
          await click(new RegExp(arg));
        } else if (action === "pass") {
          // This explicitly labelled lesson control passes exactly one action;
          // unlike the ordinary market-pass control, it cannot skip the course.
          await click(/^Pass one lesson action$/);
        } else {
          if (arg) {
            // Canvas-only fallback: these desktop footer coordinates are for
            // 1280x900 at the default text scale. OCR confuses ticker labels on
            // the board with the adjacent trade controls. No game-state hook.
            const y = page.viewportSize().height - 102;
            const threeCompanies = teachingSteps >= 18;
            await page.mouse.click(arg === "VG" ? 154 : 46, y);
            await sleep(250);
            await page.mouse.click(action === "sell_share" ? 218 : (threeCompanies ? 230 : 123), y);
            await sleep(250);
          } else {
            const opening = teachingSteps < 3;
            const x = action === "buy_byte" ? (opening ? 67 : 370) : (opening ? 161 : 465);
            await page.mouse.click(x, page.viewportSize().height - 102);
            await sleep(250);
          }
          await click(/^Confirm$/);
        }
      }
      if (teachingSteps === 0 || teachingSteps === 6) {
        await page.setViewportSize({ width: 1280, height: 900 });
        await sleep(300);
      }
      teachingSteps++;
      console.log("SCRIPTED_LESSON", teachingSteps, action, arg || "");
      if (process.env.MD_TUTORIAL_SMOKE && teachingSteps === 5) {
        fs.writeFileSync(result, JSON.stringify({ completed: false, smoke: true, browser: browser.version(), teachingSteps, placements, eventLessons: events, boughtByte: true, soldByte: true }, null, 2));
        console.log("M10_TUTORIAL_BROWSER_SMOKE_OK");
        return;
      }
    }
    const final = (await read()).map(row => row.text).join("\n");
    assert(/Guided match complete/.test(final) && /Merger bonuses/.test(final), "final analysis missing");
    assert(!/history\s+is\s+incomplete/.test(final), "cash reconciliation failed");
    await page.screenshot({ path: path.join(out, "analysis-desktop.png") });
    await page.setViewportSize({ width: 390, height: 844 });
    await sleep(400);
    await page.screenshot({ path: path.join(out, "analysis-phone-top.png") });
    await page.mouse.move(200, 500);
    await page.mouse.wheel(0, 1800);
    await sleep(250);
    assert(/Play again|Back to lobby/.test((await read()).map(row => row.text).join("\n")), "phone standings actions unreachable");
    assert([...requests].every(origin => origin === new URL(url).origin || origin === "null"), "unexpected external application request");
    const report = { completed: true, automated: true, scripted: true, browser: browser.version(), teachingSteps, humanPlacements: placements,
      eventLessons: events, companyFoundings: 2, tiedMerger: true, boughtAndSoldShares: true, boughtAndSoldByte: true,
      middleGameDemonstration: true, finalRound: true, tabletViewportPlacement: true, phoneViewportFounding: true, desktopAnalysis: true, phoneAnalysisActionsReachable: true,
      externalApplicationRequests: 0, tradeInput: "Fixed 1280x900 footer coordinates at default text scale; subsequent lesson transitions verified by OCR", limitation: "Automated desktop Chromium canvas interaction; not human comprehension or physical-device acceptance." };
    fs.writeFileSync(result, JSON.stringify(report, null, 2));
    console.log("M10_TUTORIAL_BROWSER_OK", JSON.stringify(report));
  } catch (error) {
    if (page) await page.screenshot({ path: path.join(out, "failure.png") }).catch(() => {});
    console.error("M10_TUTORIAL_BROWSER_FAILED", error.message);
    process.exitCode = 1;
  } finally { await browser.close(); }
})();
