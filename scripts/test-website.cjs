/* Run with Playwright and axe-core available through NODE_PATH. */
const { chromium, webkit } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const base = process.env.WEBSITE_URL || 'http://127.0.0.1:8767';
const out = process.env.WEBSITE_EVIDENCE || '/tmp/vowrite-website-evidence';
fs.mkdirSync(out, { recursive: true });
const results = [], errors = [], axeResults = [];
const pages = ['index','pricing'];
const consolidation = JSON.parse(fs.readFileSync(path.join(__dirname,'../docs/website-assets/content-consolidation.json')));
const axe = fs.readFileSync(require.resolve('axe-core/axe.min.js'),'utf8');
// Side-by-side evidence against the Open Design source (served at WEBSITE_DESIGN_URL).
async function compareDesign(browser) {
  const design = process.env.WEBSITE_DESIGN_URL;
  assert(design, 'WEBSITE_DESIGN_URL is required for --design');
  const dir = path.join(out, 'design-compare'); fs.mkdirSync(dir, {recursive:true});
  let png = null, pixelmatch = null;
  try { png = require('pngjs').PNG; pixelmatch = require('pixelmatch'); pixelmatch = pixelmatch.default || pixelmatch; } catch {}
  const report = [];
  for (const route of ['pricing','index']) for (const width of [1440,375]) for (const scheme of ['light','dark']) {
    const entry = {route, width, scheme};
    for (const [label, origin] of [['design', design], ['product', base]]) {
      const c = await browser.newContext({locale:'en-US', reducedMotion:'reduce', colorScheme:scheme, viewport:{width, height:1000}});
      const p = await c.newPage(); const pageErrors = [];
      p.on('pageerror', e => pageErrors.push(e.message));
      await p.goto(`${origin}/${route}.html`); await p.waitForLoadState('networkidle');
      await p.evaluate(() => { try { setLang('en'); } catch {} return document.fonts.ready; });
      const shot = path.join(dir, `${route}-${width}-${scheme}-${label}.png`);
      await p.screenshot({path:shot, fullPage:true});
      entry[label] = {shot, pageErrors, ...await p.evaluate(() => {
        const box = el => { const r = el.getBoundingClientRect(); return {top:Math.round(r.top + scrollY), height:Math.round(r.height)}; };
        const style = el => { const s = getComputedStyle(el); return {font:s.fontFamily.split(',')[0], size:s.fontSize, weight:s.fontWeight, color:s.color, background:s.backgroundColor}; };
        return {
          height: document.documentElement.scrollHeight,
          overflow: document.documentElement.scrollWidth > innerWidth + 1,
          overflowers: [...document.querySelectorAll('body *')].filter(e => (e.getBoundingClientRect().right > innerWidth + 1 || e.scrollWidth > e.clientWidth + 1 && getComputedStyle(e).overflowX === 'visible' && e.clientWidth > 0) && !e.parentElement.closest('.table-wrap,.compare-table-wrap')).slice(0, 8).map(e => e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (e.className && typeof e.className === 'string' ? '.' + e.className.trim().split(/\s+/).join('.') : '') + ' right=' + Math.round(e.getBoundingClientRect().right)),
          headings: [...document.querySelectorAll('main h1, main h2')].filter(h => h.offsetParent).map(h => ({tag:h.tagName, text:h.textContent.trim().replace(/\s+/g,' '), ...box(h), ...style(h)})),
          controls: [...document.querySelectorAll('main button, main select, main a.usage-link, main a.usage-download')].filter(e => e.offsetParent).length,
          body: style(document.body)
        };
      })};
      if (label === 'design' || label === 'product') entry[label].viewport = await p.screenshot({path:path.join(dir, `${route}-${width}-${scheme}-${label}-top.png`)});
      await c.close();
    }
    if (png && pixelmatch) {
      const a = png.sync.read(entry.design.viewport), b = png.sync.read(entry.product.viewport);
      const diff = new png({width:a.width, height:a.height});
      entry.firstViewportDiffRatio = Number((pixelmatch(a.data, b.data, diff.data, a.width, a.height, {threshold:0.1}) / (a.width * a.height)).toFixed(4));
      fs.writeFileSync(path.join(dir, `${route}-${width}-${scheme}-diff.png`), png.sync.write(diff));
    }
    delete entry.design.viewport; delete entry.product.viewport;
    report.push(entry);
  }
  fs.writeFileSync(path.join(dir, 'design-compare.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report.map(r => ({route:r.route, width:r.width, scheme:r.scheme, diff:r.firstViewportDiffRatio, heights:[r.design.height, r.product.height], errors:[...r.design.pageErrors, ...r.product.pageErrors], pageOverflow:{design:r.design.overflow, product:r.product.overflow}, productOverflowers:r.product.overflow ? r.product.overflowers : []})), null, 2));
}
(async () => {
  const browser = await chromium.launch({headless:true});
  if (process.argv.includes('--design')) { await compareDesign(browser); await browser.close(); return; }
  if (process.argv.includes('--links')) {
    const p = await browser.newPage(); const links = new Set();
    for (const route of pages) { await p.goto(`${base}/${route}.html`); (await p.locator('a[href^="http"]').evaluateAll(es => es.map(e => e.href))).forEach(h => links.add(h)); }
    const results = [];
    for (const url of [...links].sort()) {
      let status = 0;
      try { status = (await fetch(url, {redirect:'follow', headers:{'user-agent':'Mozilla/5.0 (Macintosh) VowriteLinkCheck'}, signal:AbortSignal.timeout(20000)})).status; } catch (e) { status = String(e.cause?.code || e.name); }
      results.push({url, status});
    }
    fs.writeFileSync(path.join(out, 'links.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results, null, 2));
    await browser.close(); if (results.some(r => !(r.status >= 200 && r.status < 400))) process.exitCode = 1; return;
  }
  const context = await browser.newContext({locale:'en-US',reducedMotion:'reduce'});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('response', r => { if(r.status() >= 400) errors.push(`${r.status()} ${r.url()}`); });
  if (!process.argv.includes('--interactions')) for (const route of pages) {
    await page.goto(`${base}/${route}.html`);
    await page.evaluate(async()=>{await Promise.all([...document.images].map(img=>{img.loading='eager';return img.decode().catch(()=>{})}))});
    for (const language of ['en','zh','de']) {
      await page.evaluate(l => setLang(l),language);
      for (const width of [375,600,768,1024,1440]) {
        await page.setViewportSize({width,height:960});
        for (const colorScheme of ['light','dark']) {
          await page.emulateMedia({colorScheme});
          await page.evaluate(() => document.querySelectorAll('details').forEach(d=>d.open=true));
          const status = await page.evaluate(() => ({
            overflow:document.documentElement.scrollWidth > innerWidth + 1,
            width:innerWidth, scroll:document.documentElement.scrollWidth,
            h1:document.querySelectorAll('h1').length,
            lang:document.documentElement.lang,
            duplicateIds:[...document.querySelectorAll('[id]')].map(x=>x.id).filter((v,i,a)=>a.indexOf(v)!==i),
            brokenImages:[...document.images].filter(x=>!x.complete || !x.naturalWidth).map(x=>x.src),
            invisiblePlatformActions:[...document.querySelectorAll('.home-platform-actions a')].filter(e=>getComputedStyle(e).color===getComputedStyle(e).backgroundColor).map(e=>e.textContent)
          }));
          results.push({route,language,width,colorScheme,...status});
        }
      }
    }
    await page.evaluate(()=>setLang('en'));
    await page.setViewportSize({width:1440,height:1000});
    for(const colorScheme of ['light','dark']) {
      await page.emulateMedia({colorScheme});
      await page.addScriptTag({content:axe});
      const result = await page.evaluate(async()=>await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));
      axeResults.push({route,colorScheme,violations:result.violations.map(v=>({id:v.id,impact:v.impact,description:v.description,nodes:v.nodes.map(n=>({html:n.html,target:n.target,summary:n.failureSummary}))}))});
    }
    for(const language of ['en','zh','de']) {
      await page.evaluate(l=>setLang(l),language);
      for(const width of [375,1440]) {
        await page.setViewportSize({width,height:1000});await page.emulateMedia({colorScheme:'light'});
        await page.evaluate(()=>{document.querySelectorAll('details').forEach(d=>d.open=false);scrollTo(0,0)});
        await page.screenshot({path:path.join(out,`${route}-${language}-${width}.png`),fullPage:true});
      }
    }
    // 200% zoom includes the longest language and all expanded content.
    await page.setViewportSize({width:1440,height:1000});
    await page.evaluate(()=>{setLang('de');document.body.style.zoom='2';document.querySelectorAll('details').forEach(d=>d.open=true)});
    results.push({route,test:'zoom-200',...await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth+1,width:innerWidth,scroll:document.documentElement.scrollWidth}))});
    await page.evaluate(()=>document.body.style.zoom='');
  }
  if (!process.argv.includes('--interactions')) fs.writeFileSync(path.join(out,'browser-matrix.json'),JSON.stringify({results,errors,axeResults},null,2));
  const failures=results.filter(x=>x.overflow||x.h1>1||x.duplicateIds?.length||x.brokenImages?.length||x.invisiblePlatformActions?.length);
  console.log(JSON.stringify({matrix:results.length,layoutFailures:failures,errors,axe:axeResults.map(x=>({route:x.route,color:x.colorScheme,violations:x.violations.map(v=>({id:v.id,nodes:v.nodes.length}))}))},null,2));
  const interactions = [];
  async function test(name, fn) {
    try { await fn(); interactions.push({name,passed:true}); }
    catch(e) { interactions.push({name,passed:false,error:e.message}); }
  }
  await test('language menu, mobile navigation, persistence and Escape focus',async()=>{
    await page.setViewportSize({width:375,height:900});await page.goto(`${base}/index.html`);
    await page.locator('.lang-toggle').click();await page.locator('.lang-menu [data-lang="de"]').click();
    assert.equal(await page.locator('html').getAttribute('lang'),'de');
    await page.locator('.nav-menu-toggle').click();await page.locator('.nav-links a[href="pricing.html"]').click();
    assert.equal(await page.locator('html').getAttribute('lang'),'de');
    await page.locator('.nav-menu-toggle').click();await page.keyboard.press('Escape');
    assert.equal(await page.locator('.nav-menu-toggle').getAttribute('aria-expanded'),'false');
    assert(await page.locator('.nav-menu-toggle').evaluate(e=>e===document.activeElement));
    await page.locator('.lang-toggle').click();await page.keyboard.press('Home');await page.keyboard.press('Enter');
    assert.equal(await page.locator('html').getAttribute('lang'),'en');
  });
  await test('rich translations retain shortcut markup and real links in every language',async()=>{
    await page.goto(`${base}/index.html#platforms`);
    for(const l of ['en','zh','de','en']) {
      await page.evaluate(l=>setLang(l),l);
      assert(await page.locator('[data-i18n="ap.mac.flow.note"] kbd').count()>=2);
      assert.equal(await page.locator('[data-i18n="ap.mac.flow.note"] a').getAttribute('href'),'index.html#translation-triggers');
      assert.equal(await page.locator('[data-i18n="ap.ios.flow.note"] a').getAttribute('href'),'index.html#translation-triggers');
    }
  });
  await test('all four original translation samples, pause, reduced motion',async()=>{
    await page.goto(`${base}/index.html#translation`);
    const baseline=JSON.parse(fs.readFileSync(path.join(__dirname,'../docs/website-assets/content-baseline.json')));
    for(let i=0;i<4;i++) {
      await page.locator(`button.tr-demo-dot[data-i="${i}"]`).click();
      assert.equal(await page.locator('#trDemoIn').textContent(),baseline.samples[i].textIn);
      assert.equal(await page.locator('#trDemoOut').textContent(),baseline.samples[i].textOut);
    }
    await page.emulateMedia({reducedMotion:'no-preference'});await page.waitForTimeout(4400);
    assert.equal(await page.locator('#trDemoOut').textContent(),baseline.samples[3].textOut);
    await page.emulateMedia({reducedMotion:'reduce'});
  });
  await test('desktop demo: all scenes, all stages, copy success and rejection',async()=>{
    await context.grantPermissions(['clipboard-read','clipboard-write']);
    await page.goto(`${base}/index.html#live-demo`);await page.evaluate(()=>setLang('en'));
    for(let scene=0;scene<3;scene++) {
      await page.locator(`#live-demo button[data-scene="${scene}"]`).click();
      for(let i=0;i<5;i++)await page.locator('#live-demo [data-next]').click();
      assert.equal(await page.locator('#live-demo').getAttribute('data-stage'),'5');
      assert((await page.locator('#live-demo [data-result]').textContent()).length>20);
    }
    await page.locator('#live-demo [data-copy]').click();await page.waitForFunction(()=>document.querySelector('#live-demo [data-feedback]').textContent.length>0);
    assert.match(await page.locator('#live-demo [data-feedback]').textContent(),/copied/i);
    await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw new Error('denied')}}}));
    await page.locator('#live-demo [data-copy]').click();await page.waitForFunction(()=>document.querySelector('#live-demo [data-feedback]').textContent.length>0);
    assert(!/copied/i.test(await page.locator('#live-demo [data-feedback]').textContent()));
    assert((await page.evaluate(()=>getSelection().toString())).length>20);
  });
  await test('dictation, refinement, app styles and provider configuration demos',async()=>{
    await page.goto(`${base}/index.html`);await page.evaluate(()=>setLang('en'));
    await page.locator('[data-hc-dict]').click();assert.match(await page.locator('[data-hc-dict-output]').textContent(),/Thursday/);
    await page.locator('[data-vc-action="clean"]').click();await page.waitForTimeout(50);
    assert.match(await page.locator('#vc-clean .vc-result').textContent(),/Thursday/);
    await page.locator('#vc-style [data-vc-action="scene"][data-value="1"]').click();
    assert.match(await page.locator('#vc-style .vc-paper').textContent(),/Hi team/);
    await page.locator('[data-hc-add]').click();assert.match(await page.locator('[data-hc-provider-status]').textContent(),/Choose/);
    await page.locator('[data-hf-provider="recognition"]').selectOption('Groq');await page.locator('[data-hf-provider="writing"]').selectOption('Ollama');
    await page.locator('[data-hc-add]').click();assert.equal(await page.locator('[data-hc-added] li').count(),2);
    assert.equal(await page.locator('option[value="Sherpa"]').count(),0);
  });
  await test('important features, translation examples and both platforms are visible without disclosure clicks',async()=>{
    await page.goto(`${base}/index.html`);
    for(const id of [...consolidation.visibleModules,...consolidation.visibleTranslation,'platform-mac','platform-ios']) {
      assert(await page.locator('#'+id).isVisible(),`${id} must be visible`);
      assert(await page.locator('#'+id).evaluate(e=>!e.closest('details')),`${id} must not be inside an accordion`);
    }
    assert.equal(await page.locator('#translation .tr-demo-card').count(),1);
    assert.equal(await page.locator('.vc-body#vc-translate,.site-overview,.vc-faq').count(),0);
    assert.equal(await page.locator('#faq .faq-item').count(),7);
    for(const route of pages) {
      await page.goto(`${base}/${route}.html`);
      assert.deepEqual(await page.locator('#site-navigation a').evaluateAll(es=>es.map(e=>e.getAttribute('href'))),['index.html#features','index.html#platforms','pricing.html','index.html#download']);
      assert.equal(await page.locator('a[href^="apps.html"],a[href^="translate.html"],a[href^="why.html"]').count(),0);
    }
  });
  await test('all legacy routes and old anchors preserve query, language and access to canonical content',async()=>{
    await page.goto(`${base}/index.html`);await page.evaluate(()=>setLang('de'));
    for(const [route,mapping] of Object.entries(consolidation.legacyRoutes)) for(const [hash,target] of Object.entries(mapping)) {
      await page.goto(`${base}/${route}.html?campaign=compatibility&keep=1${hash?'#'+encodeURIComponent(hash):''}`);
      await page.waitForURL(url=>url.pathname.endsWith('/index.html')&&url.hash==='#'+target);
      assert.equal(new URL(page.url()).search,'?campaign=compatibility&keep=1');
      assert.equal(await page.locator('html').getAttribute('lang'),'de');
      assert.equal(await page.locator('#'+target).count(),1);
      assert(await page.locator('#'+target).evaluate(e=>{for(let p=e;p;p=p.parentElement)if(p.tagName==='DETAILS'&&!p.open)return false;return true}));
    }
    await page.goto(`${base}/pricing.html`);
    await page.locator('.footer-links a[href="index.html#platforms"]').click();
    await page.goBack();assert(new URL(page.url()).pathname.endsWith('pricing.html'));
    await page.goForward();assert.equal(new URL(page.url()).hash,'#platforms');
  });
  await test('usage page: examples, independent providers, live summary, languages and all 77 archived rows',async()=>{
    await page.setViewportSize({width:1440,height:1000});
    await page.goto(`${base}/pricing.html`);await page.evaluate(()=>setLang('en'));
    await page.waitForFunction(()=>document.querySelector('.usage-page').dataset.usageReady==='true');
    const text=selector=>page.locator(selector).textContent();
    assert.equal(await page.locator('[data-usage-control]:disabled').count(),0);
    assert.equal(await page.locator('option[value="sherpa"]').count(),0);
    assert.equal(await text('#usage-combination-name'),'Groq → DeepSeek');
    assert.equal(await page.locator('[data-usage-example="cloud"]').getAttribute('aria-pressed'),'true');
    await page.locator('[data-usage-example="dictation"]').click();
    assert.equal(await text('#usage-combination-name'),'Groq · Dictation only');
    assert.equal(await text('#usage-writing-location'),'Off');
    assert(await page.locator('[data-usage-writing-icon]').evaluate(e=>e.hidden&&!e.offsetParent));
    await page.locator('[data-usage-example="local"]').click();
    assert.equal(await text('#usage-combination-name'),'Groq → Ollama');
    assert.equal(await text('#usage-writing-location'),'Local');
    assert.match(await text('#usage-writing-billing'),/no cloud API fee/);
    assert.equal(await page.locator('[data-usage-example][aria-pressed="true"]').count(),1);
    await page.locator('#usage-flow-speech').selectOption('deepgram');
    assert.equal(await page.locator('[data-usage-example][aria-pressed="true"]').count(),0);
    assert.match(await page.locator('[data-usage-speech-icon]').getAttribute('src'),/assets\/providers\/deepgram\.svg$/);
    await page.locator('#usage-writing').selectOption('anthropic');
    assert.equal(await text('#usage-combination-name'),'Deepgram → Anthropic');
    assert.equal(await text('#usage-combination-detail'),'Deepgram handles recognition in the cloud. Anthropic bills input and output tokens separately.');
    await page.waitForFunction(()=>document.getElementById('usage-live').textContent.startsWith('Deepgram → Anthropic.'));
    assert(await page.evaluate(()=>[...document.querySelectorAll('.usage-brand')].every(i=>i.hidden||i.naturalWidth>0)));
    await page.evaluate(()=>setLang('zh'));
    assert.equal(await text('[data-usage="heroUsage"]'),'用多少，付多少。');
    assert.equal(await text('#usage-combination-detail'),'Deepgram 在云端完成语音识别。 Anthropic 按输入和输出 Token 另行计费。');
    assert.equal(await page.locator('#usage-live').textContent(),'');
    await page.evaluate(()=>setLang('de'));
    assert.equal(await text('[data-usage="exampleLocal"]'),'Lokal bearbeiten');
    assert.equal(await text('#usage-writing-location'),'Cloud-API');
    await page.evaluate(()=>setLang('en'));
    for(const summary of await page.locator('.usage-principle>summary,.usage-faq-item>summary').all()){
      await summary.click();assert(await summary.evaluate(s=>s.parentElement.open&&s.nextElementSibling.offsetHeight>0));
    }
    await page.locator('a.usage-link[href="#usage-providers"]').click();await page.waitForURL(u=>u.hash==='#usage-providers');
    assert(await page.locator('#usage-provider-title').evaluate(e=>{const r=e.getBoundingClientRect();return r.top>=0&&r.top<innerHeight}));
    await page.locator('#provider-reference > summary').click();
    assert.equal(await page.locator('#provider-reference tbody tr').count(),77);
    assert(await page.locator('#provider-reference table').first().isVisible());
    assert(!await page.locator('.estimate-card').first().isVisible());
    await page.locator('.usage-archived-estimates > summary').click();assert(await page.locator('.estimate-card').first().isVisible());
    assert.equal(await page.locator('.usage-download').getAttribute('href'),'index.html#download');
    await page.locator('.usage-combination a.usage-link').click();await page.waitForURL(u=>u.pathname.endsWith('/index.html')&&u.hash==='#download-mac');
    assert(await page.locator('#download-mac').evaluate(e=>{for(let p=e;p;p=p.parentElement)if(p.tagName==='DETAILS'&&!p.open)return false;return true}));
  });
  await test('normal motion: demo playback, typing, pause/resume/replay, carousel, refine, menu and disclosure animations',async()=>{
    const c=await browser.newContext({locale:'en-US',reducedMotion:'no-preference',viewport:{width:1440,height:1000}});const p=await c.newPage();
    const motionErrors=[];p.on('pageerror',e=>motionErrors.push(e.message));
    await p.goto(`${base}/index.html#live-demo`);await p.evaluate(()=>setLang('en'));
    const demo=p.locator('#live-demo');
    await p.evaluate(()=>{window.__typing={raw:[],result:[]};const root=document.querySelector('#live-demo');new MutationObserver(()=>{const raw=root.querySelector('[data-raw]').textContent.length,result=root.querySelector('[data-result]').textContent.length;const t=window.__typing;if(t.raw.at(-1)!==raw)t.raw.push(raw);if(t.result.at(-1)!==result)t.result.push(result)}).observe(root,{subtree:true,childList:true,characterData:true})});
    await demo.locator('[data-play]').click();
    assert.equal(await demo.getAttribute('data-running'),'true');
    await p.waitForFunction(()=>document.querySelector('#live-demo').dataset.stage==='2');
    await demo.locator('[data-play]').click();
    const held={stage:await demo.getAttribute('data-stage'),status:await demo.locator('[data-status]').textContent()};
    assert.equal(await demo.getAttribute('data-running'),'false');
    await p.waitForTimeout(900);
    assert.deepEqual({stage:await demo.getAttribute('data-stage'),status:await demo.locator('[data-status]').textContent()},held);
    await demo.locator('[data-play]').click();
    await p.waitForFunction(()=>document.querySelector('#live-demo').dataset.stage==='5',null,{timeout:10000});
    assert.equal(await demo.getAttribute('data-running'),'false');
    assert(!await demo.locator('[data-copy]').isDisabled());
    const typing=await p.evaluate(()=>window.__typing);
    assert(typing.raw.filter(n=>n>1).length>=5,'raw transcript should type progressively');
    assert(typing.result.filter(n=>n>1).length>=5,'refined result should type progressively');
    assert(await demo.locator('.vw-wave').evaluate(e=>getComputedStyle(e,'::after').animationName.includes('vw-refined-done')));
    await demo.locator('[data-replay]').click();assert.equal(await demo.getAttribute('data-stage'),'0');
    await p.goto(`${base}/index.html#translation`);
    const first=await p.locator('#trDemoOut').textContent();
    await p.waitForFunction(f=>document.querySelector('#trDemoOut').textContent!==f,first,{timeout:6000});
    assert(await p.locator('#trDemoRow').evaluate(e=>e.classList.contains('tr-demo-fade')&&getComputedStyle(e).animationName!=='none'));
    await p.locator('#translation .tr-demo-pause').click();
    const pausedOut=await p.locator('#trDemoOut').textContent();await p.waitForTimeout(4700);
    assert.equal(await p.locator('#trDemoOut').textContent(),pausedOut);
    await p.locator('#translation .tr-demo-pause').click();
    await p.waitForFunction(f=>document.querySelector('#trDemoOut').textContent!==f,pausedOut,{timeout:6000});
    await p.goto(`${base}/index.html#cleanup`);
    await p.locator('#vc-clean [data-vc-action="clean"]').click();
    assert(await p.locator('#vc-clean [data-vc-action="clean"]').isDisabled());
    await p.waitForFunction(()=>/Thursday/.test(document.querySelector('#vc-clean .vc-result')?.textContent||''),null,{timeout:3000});
    await p.locator('.lang-toggle').click();
    assert(await p.locator('.lang-menu').evaluate(e=>e.getAnimations().some(a=>a.animationName==='vh-menu-in')));
    await p.keyboard.press('Escape');
    await p.goto(`${base}/pricing.html#usage-faq`);
    const chevron=p.locator('.usage-faq-item').first().locator('.usage-details-chevron');
    const closed=await chevron.evaluate(e=>getComputedStyle(e).transform);
    await p.locator('.usage-faq-item>summary').first().click();await p.waitForTimeout(260);
    assert.notEqual(await chevron.evaluate(e=>getComputedStyle(e).transform),closed);
    assert.deepEqual(motionErrors,[]);await c.close();
  });
  await test('command copy success and manual fallback',async()=>{
    await page.goto(`${base}/index.html#download`);
    await page.evaluate(()=>setLang('en'));
    await page.locator('.download-note .site-copy').click();await page.waitForFunction(()=>document.querySelector('.download-note .site-copy-feedback').textContent.length>0);assert.equal(await page.locator('.download-note .site-copy-feedback').textContent(),'Copied');
    await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw new Error('denied')}}}));
    await page.locator('.download-note .site-copy').click();await page.waitForFunction(()=>document.querySelector('.download-note .site-copy-feedback').textContent.length>0);assert.match(await page.locator('.download-note .site-copy-feedback').textContent(),/manually/);
    assert.equal(await page.evaluate(()=>getSelection().toString()),'cd Vowrite/VowriteMac && swift build');
  });
  await test('old homepage anchors open their containing detail panels',async()=>{
    for(const id of ['how-it-works','compare','download-mac','translation-triggers','vc-translate']){
      await page.goto(`${base}/index.html#${id}`);
      assert(await page.locator(`#${id}`).evaluate(el=>{for(let p=el;p;p=p.parentElement)if(p.tagName==='DETAILS'&&!p.open)return false;return true}));
    }
  });
  await test('no JavaScript: complete content and navigation remain usable',async()=>{
    const c=await browser.newContext({javaScriptEnabled:false,viewport:{width:375,height:900}});const p=await c.newPage();
    for(const route of pages){await p.goto(`${base}/${route}.html`);assert(await p.locator('.nav-links a[href="index.html#platforms"]').isVisible());assert(await p.locator('h1').isVisible());}
    assert(await p.locator('.usage-nojs').isVisible());assert.equal(await p.locator('[data-usage-control]:not([disabled])').count(),0);
    assert.equal(await p.locator('#usage-combination-name').textContent(),'Groq → DeepSeek');
    await p.locator('.va-history > summary').click();assert(await p.locator('.va-history table').first().isVisible());await c.close();
  });
  await test('legacy entries provide working fallback links with JavaScript disabled',async()=>{
    const c=await browser.newContext({javaScriptEnabled:false,viewport:{width:375,height:900}});const p=await c.newPage();
    for(const [route,mapping] of Object.entries(consolidation.legacyRoutes)){
      await p.goto(`${base}/${route}.html`);
      await Promise.all([p.waitForURL(u=>u.pathname.endsWith('/index.html')),p.locator('[data-redirect-target]').click()]);await p.waitForLoadState('load');
      assert.equal(new URL(p.url()).hash,'#'+mapping['']);
      assert(await p.locator('h1').isVisible());
    }
    const q=await c.newPage();await q.goto(`${base}/index.html#platforms`,{waitUntil:'load'});
    // Smooth hash scrolling (normal motion) restarts on each Playwright scroll retry; motion is covered separately.
    await q.evaluate(()=>{document.documentElement.style.scrollBehavior='auto'});
    for(let last=-1,same=0;same<3;){const y=await q.evaluate(()=>scrollY);same=y===last?same+1:0;last=y;await q.waitForTimeout(150);}
    await q.locator('#ios-details>summary').click();
    assert(await q.locator('#download-ios pre').isVisible());await c.close();
  });
  await test('blocked storage and failed i18n resource keep navigation and content',async()=>{
    const c=await browser.newContext({viewport:{width:375,height:900}});await c.addInitScript(()=>{Object.defineProperty(window,'localStorage',{get(){throw new Error('blocked')}})});
    const p=await c.newPage();await p.goto(`${base}/index.html#platforms`);await p.locator('.lang-toggle').click();await p.locator('[data-lang="zh"]').click();assert.equal(await p.locator('html').getAttribute('lang'),'zh-CN');
    await p.route('**/i18n.js',r=>r.abort());await p.goto(`${base}/index.html`);assert(await p.locator('.nav-links a[href="index.html#platforms"]').isVisible());assert(await p.locator('h1').isVisible());await c.close();
  });
  await test('WebKit: canonical pages and redirected entries, mobile dark layout and language switching',async()=>{
    const b=await webkit.launch();const p=await b.newPage({viewport:{width:375,height:900},colorScheme:'dark',reducedMotion:'reduce'});
    const failures=[];p.on('pageerror',e=>failures.push(e.message));
    for(const route of [...pages,...Object.keys(consolidation.legacyRoutes)]){await p.goto(`${base}/${route}.html`);await p.waitForFunction(()=>typeof setLang==='function');await p.evaluate(()=>{setLang('de');document.querySelectorAll('details').forEach(x=>x.open=true)});assert(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));}
    assert.deepEqual(failures,[]);await b.close();
  });
  fs.writeFileSync(path.join(out,'interactions.json'),JSON.stringify(interactions,null,2));
  console.log(JSON.stringify({interactions},null,2));
  if(interactions.some(x=>!x.passed))process.exitCode=1;

  await browser.close();
  if(failures.length||errors.length||axeResults.some(x=>x.violations.length))process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
