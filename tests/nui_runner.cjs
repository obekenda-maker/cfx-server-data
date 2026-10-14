// Draait de échte HUD-NUI in headless Chromium en voert scenario's uit. Output: JSON met resultaten.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs = require('fs'), path = require('path');
const root = process.argv[2];
(async () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const css = fs.readFileSync(path.join(root, 'style.css'), 'utf8');
  const js = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
  const body = html.split('<body>')[1].split('<script')[0];
  const posted = [];
  const page = (`<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${body}
    <script>window.GetParentResourceName=()=>'server_hud';window.__posts=[];
    window.fetch=(u,o)=>{window.__posts.push(u);return Promise.resolve({json:()=>({})})};</script>
    <script>${js}</script></body></html>`);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM, args: ['--no-sandbox'] });
  const p = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  p.on('pageerror', e => errors.push('pageerror: ' + e.message));
  p.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await p.setContent(page);
  const send = (m) => p.evaluate((m) => window.postMessage(m, '*'), m);
  const q = (sel) => p.evaluate((s) => document.querySelector(s) ? document.querySelector(s).textContent : null, sel);
  const cls = (sel) => p.evaluate((s) => Array.from(document.querySelector(s).classList), sel);
  const count = (sel) => p.evaluate((s) => document.querySelectorAll(s).length, sel);
  const wait = (ms) => p.waitForTimeout(ms);
  const res = {};

  res.readyPosted = await p.evaluate(() => window.__posts.some(u => u.endsWith('/ready')));
  const texts = { cash: 'Contant', bank: 'Bank', kill_text: '{killer} heeft {victim} geëlimineerd met {weapon}', suicide_text: '{victim} is uitgeschakeld ({weapon})', streak_text: 'serie van {n}', job_none: 'Werkloos', board_sort_kills: 'Meeste kills' };
  await send({ action: 'config', colors: { primary: '#123456' }, texts, hud: { position: 'top-left', moneyPosition: 'top-left', killfeedPosition: 'top-left', scale: 1.1, killfeedMax: 3, killfeedSeconds: 60, showHunger: true, showThirst: true, showMoney: true, showBank: true, showJob: true, showVehicle: true, showAmmo: true, speedUnit: 'mph' } });
  await wait(50);
  res.positionClass = await cls('#status');
  res.primaryVar = await p.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--primary').trim());

  await send({ action: 'update', visible: true, health: 150, armor: -5, hunger: null, thirst: undefined, cash: 1250.7, bank: null, job: null, grade: undefined });
  await wait(50);
  res.cash = await q('#cash'); res.bank = await q('#bank'); res.job = await q('#job');
  res.healthClamped = await q('#bar-health b');
  res.hungerHidden = (await cls('#bar-hunger')).includes('hidden');

  await send({ action: 'update', visible: true, health: 50, armor: 10, hunger: 40, thirst: 15, cash: 5, bank: 6, vehicle: { speed: 88, fuel: 50, gear: 0, engine: 99 }, ammo: { clip: 7, reserve: 30 } });
  await wait(50);
  res.gearReverse = await q('#v-gear'); res.fuelText = await q('#v-fuel'); res.ammo = (await q('#a-clip')) + '/' + (await q('#a-reserve'));
  res.thirstLow = (await cls('#bar-thirst')).includes('low');

  await send({ action: 'update', visible: false });
  await wait(50);
  res.dimmed = (await cls('#root')).includes('dim');
  await send({ action: 'update', visible: true });

  // killfeed: limiet + XSS
  for (let i = 0; i < 6; i++) await send({ action: 'killfeed', entry: { killer: 'K' + i, victim: 'V' + i, weapon: 'Karabijn', streak: i } });
  await send({ action: 'killfeed', entry: { killer: '<img src=x onerror="window.__xss=1">', victim: '<b>vet</b>', weapon: '<script>window.__xss=2</script>', killerColor: 'red;background:url(x)' } });
  await send({ action: 'killfeed', entry: { victim: 'Mo', weapon: 'Val', suicide: true } });
  await wait(100);
  res.killfeedCount = await count('#killfeed .kf');
  res.injectedElements = await count('#killfeed img, #killfeed script, #killfeed b b');
  res.xss = await p.evaluate(() => window.__xss || 0);
  res.lastFeed = await p.evaluate(() => document.querySelector('#killfeed .kf:last-child').textContent);

  // combat-paneel
  await send({ action: 'combat', state: { active: true, zone: { label: '<i>Zone</i>', mode: 'team' }, team: 2, teams: [{ id: 1, label: 'Rood', color: '#f00' }, { id: 2, label: 'Blauw', color: '#00f' }], scores: { 1: 3 }, scoreLimit: 30, kills: 4, deaths: 0, streak: 2 } });
  await wait(50);
  res.combatVisible = !(await cls('#combat')).includes('hidden');
  res.kd = await q('#c-kd');
  res.zoneEscaped = await p.evaluate(() => document.querySelector('#combat-zone').children.length);
  res.scoresText = await q('#scores');
  await send({ action: 'combat', state: { active: false } });
  await wait(50);
  res.combatHidden = (await cls('#combat')).includes('hidden');
  await send({ action: 'combat' });   // ontbrekende state mag niet crashen

  // protectie, dood, banner
  await send({ action: 'protection', seconds: 2 });
  await wait(150);
  res.protectShown = !(await cls('#protect')).includes('hidden');
  await send({ action: 'protection', seconds: 0 });
  await send({ action: 'death', dead: true });
  await wait(50);
  res.deathShown = !(await cls('#death')).includes('hidden');
  await send({ action: 'death', dead: false });
  await send({ action: 'banner', banner: { title: 'PvP', text: 'x', color: '#f00' } });

  // leaderboard
  await send({ action: 'leaderboard', show: true, sort: 'kills', rows: [{ rank: 1, name: '<b>X</b>', kills: 5, deaths: 2, kd: 2.5, level: 3 }], mine: { kills: 1, deaths: 1, kd: 1, level: 1, xp: 5, best_streak: 1 } });
  await wait(50);
  res.boardRows = await count('#board-rows tr');
  res.boardEscaped = await count('#board-rows b');
  await send({ action: 'leaderboard', show: true, sort: 'kd', rows: [], mine: null });
  await wait(50);
  res.boardEmptyShown = !(await cls('#board-empty')).includes('hidden');
  await send({ action: 'leaderboard', show: false });

  // onbekende actie en rommel
  await send({ action: 'bestaat-niet' });
  await send({});
  await wait(100);
  res.errors = errors;
  console.log(JSON.stringify(res));
  await browser.close();
})();
