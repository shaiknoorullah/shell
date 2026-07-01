// Renders adhd-os.html to 1920x1080 stills + a walkthrough video.
// Uses Playwright's bundled chromium + ffmpeg. Run: node capture.mjs
import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import path from 'path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const url = 'file://' + path.join(dir, 'adhd-os.html');
const W = 1920, H = 1080;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 2,
  recordVideo: { dir, size: { width: W, height: H } },
});
const page = await ctx.newPage();
await page.goto(url);
await page.waitForTimeout(600); // fonts + stars

const shot = (name) => page.screenshot({ path: path.join(dir, name) });
const set = (s) => page.evaluate((x) => window.setState(x), s);
const pal = (o) => page.evaluate((x) => window.setPalette(x), o);
const cap = (t) => page.evaluate((x) => window.setCaption(x), t);
const isl = (o) => page.evaluate((x) => window.setIsland(x), o);

// ── Stills (deviceScaleFactor 2 → crisp 2x PNGs) ──
await set('idle');    await sleep(500); await shot('01-idle.png');
await isl(true);      await sleep(900); await shot('06-island-open.png'); await isl(false); await sleep(300);
await set('left');    await sleep(700); await shot('02-left.png');
await set('focus');   await sleep(700); await shot('03-focus.png');
await set('browser'); await sleep(600); await pal(true); await sleep(500); await shot('04-browser-palette.png');

// ── Walkthrough video ──
async function beat(state, caption, hold = 2600, palette = null) {
  await set(state);
  if (palette === false) await pal(false);
  await sleep(450);
  if (palette === true) { await pal(true); await sleep(450); }
  cap(caption);
  await sleep(hold);
  cap('');
  await sleep(250);
}
await pal(false);
await beat('idle',    'Top bar: only the essentials · bottom bar: your context + gentle, shame-free stats', 2600);
// Dynamic Island morph beat
await set('idle'); await sleep(300); cap('Top-center: a Dynamic Island — tap it…');
await sleep(1400); await isl(true); await sleep(2600); cap('…it morphs open into a full player + live deep-block activity');
await sleep(2200); await isl(false); cap(''); await sleep(700);
await beat('left',    'Summon the left bar — big timer to the next prayer, tasks, master AI agent, learn-in-the-gaps', 3600);
await beat('focus',   'Focus mode: everything else disappears — one block, one outcome', 3000);
await beat('browser', 'Zero-chrome browser — literally no tabs, no chrome, just the page', 2600, false);
await beat('browser', 'Press Space — everything is a calm, fuzzy overlay (Aether Canvas, Dracula-skinned)', 3400, true);
await sleep(400);

await ctx.close(); // flush video
await browser.close();
console.log('done');
