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
(async () => {
  const browser = await chromium.launch({headless:true});
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
  await test('pricing slider and all 77 archived provider rows',async()=>{
    await page.goto(`${base}/pricing.html`);
    await page.locator('#va-volume').fill('200');await page.locator('#va-rate').fill('75');
    assert.equal(await page.locator('#va-cost').textContent(),'150%');
    await page.locator('.va-history > summary').click();assert.equal(await page.locator('.va-history tbody tr').count(),77);
    await page.locator('#va-volume').fill('0');assert.equal(await page.locator('#va-cost').textContent(),'0%');
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
    await p.locator('.va-history > summary').click();assert(await p.locator('.va-history table').first().isVisible());await c.close();
  });
  await test('legacy entries provide working fallback links with JavaScript disabled',async()=>{
    const c=await browser.newContext({javaScriptEnabled:false,viewport:{width:375,height:900}});const p=await c.newPage();
    for(const [route,mapping] of Object.entries(consolidation.legacyRoutes)){
      await p.goto(`${base}/${route}.html`);await p.locator('[data-redirect-target]').click();
      assert.equal(new URL(p.url()).hash,'#'+mapping['']);
      assert(await p.locator('h1').isVisible());
    }
    await p.goto(`${base}/index.html#platforms`);await p.locator('#ios-details>summary').click();
    assert(await p.locator('#download-ios pre').isVisible());await c.close();
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
