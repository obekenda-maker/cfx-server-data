'use strict';
/* server_welcome – NUI. Alle teksten komen uit de Lua-config/locale; alles wordt met textContent geplaatst (geen HTML-injectie). */
const $ = (id) => document.getElementById(id);
const post = (name, data) => fetch(`https://${GetParentResourceName()}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
}).catch(() => {});

const S = { mode: 'rules', mandatory: false, texts: {}, steps: [], step: 0, timeoutTimer: null };
const t = (k) => S.texts[k] || k;

/* **vet** → <b>, `code` → <code>; alleen via DOM-nodes, nooit innerHTML */
function richText(parent, text) {
  const parts = String(text).split(/(\*\*[^*]+\*\*|`[^`]+`)/);
  parts.forEach((p) => {
    if (p.startsWith('**') && p.endsWith('**')) { const b = document.createElement('b'); b.textContent = p.slice(2, -2); parent.appendChild(b); }
    else if (p.startsWith('`') && p.endsWith('`')) { const c = document.createElement('code'); c.textContent = p.slice(1, -1); parent.appendChild(c); }
    else if (p) parent.appendChild(document.createTextNode(p));
  });
}
function paragraphs(parent, text) {
  String(text).split(/\n+/).forEach((line) => {
    if (!line.trim()) return;
    const p = document.createElement('p');
    p.style.marginBottom = '8px';
    richText(p, line.replace(/^\s*-\s+/, '• '));
    parent.appendChild(p);
  });
}

function setColors(c) {
  const r = document.documentElement.style;
  ['primary', 'secondary', 'success', 'danger', 'warning', 'text', 'muted'].forEach((k) => { if (c && c[k]) r.setProperty('--' + k, c[k]); });
}

function showView(mode) {
  S.mode = mode;
  ['rules', 'onboarding', 'help'].forEach((m) => $('view-' + m).classList.toggle('hidden', m !== mode));
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.mode === mode));
  $('title').textContent = mode === 'rules' ? t('rules_title') : mode === 'help' ? t('helppage_title') : t('onboarding_title');
}

function buildTabs() {
  const nav = $('tabs');
  nav.innerHTML = '';
  if (S.mandatory) return;           // tijdens het verplichte akkoord geen tabs
  [['onboarding', t('tab_welcome')], ['rules', t('tab_rules')], ['help', t('tab_help')]].forEach(([m, label]) => {
    const b = document.createElement('button');
    b.className = 'tab'; b.dataset.mode = m; b.textContent = label;
    b.onclick = () => showView(m);
    nav.appendChild(b);
  });
}

function renderRules(rules) {
  const body = $('rules-body');
  body.innerHTML = '';
  (rules || []).forEach((sec, i) => {
    const d = document.createElement('div'); d.className = 'rule-section';
    const h = document.createElement('h3'); h.textContent = `${i + 1}. ${sec.title}`; d.appendChild(h);
    const ol = document.createElement('ol');
    (sec.items || []).forEach((it) => { const li = document.createElement('li'); li.textContent = it; ol.appendChild(li); });
    d.appendChild(ol); body.appendChild(d);
  });
  $('accept-label').classList.toggle('hidden', !S.mandatory);
  $('btn-accept').classList.toggle('hidden', !S.mandatory);
  $('btn-decline').classList.toggle('hidden', !S.mandatory);
  $('btn-rules-close').classList.toggle('hidden', S.mandatory);
  $('accept-check').checked = false; $('btn-accept').disabled = true;
}

function renderStep() {
  const st = S.steps[S.step]; if (!st) return;
  $('step-title').textContent = st.title;
  const box = $('step-text'); box.innerHTML = ''; paragraphs(box, st.text);
  $('step-count').textContent = t('step_of').replace('%1', S.step + 1).replace('%2', S.steps.length);
  const dots = $('dots'); dots.innerHTML = '';
  S.steps.forEach((_, i) => { const d = document.createElement('span'); d.className = 'dot' + (i <= S.step ? ' on' : ''); dots.appendChild(d); });
  const wp = $('btn-waypoint');
  wp.classList.toggle('hidden', !st.waypoint);
  if (st.waypoint) wp.textContent = t('waypoint_btn').replace('%s', st.waypoint.label);
  const last = S.step === S.steps.length - 1;
  $('btn-prev').disabled = S.step === 0;
  $('btn-next').classList.toggle('hidden', last);
  $('btn-finish').classList.toggle('hidden', !last);
}

function renderHelp(help) {
  const body = $('help-body'); body.innerHTML = '';
  (help || []).forEach((g) => {
    const d = document.createElement('div'); d.className = 'help-group';
    const h = document.createElement('h3'); h.textContent = g.group; d.appendChild(h);
    g.items.forEach(([cmd, txt]) => {
      const row = document.createElement('div'); row.className = 'help-row';
      const c = document.createElement('code'); c.textContent = cmd;
      const x = document.createElement('span'); x.textContent = txt;
      row.appendChild(c); row.appendChild(x); d.appendChild(row);
    });
    body.appendChild(d);
  });
}

function startTimeout(seconds) {
  clearInterval(S.timeoutTimer);
  const note = $('timeout-note');
  if (!seconds || !S.mandatory) { note.textContent = ''; return; }
  const end = Date.now() + seconds * 1000;
  const tick = () => {
    const left = Math.max(0, Math.round((end - Date.now()) / 1000));
    note.textContent = t('timeout_note').replace('%1', Math.floor(left / 60)).replace('%2', String(left % 60).padStart(2, '0')).replace('%3', t('chat_fallback'));
  };
  tick(); S.timeoutTimer = setInterval(tick, 1000);
}

function open(m) {
  S.texts = m.texts || {}; S.mandatory = m.mandatory === true; S.steps = m.steps || []; S.step = 0;
  setColors(m.colors);
  $('subtitle').textContent = (m.server && m.server.name) ? m.server.name : '';
  $('accept-text').textContent = t('accept_check'); $('btn-accept').textContent = t('accept_btn');
  $('btn-decline').textContent = t('decline_btn'); $('btn-rules-close').textContent = t('close');
  $('btn-help-close').textContent = t('close'); $('btn-prev').textContent = t('prev'); $('btn-next').textContent = t('next');
  $('btn-finish').textContent = t('finish'); $('btn-skip').textContent = t('skip');
  buildTabs(); renderRules(m.rules); renderHelp(m.help); renderStep();
  showView(m.mode || 'rules'); startTimeout(m.timeout);
  $('overlay').classList.remove('hidden');
}
function close() { clearInterval(S.timeoutTimer); $('overlay').classList.add('hidden'); }

$('accept-check').onchange = (e) => { $('btn-accept').disabled = !e.target.checked; };
$('btn-accept').onclick = () => { if (!$('btn-accept').disabled) post('accept'); };
$('btn-decline').onclick = () => post('decline');
$('btn-rules-close').onclick = () => post('close');
$('btn-help-close').onclick = () => post('close');
$('btn-next').onclick = () => { if (S.step < S.steps.length - 1) { S.step++; renderStep(); } };
$('btn-prev').onclick = () => { if (S.step > 0) { S.step--; renderStep(); } };
$('btn-finish').onclick = () => post('finish');
$('btn-skip').onclick = () => post('finish');
$('btn-waypoint').onclick = () => { const wp = S.steps[S.step] && S.steps[S.step].waypoint; if (wp) post('waypoint', { key: wp.key }); };
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !S.mandatory) post('close'); });

window.addEventListener('message', (ev) => {
  const m = ev.data || {};
  if (m.action === 'open') open(m);
  else if (m.action === 'close') close();
});
