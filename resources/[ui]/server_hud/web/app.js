'use strict';
/* server_hud – NUI. Alle teksten komen uit de Lua-config (server_config/locale_nl.lua). */

const $ = (id) => document.getElementById(id);
const state = { texts: {}, hud: {}, colors: {}, fmt: new Intl.NumberFormat('nl-NL') };

const money = (n) => '€' + state.fmt.format(Math.max(0, Math.floor(n || 0)));
const t = (key, fallback) => state.texts[key] || fallback || key;

function applyTexts() {
  document.querySelectorAll('[data-t]').forEach((el) => {
    const v = state.texts[el.dataset.t];
    if (v) el.textContent = v;
  });
}

function applyConfig(msg) {
  state.texts = msg.texts || {};
  state.hud = msg.hud || {};
  state.colors = msg.colors || {};
  const r = document.documentElement.style;
  const c = state.colors;
  if (c.primary) r.setProperty('--primary', c.primary);
  if (c.secondary) r.setProperty('--secondary', c.secondary);
  if (c.success) r.setProperty('--success', c.success);
  if (c.danger) r.setProperty('--danger', c.danger);
  if (c.warning) r.setProperty('--warning', c.warning);
  if (c.panel) r.setProperty('--panel', c.panel);
  if (c.text) r.setProperty('--text', c.text);
  if (c.muted) r.setProperty('--muted', c.muted);
  r.setProperty('--scale', String(state.hud.scale || 1));

  const place = (el, pos) => {
    el.classList.remove('pos-top-left', 'pos-top-right', 'pos-bottom-left', 'pos-bottom-right');
    el.classList.add('pos-' + pos);
  };
  place($('status'), state.hud.position || 'bottom-right');
  place($('money'), state.hud.moneyPosition || 'top-right');
  place($('killfeed'), state.hud.killfeedPosition || 'top-right');

  $('row-cash').classList.toggle('hidden', !state.hud.showMoney);
  $('row-bank').classList.toggle('hidden', !state.hud.showBank);
  $('row-job').classList.toggle('hidden', !state.hud.showJob);
  $('money').classList.toggle('hidden', !(state.hud.showMoney || state.hud.showBank || state.hud.showJob));
  $('v-unit').textContent = state.hud.speedUnit === 'mph' ? t('speed_mph', 'mph') : t('speed_kmh', 'km/u');
  $('board-title').textContent = t('board_title', 'Leaderboard');
  $('board-empty').textContent = t('board_empty', '');
  applyTexts();
  $('root').classList.remove('hidden');
}

function setBar(id, value, hideWhenNull) {
  const el = $(id);
  if (value === null || value === undefined) {
    if (hideWhenNull) el.classList.add('hidden');
    return;
  }
  el.classList.remove('hidden');
  const v = Math.max(0, Math.min(100, value));
  el.querySelector('i').style.width = v + '%';
  el.querySelector('b').textContent = Math.round(v);
  el.classList.toggle('low', v <= 20);
}

function update(m) {
  $('root').classList.toggle('dim', m.visible === false);
  setBar('bar-health', m.health);
  setBar('bar-armor', m.armor);
  $('bar-armor').classList.toggle('hidden', !m.armor);
  setBar('bar-hunger', state.hud.showHunger ? m.hunger : null, true);
  setBar('bar-thirst', state.hud.showThirst ? m.thirst : null, true);

  $('cash').textContent = money(m.cash);
  $('bank').textContent = money(m.bank);
  $('job').textContent = m.job || t('job_none');
  $('grade').textContent = m.grade || '';

  const v = $('vehicle');
  if (m.vehicle && state.hud.showVehicle) {
    v.classList.remove('hidden');
    $('v-speed').textContent = m.vehicle.speed;
    $('v-fuel').textContent = m.vehicle.fuel + '%';
    $('v-gear').textContent = m.vehicle.gear === 0 ? 'R' : (m.vehicle.speed < 1 ? 'N' : m.vehicle.gear);
    $('v-engine').textContent = m.vehicle.engine + '%';
  } else {
    v.classList.add('hidden');
  }

  const a = $('ammo');
  if (m.ammo && state.hud.showAmmo) {
    a.classList.remove('hidden');
    $('a-clip').textContent = m.ammo.clip;
    $('a-reserve').textContent = m.ammo.reserve;
  } else {
    a.classList.add('hidden');
  }
}

/* ---- Combat ---- */
function combat(s) {
  const el = $('combat');
  if (!s || !s.active) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  $('combat-zone').textContent = s.zone ? s.zone.label : '-';
  $('c-kills').textContent = s.kills || 0;
  $('c-deaths').textContent = s.deaths || 0;
  $('c-streak').textContent = s.streak || 0;
  $('c-kd').textContent = ((s.kills || 0) / Math.max(s.deaths || 0, 1)).toFixed(2);

  const team = $('combat-team');
  const scores = $('scores');
  if (s.teams && s.team !== undefined && s.zone && s.zone.mode === 'team') {
    const mine = s.teams.find((x) => x.id === s.team);
    team.textContent = mine ? t('team', 'Team') + ' ' + mine.label : '';
    team.style.color = mine ? mine.color : '';
    scores.classList.remove('hidden');
    scores.innerHTML = '';
    s.teams.forEach((tm) => {
      const sp = document.createElement('span');
      sp.style.color = tm.color;
      sp.textContent = tm.label + ' ' + ((s.scores && s.scores[tm.id]) || 0);
      scores.appendChild(sp);
    });
    if (s.scoreLimit) {
      const lim = document.createElement('span');
      lim.innerHTML = '<i></i>';
      lim.firstChild.textContent = (t('round_to', 'Eerste tot %d')).replace('%d', s.scoreLimit);
      scores.appendChild(lim);
    }
  } else {
    team.textContent = '';
    scores.classList.add('hidden');
  }
}

let protectTimer = null;
function protection(seconds) {
  const box = $('protect');
  const bar = $('protect-bar');
  clearInterval(protectTimer);
  if (!seconds) { box.classList.add('hidden'); return; }
  box.classList.remove('hidden');
  const end = Date.now() + seconds * 1000;
  const tick = () => {
    const left = end - Date.now();
    bar.style.width = Math.max(0, (left / (seconds * 1000)) * 100) + '%';
    if (left <= 0) { clearInterval(protectTimer); box.classList.add('hidden'); }
  };
  tick();
  protectTimer = setInterval(tick, 100);
}

/* ---- Killfeed ---- */
function killfeed(e) {
  const feed = $('killfeed');
  const max = state.hud.killfeedMax || 6;
  while (feed.children.length >= max) feed.removeChild(feed.firstChild);

  const div = document.createElement('div');
  div.className = 'kf';
  const tpl = e.suicide ? t('suicide_text') : t('kill_text');
  const parts = tpl.split(/(\{killer\}|\{victim\}|\{weapon\})/);
  parts.forEach((p) => {
    if (p === '{killer}' || p === '{victim}') {
      const b = document.createElement('b');
      b.textContent = p === '{killer}' ? e.killer : e.victim;
      const col = p === '{killer}' ? e.killerColor : e.victimColor;
      if (col) b.style.color = col;
      div.appendChild(b);
    } else if (p === '{weapon}') {
      const b = document.createElement('b');
      b.textContent = e.weapon;
      b.style.color = 'var(--primary)';
      div.appendChild(b);
    } else if (p) {
      div.appendChild(document.createTextNode(p));
    }
  });
  if (e.streak && e.streak >= 3) {
    const s = document.createElement('span');
    s.className = 'streak';
    s.textContent = t('streak_text').replace('{n}', e.streak);
    div.appendChild(s);
  }
  feed.appendChild(div);
  const life = (state.hud.killfeedSeconds || 7) * 1000;
  setTimeout(() => {
    div.classList.add('out');
    setTimeout(() => div.remove(), 450);
  }, life);
}

/* ---- Banner ---- */
let bannerTimer = null;
function banner(b) {
  const el = $('banner');
  $('banner-title').textContent = b.title || '';
  $('banner-text').textContent = b.text || '';
  el.style.setProperty('--bannerColor', b.color || '');
  el.classList.remove('hidden');
  el.style.animation = 'none';
  void el.offsetWidth;
  el.style.animation = '';
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => el.classList.add('hidden'), 3600);
}

/* ---- Leaderboard ---- */
function leaderboard(m) {
  const board = $('board');
  if (!m.show) { board.classList.add('hidden'); return; }
  board.classList.remove('hidden');
  $('board-sort').textContent = t('board_sort_' + m.sort);
  const body = $('board-rows');
  body.innerHTML = '';
  const rows = m.rows || [];
  $('board-empty').classList.toggle('hidden', rows.length > 0);
  rows.forEach((r, i) => {
    const tr = document.createElement('tr');
    [(r.rank || i + 1), r.name, r.kills, r.deaths, Number(r.kd).toFixed(2), r.level].forEach((v) => {
      const td = document.createElement('td');
      td.textContent = v;
      tr.appendChild(td);
    });
    body.appendChild(tr);
  });
  const foot = $('board-mine');
  foot.innerHTML = '';
  if (m.mine) {
    const mk = (label, value) => {
      const s = document.createElement('span');
      s.textContent = label + ' ';
      const b = document.createElement('b');
      b.textContent = value;
      s.appendChild(b);
      foot.appendChild(s);
    };
    mk(t('board_mine'), '');
    mk(t('kills'), m.mine.kills);
    mk(t('deaths'), m.mine.deaths);
    mk(t('kd'), Number(m.mine.kd).toFixed(2));
    mk(t('board_level'), m.mine.level);
    mk(t('board_xp'), m.mine.xp);
    mk(t('board_best'), m.mine.best_streak);
  }
}

window.addEventListener('message', (ev) => {
  const m = ev.data;
  switch (m.action) {
    case 'config': applyConfig(m); break;
    case 'update': update(m); break;
    case 'combat': combat(m.state); break;
    case 'protection': protection(m.seconds); break;
    case 'killfeed': killfeed(m.entry); break;
    case 'banner': banner(m.banner); break;
    case 'death': $('death').classList.toggle('hidden', !m.dead); break;
    case 'leaderboard': leaderboard(m); break;
  }
});

/* Vertel Lua dat de NUI klaar is (config volgt) */
fetch(`https://${GetParentResourceName()}/ready`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  body: JSON.stringify({}),
}).catch(() => {});
