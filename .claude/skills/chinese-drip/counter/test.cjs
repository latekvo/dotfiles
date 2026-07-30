'use strict';
/**
 * Drives the counter over real MCP stdio framing and asserts on the results.
 * Run: node test.cjs
 *
 * Every case runs against a sandboxed copy of state.json in a temp dir, so the
 * real dictionary is never touched — the suite mutates levels and graduates words.
 */
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const SANDBOX = fs.mkdtempSync(path.join(os.tmpdir(), 'drip-counter-test-'));
fs.mkdirSync(path.join(SANDBOX, 'counter'));
fs.copyFileSync(path.join(__dirname, 'server.cjs'), path.join(SANDBOX, 'counter', 'server.cjs'));
fs.copyFileSync(path.join(__dirname, 'state.json'), path.join(SANDBOX, 'counter', 'state.json'));

const server = spawn('node', [path.join(SANDBOX, 'counter', 'server.cjs')], { stdio: ['pipe', 'pipe', 'inherit'] });

const pending = new Map();
let buf = '';
server.stdout.on('data', (c) => {
  buf += c;
  let nl;
  while ((nl = buf.indexOf('\n')) !== -1) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    const msg = JSON.parse(line);
    const resolve = pending.get(msg.id);
    if (resolve) {
      pending.delete(msg.id);
      resolve(msg);
    } else {
      console.log('UNSOLICITED:', line);
    }
  }
});

let nextId = 1;
function rpc(method, params) {
  const id = nextId++;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
  });
}
function notify(method, params) {
  server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method, params })}\n`);
}
function call(name, args) {
  return rpc('tools/call', { name, arguments: args }).then((m) => {
    if (m.error) throw new Error(`${name} errored: ${m.error.message}`);
    return JSON.parse(m.result.content[0].text);
  });
}

let failures = 0;
function check(label, cond, detail) {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${label}${detail ? ` — ${detail}` : ''}`);
  if (!cond) failures++;
}

// The server mirrors state into ../wordlist.md between markers; stage a fake one.
const MIRROR = path.join(SANDBOX, 'wordlist.md');
const PROSE_HEAD = '# fake wordlist\n\nHand-written prose that must survive.\n\n';
const PROSE_TAIL = '\n\nTrailing prose that must also survive.\n';
fs.writeFileSync(
  MIRROR,
  `${PROSE_HEAD}<!-- BEGIN:generated (chinese-drip counter owns this block) -->\nSTALE\n<!-- END:generated -->${PROSE_TAIL}`,
);

(async () => {
  const init = await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'drive', version: '0' } });
  check('initialize handshake', init.result.serverInfo.name === 'chinese-drip-counter', init.result.protocolVersion);
  check('advertises tools capability', !!init.result.capabilities.tools);

  notify('notifications/initialized');

  const list = await rpc('tools/list');
  const names = list.result.tools.map((t) => t.name).sort();
  check('tools/list', JSON.stringify(names) === JSON.stringify(['drip_add', 'drip_level', 'drip_record', 'drip_status']), names.join(','));

  // --- status
  const st = await call('drip_status', {});
  check('status: 6 tracked words', st.words_by_level['1'].length + st.words_by_level['2'].length === 6);
  check('status: level-1 words carry a footer line', st.footer_reminders_needed_if_used.includes('代码 (dàimǎ) = code'), JSON.stringify(st.footer_reminders_needed_if_used));
  check('status: 完成 is learned, not a row', st.learned.words.includes('完成') && !JSON.stringify(st.words_by_level).includes('完成'));
  check('status: fresh session opened', st.session.fresh === true && st.session.id === 1);
  check('status: session budget starts at 4', st.session.new_tracked_remaining === 4);

  // --- record: in band
  const inBand = await call('drip_record', {
    reply_words: 120,
    items: [
      { word: '提交', context: 'the counter commit' },
      { word: '测试', context: 'the E2E drive' },
      { word: '完成', context: 'sign-off' },
      { word: '好的', context: 'opener' },
    ],
  });
  check('record: in-band verdict', inBand.verdict === 'IN BAND', `${inBand.density_percent}%`);
  check('record: 好的 counted as pass-through', inBand.passthrough_used.includes('好的'));
  check('record: learned word tallied without a row', inBand.tracked_used.includes('完成 (learned)'));

  // --- record: over band, by item count
  const over = await call('drip_record', {
    reply_words: 400,
    items: Array.from({ length: 10 }, () => ({ word: '发布', context: 'flood' })),
  });
  check('record: over-band by item count (2.5%, 10 items)', over.verdict === 'OVER — cut back', `${over.density_percent}%`);

  // Over by PERCENTAGE alone — item count is legal, density is not. This is the
  // "too heavy blocks the work" failure, and it must not hide behind the item cap.
  const dense = await call('drip_record', {
    reply_words: 20,
    items: Array.from({ length: 5 }, () => ({ word: '发布', context: 'dense' })),
  });
  check('record: over-band by density alone (25%, 5 items)', dense.verdict === 'OVER — cut back', `${dense.density_percent}%`);
  check('record: density advice names the cap', /cap ~10%/.test(dense.advice), dense.advice);

  // Legal on both axes.
  const okBoth = await call('drip_record', {
    reply_words: 200,
    items: Array.from({ length: 8 }, () => ({ word: '发布' })),
  });
  check('record: 8 items @ 4% is in band', okBoth.verdict === 'IN BAND', `${okBoth.density_percent}%`);

  // --- record: under band
  const under = await call('drip_record', { reply_words: 200, items: [{ word: '发布' }] });
  check('record: under-band caught', under.verdict === 'UNDER — likely back-loaded');

  // --- record: meta widens the band
  const meta = await call('drip_record', {
    reply_words: 80,
    meta: true,
    items: Array.from({ length: 10 }, (_, i) => ({ word: i % 2 ? '文件' : '发布' })),
  });
  check('record: meta band allows 10 items @ 12.5%', meta.verdict === 'IN BAND', `${meta.density_percent}% ${meta.band}`);

  // --- record: level-1 word forces a footer warning
  const lvl1 = await call('drip_record', { reply_words: 100, items: [{ word: '代码' }, { word: '报错' }, { word: '提交' }] });
  check(
    'record: level-1 use demands a footer naming exactly the level-1 words',
    lvl1.warnings.some((w) => w === 'Level-1 words used — the reply MUST end with: Reminder: 代码 (dàimǎ) = code · 报错 (bàocuò) = (throws) an error'),
    JSON.stringify(lvl1.warnings),
  );
  check('record: level-2 word did not trigger a footer', !JSON.stringify(lvl1.warnings).includes('提交'), JSON.stringify(lvl1.warnings));

  // --- record: repeated pass-through flagged for promotion
  await call('drip_record', { reply_words: 100, items: [{ word: '好的' }, { word: '文件' }, { word: '发布' }] });
  const st2 = await call('drip_status', {});
  check('status: repeated pass-through flagged', st2.repeated_passthrough.some((p) => p.startsWith('好的')), JSON.stringify(st2.repeated_passthrough));

  // --- add a new tracked word
  const added = await call('drip_add', {
    hanzi: '分支', pinyin: 'fēnzhī', meaning: 'branch', parts: '分 divide + 支 branch',
    chars: ['分', '支'],
    bricks: [
      { char: '分', pinyin: 'fēn', meaning: 'divide / minute', note: '分支; also 部分 "part"' },
      { char: '支', pinyin: 'zhī', meaning: 'branch / support', note: '分支' },
    ],
    note: 'introduced on the counter worktree',
  });
  check('add: enters at level 0', added.level === 0);
  check('add: generates the full gloss with breakdown', added.gloss === '分支 (fēnzhī, "branch" = 分 fēn "divide / minute" + 支 zhī "branch / support")', added.gloss);
  check('add: pulled out of the pipeline', added.pulled_from_pipeline === true);
  const st3 = await call('drip_status', {});
  check('add: pipeline no longer offers it', !st3.pipeline.some((p) => p.startsWith('分支')));
  check('add: session budget decremented', st3.session.new_tracked_remaining === 3);

  // --- promote through to graduation
  const p1 = await call('drip_level', { word: '分支', delta: 1, reason: 'test' });
  check('level: 0→1 reports the footer form', p1.footer === '分支 (fēnzhī) = branch', JSON.stringify(p1));
  const noop = await call('drip_level', { word: '分支', level: 1, reason: 'test' });
  check('level: no-op set is reported, not silently applied', /already at level 1/.test(noop.note || ''), JSON.stringify(noop));

  // A brick shared with a still-tracked word must NOT flatten on graduation.
  await call('drip_add', {
    hanzi: '部分', pinyin: 'bùfen', meaning: 'part / portion', parts: '部 section + 分 divide',
    chars: ['部', '分'],
    bricks: [{ char: '部', pinyin: 'bù', meaning: 'section / department', note: '部分, 部署' }],
  });
  const gradShared = await call('drip_level', { word: '分支', level: 4, reason: 'test shared brick' });
  check('graduation: only the unshared brick flattens', gradShared.action.includes('支') && !gradShared.action.includes('分 ·') , gradShared.action);
  const stShared = await call('drip_status', {});
  check('graduation: 支 flattened', stShared.learned.bricks.includes('支'));
  check('graduation: 分 held back — 部分 still teaches it', !stShared.learned.bricks.includes('分') && stShared.bricks.some((b) => b.startsWith('分 ')), JSON.stringify(stShared.bricks));

  const grad = await call('drip_level', { word: '文件', level: 4, reason: 'test graduation' });
  check('level: graduation deletes the row', grad.action.includes('row deleted'), grad.action);
  check('level: graduation flattens its bricks', grad.action.includes('文') && grad.action.includes('件'), grad.action);
  const st4 = await call('drip_status', {});
  check('graduation: word in Learned list', st4.learned.words.includes('文件'));
  check('graduation: bricks 文/件 flattened', st4.learned.bricks.includes('文') && st4.learned.bricks.includes('件'));
  check('graduation: bricks gone from teaching table', !st4.bricks.some((b) => b.startsWith('文 ') || b.startsWith('件 ')), JSON.stringify(st4.bricks));

  // --- demotion out of 4 rebuilds the row
  const demo = await call('drip_level', { word: '文件', level: 2, reason: 'user went blank' });
  check('demote from 4: rebuilds at level 2', demo.to === 2 && demo.action.includes('rebuilt'), JSON.stringify(demo));
  const st6 = await call('drip_status', {});
  check('demote from 4: back in the table with real pinyin', st6.words_by_level['2'].some((w) => w.hanzi === '文件' && w.pinyin === 'wénjiàn'));
  check('demote from 4: out of the Learned list', !st6.learned.words.includes('文件'));
  check(
    'demote from 4: its bricks come back to the teaching table too',
    st6.bricks.some((b) => b.startsWith('文 wén')) && !st6.learned.bricks.includes('文'),
    JSON.stringify(st6.learned.bricks),
  );
  const regloss = st6.words_by_level['2'].find((w) => w.hanzi === '文件');
  check('demote from 4: parts restored, not lost', regloss.parts === '文 writing/art + 件 item ← the user\'s own example', JSON.stringify(regloss));

  // --- error paths
  const unknown = await call('drip_level', { word: '龙', delta: 1 });
  check('level: unknown word errors cleanly', !!unknown.error, unknown.error);
  const dupe = await call('drip_add', { hanzi: '代码', pinyin: 'x', meaning: 'y' });
  check('add: duplicate rejected', !!dupe.error, dupe.error);
  const bad = await rpc('tools/call', { name: 'nope', arguments: {} });
  check('unknown tool → JSON-RPC error', !!bad.error && bad.error.code === -32602, JSON.stringify(bad.error));
  const badMethod = await rpc('totally/unknown');
  check('unknown method → -32601', badMethod.error.code === -32601);
  const ping = await rpc('ping');
  check('ping answers', !!ping.result);

  // --- markdown mirror
  const md = fs.readFileSync(MIRROR, 'utf8');
  check('mirror: stale block replaced', !md.includes('STALE'));
  check('mirror: hand-written prose preserved', md.startsWith(PROSE_HEAD) && md.endsWith(PROSE_TAIL));
  check('mirror: markers still intact for the next write', md.includes('<!-- BEGIN:generated') && md.includes('<!-- END:generated -->'));
  check('mirror: renders the Words table', /\| 代码 \| dàimǎ \| code \| 1 \|/.test(md), md.split('\n').find((l) => l.startsWith('| 代码')));
  check('mirror: renders the Learned list', /\*\*Words:\*\*.*完成/.test(md));
  check('mirror: graduated word left the table', !/\| 分支 \|/.test(md) && /\*\*Words:\*\*.*分支/.test(md));
  check('mirror: renders the Characters table', /\| 马 \| mǎ \| horse \| P \|/.test(md));
  check('mirror: renders the pipeline', /修复 xiūfù fix/.test(md));

  // Idempotence: a second render must not drift or nest markers.
  await call('drip_status', {});
  const md2 = fs.readFileSync(MIRROR, 'utf8');
  check('mirror: re-render is stable', md2 === md, 'second write differed');
  check('mirror: markers not duplicated', md2.split('<!-- BEGIN:generated').length === 2);

  console.log(`\n${failures === 0 ? 'ALL PASS' : `${failures} FAILURE(S)`}`);
  server.stdin.end();
  process.exit(failures === 0 ? 0 : 1);
})().catch((e) => {
  console.error('DRIVER ERROR:', e);
  process.exit(1);
});
