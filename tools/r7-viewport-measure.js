const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

function argsOf(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i += 2) out[argv[i].replace(/^--/, '')] = argv[i + 1];
  return out;
}

function selectorFor(el) {
  if (el.id) return `#${el.id}`;
  const parts = [];
  let node = el;
  while (node && node.nodeType === 1 && parts.length < 5) {
    let part = node.tagName.toLowerCase();
    if (node.classList && node.classList.length) part += `.${[...node.classList].slice(0, 2).join('.')}`;
    const siblings = node.parentElement ? [...node.parentElement.children].filter(x => x.tagName === node.tagName) : [];
    if (siblings.length > 1) part += `:nth-of-type(${siblings.indexOf(node) + 1})`;
    parts.unshift(part);
    node = node.parentElement;
  }
  return parts.join(' > ');
}

(async () => {
  const a = argsOf(process.argv);
  const width = Number(a.width);
  const height = Number(a.height);
  if (!a.html || !a.output || !a.screenshot || !width || !height) throw new Error('viewport_arguments_invalid');
  const { chromium } = require('playwright');
  const launch = { headless: true };
  if (a.browser && fs.existsSync(a.browser)) launch.executablePath = a.browser;
  const browser = await chromium.launch(launch);
  try {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    const failedRequests = [];
    page.on('requestfailed', request => failedRequests.push(request.url()));
    await page.goto(pathToFileURL(path.resolve(a.html)).href, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.evaluate(async () => {
      const images = [...document.images];
      await Promise.all(images.map(img => img.complete ? Promise.resolve() : new Promise(resolve => {
        const done = () => resolve();
        img.addEventListener('load', done, { once: true });
        img.addEventListener('error', done, { once: true });
        setTimeout(done, 5000);
      })));
      if (document.fonts && document.fonts.ready) await Promise.race([document.fonts.ready, new Promise(resolve => setTimeout(resolve, 5000))]);
    });
    const measurement = await page.evaluate(selectorSource => {
      const selectorFor = new Function('el', selectorSource);
      const root = document.documentElement;
      const clientWidth = root.clientWidth;
      const offenders = [];
      for (const el of document.querySelectorAll('body *')) {
        const style = getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') continue;
        const r = el.getBoundingClientRect();
        if (r.width > 0 && (r.right > clientWidth + 1 || r.left < -1)) offenders.push({ selector: selectorFor(el), left: r.left, right: r.right, width: r.width });
      }
      const failedImages = [...document.images].filter(img => !img.complete || img.naturalWidth === 0).map(img => img.currentSrc || img.src);
      return {
        document_client_width: clientWidth,
        document_scroll_width: root.scrollWidth,
        body_scroll_width: document.body ? document.body.scrollWidth : 0,
        overflow_offender_count: offenders.length,
        overflow_offenders: offenders.slice(0, 50),
        failed_image_count: failedImages.length,
        failed_images: failedImages,
        font_wait_status: 'settled_or_bounded_timeout'
      };
    }, selectorFor.toString().match(/\{([\s\S]*)\}$/)[1]);
    fs.mkdirSync(path.dirname(a.screenshot), { recursive: true });
    if (a.omitScreenshot !== 'true') await page.screenshot({ path: a.screenshot, fullPage: true });
    const result = {
      browser_invocation_status: 'succeeded',
      layout_measurement_status: 'measured',
      viewport_css_px: { width, height },
      page_url: pathToFileURL(path.resolve(a.html)).href,
      failed_request_count: failedRequests.length,
      failed_requests: failedRequests,
      ...measurement
    };
    fs.mkdirSync(path.dirname(a.output), { recursive: true });
    fs.writeFileSync(a.output, JSON.stringify(result, null, 2) + '\n', 'utf8');
  } finally {
    await browser.close();
  }
})().catch(error => {
  process.stderr.write(`R7_VIEWPORT_ERROR=${error && error.stack ? error.stack : error}\n`);
  process.exit(1);
});
