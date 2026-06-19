import { chromium } from 'playwright';

const url = process.argv[2] || 'http://localhost:9090';
const browser = await chromium.launch();
const page = await browser.newPage();

const consoleMsgs = [];
page.on('console', (msg) => {
  consoleMsgs.push(`[${msg.type()}] ${msg.text()}`);
});
page.on('pageerror', (err) => {
  consoleMsgs.push(`[pageerror] ${err.message}`);
});

console.log(`Navigating to ${url}...`);
await page.goto(url, { waitUntil: 'load', timeout: 60000 });
await page.waitForTimeout(8000); // let flutter boot

await page.screenshot({ path: '.claude/screenshots/01_initial.png', fullPage: true });
console.log('Screenshot saved: 01_initial.png');

console.log('--- Console messages so far ---');
console.log(consoleMsgs.join('\n'));

await browser.close();
