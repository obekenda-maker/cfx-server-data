const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('fs'), path = require('path');
const root = process.argv[2];
(async () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const css = fs.readFileSync(path.join(root, 'style.css'), 'utf8');
  const js = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
  const body = html.split('<body>')[1].split('<script')[0];
  const page = `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${body}
    <script>window.GetParentResourceName=()=>'server_welcome';window.__posts=[];
    window.fetch=(u,o)=>{window.__posts.push({u:u.split('/').pop(),b:o&&o.body});return Promise.resolve({})};</script>
    <script>${js}</script></body></html>`;
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM, args: ['--no-sandbox'] });
  const p = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  p.on('pageerror', e => errors.push('pageerror: ' + e.message));
  p.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await p.setContent(page);
  const send = (m) => p.evaluate((m) => window.postMessage(m, '*'), m);
  const hidden = (sel) => p.evaluate((s) => document.querySelector(s).classList.contains('hidden') || getComputedStyle(document.querySelector(s)).display === 'none', sel);
  const text = (sel) => p.evaluate((s) => document.querySelector(s).textContent, sel);
  const count = (sel) => p.evaluate((s) => document.querySelectorAll(s).length, sel);
  const posts = () => p.evaluate(() => window.__posts.map(x => x.u));
  const clear = () => p.evaluate(() => { window.__posts.length = 0; });
  const wait = (ms) => p.waitForTimeout(ms);
  const res = {};

  const texts = { rules_title: 'Serverregels', onboarding_title: 'Welkom!', helppage_title: "Hulp", tab_welcome: 'Uitleg', tab_rules: 'Regels', tab_help: 'Commando\'s', accept_check: 'Ik ga akkoord', accept_btn: 'Akkoord', decline_btn: 'Niet akkoord', close: 'Sluiten', prev: 'Vorige', next: 'Volgende', finish: 'Aan de slag', skip: 'Overslaan', step_of: 'Stap %1 van %2', waypoint_btn: 'Zet "%s" op mijn kaart', timeout_note: 'Nog %1:%2. %3', chat_fallback: 'Typ /akkoord.' };
  const rules = [{ title: 'Algemeen', items: ['Wees aardig', '<img src=x onerror="window.__xss=1">'] }, { title: 'PvP', items: ['Vrijwillig'] }];
  const steps = [
    { title: 'Stap een', text: 'Hallo **vet** en `/code`\n- punt <script>window.__xss=2</script>' },
    { title: 'Stap twee', text: 'Werk', waypoint: { key: 'jobcenter', label: 'Jobcentrum' } },
    { title: 'Stap drie', text: 'Klaar' },
  ];
  const help = [{ group: 'Algemeen', items: [['/help', 'Toon hulp'], ['/regels', 'Regels']] }];
  const base = { action: 'open', texts, rules, steps, help, server: { name: 'Testserver' }, colors: { primary: '#123456' }, version: 1 };

  // --- verplicht akkoord ---
  await send({ ...base, mode: 'rules', mandatory: true, timeout: 90 });
  await wait(1200);
  res.overlayVisible = !(await hidden('#overlay'));
  res.title = await text('#title');
  res.tabsEmpty = (await count('#tabs .tab')) === 0;
  res.closeHiddenWhenMandatory = await hidden('#btn-rules-close');
  res.acceptDisabled = await p.evaluate(() => document.getElementById('btn-accept').disabled);
  await p.click('#btn-accept', { force: true }).catch(() => {});
  res.acceptNoPostWhenDisabled = !(await posts()).includes('accept');
  await p.check('#accept-check');
  res.acceptEnabled = !(await p.evaluate(() => document.getElementById('btn-accept').disabled));
  await p.click('#btn-accept');
  res.acceptPosted = (await posts()).includes('accept');
  await clear();
  await p.click('#btn-decline');
  res.declinePosted = (await posts()).includes('decline');
  await clear();
  await p.keyboard.press('Escape');
  res.escIgnoredWhenMandatory = !(await posts()).includes('close');
  res.rulesCount = await count('#rules-body li');
  res.rulesInjected = await count('#rules-body img');
  res.timeoutNote = await text('#timeout-note');
  res.primary = await p.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--primary').trim());

  // --- rules vrijwillig (/regels) ---
  await send({ ...base, mode: 'rules', mandatory: false });
  await wait(50);
  res.readOnlyNoAccept = (await hidden('#btn-accept')) && (await hidden('#accept-label')) && !(await hidden('#btn-rules-close'));
  res.tabsShown = (await count('#tabs .tab')) === 3;
  await p.keyboard.press('Escape');
  res.escClosesWhenAllowed = (await posts()).includes('close');
  await clear();

  // --- onboarding ---
  await send({ ...base, mode: 'onboarding', mandatory: false });
  await wait(50);
  res.step1 = await text('#step-title');
  res.stepCount = await text('#step-count');
  res.prevDisabledFirst = await p.evaluate(() => document.getElementById('btn-prev').disabled);
  res.boldRendered = await count('#step-text b');
  res.codeRendered = await count('#step-text code');
  res.stepInjected = await count('#step-text script');
  res.waypointHiddenStep1 = await hidden('#btn-waypoint');
  await p.click('#btn-next');
  res.step2 = await text('#step-title');
  res.waypointText = await text('#btn-waypoint');
  await p.click('#btn-waypoint');
  res.waypointPosted = (await p.evaluate(() => window.__posts.filter(x => x.u === 'waypoint').map(x => JSON.parse(x.b).key))).join(',');
  await p.click('#btn-next');
  res.lastStepShowsFinish = !(await hidden('#btn-finish')) && (await hidden('#btn-next'));
  await p.click('#btn-prev');
  res.prevWorks = (await text('#step-title')) === 'Stap twee';
  await p.click('#btn-next'); await clear();
  await p.click('#btn-finish');
  res.finishPosted = (await posts()).includes('finish');
  await clear();
  await p.click('#btn-skip');
  res.skipPosted = (await posts()).includes('finish');

  // --- help ---
  await send({ ...base, mode: 'help', mandatory: false });
  await wait(50);
  res.helpRows = await count('#help-body .help-row');
  await send({ action: 'close' });
  await wait(50);
  res.closed = await hidden('#overlay');
  res.xss = await p.evaluate(() => window.__xss || 0);
  await send({ action: 'iets-anders' }); await send({});
  res.errors = errors;
  console.log(JSON.stringify(res));
  await browser.close();
})();
