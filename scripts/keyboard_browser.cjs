#!/usr/bin/env node
// Real Godot canvas input; OCR verifies visible phases without engine hooks.
const { chromium } = require('playwright');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const out = process.env.MD_BROWSER_EVIDENCE || '/tmp/md-keyboard-browser';
fs.mkdirSync(out, { recursive: true });
const result = path.join(out, 'result.json');
if (fs.existsSync(result)) fs.unlinkSync(result);
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--disable-dev-shm-usage'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    async function read(name) {
      await page.waitForTimeout(700);
      const file = path.join(out, name + '.png');
      await page.screenshot({ path: file });
      const primary = path.join(out, name + '-primary.png');
      execFileSync('python3', ['-c', `from PIL import Image,ImageChops
import sys
im=Image.open(sys.argv[1]).convert('RGB');im=im.resize((im.width*2,im.height*2));gray=im.convert('L')
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
text.save(sys.argv[2])`, file, primary]);
      return [file, primary].map(image => execFileSync('tesseract', [image, 'stdout', '--psm', '11'], {
        encoding: 'utf8', env: { ...process.env, OMP_THREAD_LIMIT: '1' }, stdio: ['ignore', 'pipe', 'ignore'] })).join('\n');
    }
    await page.goto(process.env.MD_BROWSER_WEB || 'http://127.0.0.1:8097/index.html');
    await page.waitForTimeout(5000);
    assert.match(await read('menu'), /Learn Classic/i);
    // The canvas needs browser focus; Tab enters it without choosing a game action.
    await page.locator('canvas').focus();
    await page.keyboard.press('Enter');
    assert.match(await read('order'), /Look at your tiles/i);
    await page.keyboard.press('Enter');
    assert.match(await read('table'), /Your hand and the board/i);
    await page.keyboard.press('r');
    assert.match(await read('rules'), /How Market Dominion plays/i);
    for (let i = 0; i < 6; i++) await page.keyboard.press(i % 2 ? 'Shift+Tab' : 'Tab');
    await page.keyboard.press('Escape');
    assert.doesNotMatch(await read('closed-rules'), /How Market Dominion plays/i);
    await page.keyboard.press('Tab');
    await page.keyboard.press('Enter');
    await page.keyboard.press('1');
    await page.keyboard.press('Enter');
    assert.match(await read('market'), /Cash becomes a holding/i);
    fs.writeFileSync(result, JSON.stringify({ browser: browser.version(), keyboardMenu: true, keyboardTurnOrder: true,
      rulesOpenedAndClosed: true, tileShortcutAndEnter: true, completedMatch: false,
      limitation: 'Desktop Chromium keyboard canvas regression; not a human or screen-reader playtest.' }, null, 2) + '\n');
    console.log('KEYBOARD_BROWSER_OK');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
