#!/usr/bin/env node
'use strict';

/**
 * chinese-drip counter — an MCP stdio server that owns the drip bookkeeping:
 * progress levels, per-reply density budget, usage counts, and level-4 graduation.
 *
 * state.json is the source of truth; wordlist.md is a generated human-readable
 * mirror, rewritten between its BEGIN/END markers on every mutation.
 *
 * Dependency-free on purpose: it lives in the dotfiles-synced skill directory,
 * so it must run anywhere node does, with nothing installed.
 */

const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const STATE_PATH = path.join(DIR, 'state.json');
const WORDLIST_PATH = path.join(DIR, '..', 'wordlist.md');
const BEGIN = '<!-- BEGIN:generated (chinese-drip counter owns this block) -->';
const END = '<!-- END:generated -->';

/** A gap this long between recorded activity starts a new session. */
const SESSION_GAP_MS = 6 * 60 * 60 * 1000;

/** Density bands from SKILL.md: [maxPercent, minItems, maxItems]. */
const BANDS = {
  normal: { cap: 10, minItems: 3, maxItems: 8 },
  meta: { cap: 15, minItems: 6, maxItems: 12 },
};

const SESSION_NEW_TRACKED_BUDGET = 4;
const REPLY_NEW_TRACKED_BUDGET = 1;

// ---------------------------------------------------------------- state I/O

function today() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function loadState() {
  const raw = fs.readFileSync(STATE_PATH, 'utf8');
  const state = JSON.parse(raw);
  state.words ||= [];
  state.bricks ||= [];
  state.pipeline ||= [];
  state.sessions ||= [];
  state.passthrough ||= {};
  state.learned ||= { words: [], bricks: [] };
  return state;
}

function saveState(state) {
  const tmp = `${STATE_PATH}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(state, null, 2)}\n`);
  fs.renameSync(tmp, STATE_PATH);
  renderWordlist(state);
}

// ------------------------------------------------------------- lookup utils

function findWord(state, hanzi) {
  return state.words.find((w) => w.hanzi === hanzi);
}

function findBrick(state, char) {
  return state.bricks.find((b) => b.char === char);
}

function isBrickLearned(state, char) {
  return state.learned.bricks.includes(char);
}

/**
 * The breakdown is a teaching aid for bricks that are still new, so drop any
 * character the user already owns rather than re-decomposing it.
 */
function partsGloss(state, word) {
  const chars = (word.chars || []).filter((c) => !isBrickLearned(state, c));
  if (!chars.length) return null;
  const pieces = chars.map((c) => {
    const b = findBrick(state, c);
    return b ? `${c} ${b.pinyin} "${b.meaning}"` : c;
  });
  return pieces.join(' + ');
}

function fullGloss(state, word) {
  const parts = partsGloss(state, word);
  const head = `${word.hanzi} (${word.pinyin}, "${word.meaning}"`;
  return parts ? `${head} = ${parts})` : `${head})`;
}

function footerGloss(word) {
  return `${word.hanzi} (${word.pinyin}) = ${word.meaning}`;
}

const LEVEL_RULE = {
  0: 'full inline gloss on FIRST use per message, bare on reuse within that message',
  1: 'bare in the text + a footer reminder at the end of the message',
  2: 'mostly bare; occasional light support, not guaranteed',
  3: 'no gloss; occasionally TEST recall instead of telling',
  4: 'bare forever — learned, lives in the flat list',
};

// ------------------------------------------------------ level-4 graduation

/**
 * Level 4 means the row is dead weight: flatten the word into the Learned list,
 * and flatten each of its bricks once EVERY word that brick was taught in is
 * learned. Mirrors the rule in SKILL.md so it never has to be done by hand.
 */
function graduate(state, word) {
  const moved = { word: word.hanzi, bricks: [] };
  state.words = state.words.filter((w) => w.hanzi !== word.hanzi);
  if (!state.learned.words.includes(word.hanzi)) state.learned.words.push(word.hanzi);

  for (const char of word.chars || []) {
    if (isBrickLearned(state, char)) continue;
    // Any still-tracked word using this brick keeps it in the teaching table.
    const stillTaught = state.words.some((w) => (w.chars || []).includes(char));
    if (stillTaught) continue;
    state.bricks = state.bricks.filter((b) => b.char !== char);
    state.learned.bricks.push(char);
    moved.bricks.push(char);
  }
  return moved;
}

/** Demotion out of 4 rebuilds the row at level 2 and re-glosses (SKILL.md). */
function ungraduate(state, hanzi, level) {
  state.learned.words = state.learned.words.filter((w) => w !== hanzi);
  const archived = (state.archive || {})[hanzi];
  const word = archived
    ? { ...archived, level }
    : { hanzi, pinyin: '?', meaning: '?', level, chars: [], uses: [], notes: [] };
  word.level = level;
  state.words.push(word);
  for (const char of word.chars || []) {
    if (isBrickLearned(state, char) && !findBrick(state, char)) {
      state.learned.bricks = state.learned.bricks.filter((b) => b !== char);
      state.bricks.push((state.archive || {})[`brick:${char}`] || { char, pinyin: '?', meaning: '?', tags: '', note: '' });
    }
  }
  return word;
}

// --------------------------------------------------------------- sessions

function currentSession(state, forceNew) {
  const now = Date.now();
  const last = state.sessions[state.sessions.length - 1];
  const stale = !last || now - new Date(last.last).getTime() > SESSION_GAP_MS;
  if (forceNew || stale) {
    const session = {
      id: state.sessions.length + 1,
      date: today(),
      started: new Date(now).toISOString(),
      last: new Date(now).toISOString(),
      replies: 0,
      items: 0,
      new_tracked: [],
    };
    state.sessions.push(session);
    return { session, fresh: true };
  }
  return { session: last, fresh: false };
}

// ------------------------------------------------------------- markdown out

function renderWordlist(state) {
  let doc;
  try {
    doc = fs.readFileSync(WORDLIST_PATH, 'utf8');
  } catch {
    return; // mirror is optional; state.json is the source of truth
  }
  const start = doc.indexOf(BEGIN);
  const stop = doc.indexOf(END);
  if (start === -1 || stop === -1) return;

  const body = [];
  body.push('## Learned (level 4) — bare, forever');
  body.push('');
  body.push(`**Words:** ${state.learned.words.join(' · ') || '—'}`);
  body.push('');
  body.push(`**Bricks (字):** ${state.learned.bricks.join(' · ') || '—'}`);
  body.push('');
  body.push('## Words');
  body.push('');
  body.push('| 汉字 | pīnyīn | meaning | lvl | parts (character breakdown) |');
  body.push('|------|--------|---------|:---:|------|');
  for (const w of [...state.words].sort((a, b) => b.level - a.level || a.hanzi.localeCompare(b.hanzi))) {
    const notes = [w.parts, ...(w.notes || [])].filter(Boolean).join('; ');
    body.push(`| ${w.hanzi} | ${w.pinyin} | ${w.meaning} | ${w.level} | ${notes} |`);
  }
  body.push('');
  body.push('## Characters (字) — the atoms');
  body.push('');
  body.push('The reusable bricks still being taught. Once a brick is known, stop decomposing the');
  body.push('words it appears in and name the payoff instead ("你 already know 码 from 代码").');
  body.push('**R** = often acts as a radical (meaning cue); **P** = often acts as a phonetic (sound cue).');
  body.push('');
  body.push('| 字 | pīnyīn | meaning | tags | appears in / notes |');
  body.push('|----|--------|---------|:----:|------|');
  for (const b of state.bricks) {
    body.push(`| ${b.char} | ${b.pinyin} | ${b.meaning} | ${b.tags || ''} | ${b.note || ''} |`);
  }
  body.push('');
  body.push('## Pipeline (introduce a couple at a time; all enter at level 0)');
  body.push('');
  body.push(
    state.pipeline
      .map((p) => `${p.hanzi} ${p.pinyin} ${p.meaning}${p.parts ? ` (${p.parts})` : ''}`)
      .join(' · '),
  );

  const next = `${doc.slice(0, start + BEGIN.length)}\n\n${body.join('\n')}\n\n${doc.slice(stop)}`;
  const tmp = `${WORDLIST_PATH}.tmp`;
  fs.writeFileSync(tmp, next);
  fs.renameSync(tmp, WORDLIST_PATH);
}

// ------------------------------------------------------------------- tools

const TOOLS = [
  {
    name: 'drip_status',
    description:
      'Read the living dictionary and the current session tallies. Call this ONCE early in a session, before weaving any Chinese into a reply — it replaces reading wordlist.md by hand. Returns every tracked word with its progress level and the exact gloss string to use at that level, the level-1 footer line, the flat Learned list, the bricks still being taught, the pipeline, and how much of the session new-tracked-word budget is already spent.',
    inputSchema: {
      type: 'object',
      properties: {
        new_session: {
          type: 'boolean',
          description:
            'Force-start a new session. Normally unnecessary — a new session rolls automatically after a 6h gap in recorded activity.',
        },
      },
    },
  },
  {
    name: 'drip_record',
    description:
      'Record the Chinese used in one reply and get the density verdict. Call this AFTER composing a reply, before sending it, so the ~10% (normal) / ~15% (meta) budget is checked rather than eyeballed. Logs a dated use against each tracked word (which is what generates the "reused <date> (<context>)" notes), counts pass-through words and flags any used a second time (they should be promoted to tracked), and enforces the new-tracked-word budget.',
    inputSchema: {
      type: 'object',
      properties: {
        items: {
          type: 'array',
          description:
            'One entry per Chinese item in the reply, in order of appearance. A full gloss counts as one item, same as a bare reuse.',
          items: {
            type: 'object',
            properties: {
              word: { type: 'string', description: 'The hanzi as used, e.g. 提交.' },
              context: {
                type: 'string',
                description: 'Short note on what it rode along on, e.g. "the 13 Diplomat commits". Becomes the usage note.',
              },
              glossed: { type: 'boolean', description: 'Whether it carried a full inline gloss this time.' },
            },
            required: ['word'],
          },
        },
        reply_words: {
          type: 'integer',
          description: 'Total word count of the reply (English + Chinese items), used to compute the density percentage.',
        },
        meta: {
          type: 'boolean',
          description:
            'True if this is a meta reply — one whose subject IS the experiment, the wordlist, or the language itself, with nothing to act on. Widens the band to ~15% / 6-12 items.',
        },
      },
      required: ['items', 'reply_words'],
    },
  },
  {
    name: 'drip_level',
    description:
      'Promote or demote a tracked word. Use on real evidence: promote when the user uses it correctly, translates it back, or clearly reads it without help; demote the moment they ask what it means, guess wrong, or go blank. Handles level-4 graduation automatically — the row is deleted, the hanzi is appended to the flat Learned list, and each of its bricks is flattened too once every word that brick was taught in is learned. Demotion out of 4 rebuilds the row.',
    inputSchema: {
      type: 'object',
      properties: {
        word: { type: 'string', description: 'The hanzi, e.g. 完成.' },
        level: { type: 'integer', minimum: 0, maximum: 4, description: 'Absolute target level 0-4.' },
        delta: { type: 'integer', description: 'Relative move instead, e.g. 1 to promote, -1 to demote.' },
        reason: { type: 'string', description: 'The evidence, e.g. "user set" or "translated it back unprompted".' },
      },
      required: ['word'],
    },
  },
  {
    name: 'drip_add',
    description:
      'Commit a new tracked word to the dictionary at level 0, with its character breakdown. Also registers any new bricks. If the word is in the pipeline it is pulled out of it. Warns when the reply (0-1) or session (2-4) new-tracked-word budget is already spent — the drip is meant to stay small.',
    inputSchema: {
      type: 'object',
      properties: {
        hanzi: { type: 'string' },
        pinyin: { type: 'string', description: 'With tone marks — tones ARE the word for a beginner.' },
        meaning: { type: 'string' },
        parts: { type: 'string', description: 'Human-readable breakdown, e.g. "代 substitute + 码 code".' },
        chars: {
          type: 'array',
          items: { type: 'string' },
          description: 'The characters of the word, in order, for brick linkage and graduation.',
        },
        bricks: {
          type: 'array',
          description: 'Any characters not already tracked, so the Characters table stays complete.',
          items: {
            type: 'object',
            properties: {
              char: { type: 'string' },
              pinyin: { type: 'string' },
              meaning: { type: 'string' },
              tags: { type: 'string', description: 'R if it often acts as a radical, P if often a phonetic.' },
              note: { type: 'string', description: 'Where it appears and what it recurs in.' },
            },
            required: ['char', 'pinyin', 'meaning'],
          },
        },
        note: { type: 'string', description: 'What deed it was introduced on.' },
      },
      required: ['hanzi', 'pinyin', 'meaning'],
    },
  },
];

function toolStatus(state, args) {
  const { session, fresh } = currentSession(state, args.new_session === true);
  saveState(state);

  const byLevel = {};
  for (const w of [...state.words].sort((a, b) => a.level - b.level)) {
    (byLevel[w.level] ||= []).push({
      hanzi: w.hanzi,
      pinyin: w.pinyin,
      meaning: w.meaning,
      use: LEVEL_RULE[w.level],
      gloss: w.level === 0 ? fullGloss(state, w) : undefined,
      footer: w.level === 1 ? footerGloss(w) : undefined,
      uses: (w.uses || []).length,
      parts: w.parts,
    });
  }

  const repeatedPassthrough = Object.entries(state.passthrough)
    .filter(([, v]) => v.count >= 2)
    .map(([k, v]) => `${k} (${v.count}× — promote to tracked)`);

  return {
    level: state.level,
    session: {
      id: session.id,
      fresh,
      replies: session.replies,
      chinese_items: session.items,
      new_tracked: session.new_tracked,
      new_tracked_remaining: Math.max(0, SESSION_NEW_TRACKED_BUDGET - session.new_tracked.length),
    },
    bands: BANDS,
    words_by_level: byLevel,
    footer_reminders_needed_if_used: state.words.filter((w) => w.level === 1).map(footerGloss),
    learned: state.learned,
    bricks: state.bricks.map((b) => `${b.char} ${b.pinyin} "${b.meaning}"${b.tags ? ` [${b.tags}]` : ''}`),
    pipeline: state.pipeline.map((p) => `${p.hanzi} ${p.pinyin} ${p.meaning}`),
    repeated_passthrough: repeatedPassthrough,
    reminder:
      'English is the working language. Payload (code, commands, paths, identifiers, numbers, verbatim errors) stays 100% English. Never let an unglossed unknown word carry a load-bearing detail.',
  };
}

function toolRecord(state, args) {
  const items = args.items || [];
  const band = args.meta ? BANDS.meta : BANDS.normal;
  const { session } = currentSession(state, false);
  const date = today();

  const tracked = [];
  const passthrough = [];
  const promoted = [];

  for (const item of items) {
    const word = findWord(state, item.word);
    if (word) {
      word.uses ||= [];
      word.uses.push({ date, context: item.context || '', glossed: !!item.glossed });
      tracked.push(item.word);
      const sinceLevel = word.uses.filter((u) => !word.leveled_at || u.date >= word.leveled_at).length;
      if (word.level < 4 && sinceLevel >= 3) {
        promoted.push(
          `${word.hanzi} — ${sinceLevel} uses at level ${word.level}; promote if the user has shown recall (evidence, not exposure count)`,
        );
      }
    } else if (state.learned.words.includes(item.word)) {
      tracked.push(`${item.word} (learned)`);
    } else {
      const entry = (state.passthrough[item.word] ||= { count: 0, uses: [] });
      entry.count += 1;
      entry.uses.push({ date, context: item.context || '' });
      passthrough.push(item.word);
    }
  }

  session.replies += 1;
  session.items += items.length;
  session.last = new Date().toISOString();
  saveState(state);

  const pct = args.reply_words > 0 ? (items.length / args.reply_words) * 100 : 0;
  const overCap = pct > band.cap;
  const overItems = items.length > band.maxItems;
  const under = items.length < band.minItems;

  let verdict;
  let advice;
  if (overCap || overItems) {
    verdict = 'OVER — cut back';
    advice = `${items.length} items / ${args.reply_words} words = ${pct.toFixed(1)}% (cap ~${band.cap}%, max ${band.maxItems} items). This is the damaging failure: it blocks the work. Drop the least load-bearing items.`;
  } else if (under) {
    verdict = 'UNDER — likely back-loaded';
    advice = `${items.length} items is below the ${band.minItems}-item floor. If the Chinese all sits in the greeting and sign-off, add one or two light touches to the middle — not a flood.`;
  } else {
    verdict = 'IN BAND';
    advice = `${items.length} items / ${args.reply_words} words = ${pct.toFixed(1)}% (${band.minItems}-${band.maxItems} items, cap ~${band.cap}%).`;
  }

  const warnings = [];
  const repeats = passthrough.filter((w) => state.passthrough[w].count >= 2);
  if (repeats.length) {
    warnings.push(`Pass-through words now used 2+ times — promote to tracked with drip_add: ${repeats.join(', ')}`);
  }
  const needFooter = tracked
    .map((h) => findWord(state, h))
    .filter((w) => w && w.level === 1)
    .map(footerGloss);
  if (needFooter.length) {
    warnings.push(`Level-1 words used — the reply MUST end with: Reminder: ${needFooter.join(' · ')}`);
  }

  return {
    verdict,
    advice,
    band: args.meta ? 'meta (~15%)' : 'normal (~10%)',
    density_percent: Number(pct.toFixed(1)),
    items: items.length,
    tracked_used: tracked,
    passthrough_used: passthrough,
    warnings,
    promotion_candidates: promoted,
    session: {
      id: session.id,
      replies: session.replies,
      chinese_items: session.items,
      new_tracked_remaining: Math.max(0, SESSION_NEW_TRACKED_BUDGET - session.new_tracked.length),
    },
  };
}

function toolLevel(state, args) {
  const hanzi = args.word;
  const learned = state.learned.words.includes(hanzi);
  const word = findWord(state, hanzi);
  if (!word && !learned) {
    return { error: `${hanzi} is not tracked. Use drip_add to commit it at level 0.` };
  }

  const from = learned ? 4 : word.level;
  let to = typeof args.level === 'number' ? args.level : from + (args.delta || 0);
  to = Math.max(0, Math.min(4, to));
  if (to === from) return { note: `${hanzi} already at level ${from}; nothing changed.` };

  const result = { word: hanzi, from, to, reason: args.reason || '' };

  if (learned && to < 4) {
    const rebuilt = ungraduate(state, hanzi, Math.max(2, to));
    result.to = rebuilt.level;
    result.action = `Demoted out of 4 — row rebuilt at level ${rebuilt.level} and re-glossed.`;
  } else if (to === 4) {
    state.archive ||= {};
    state.archive[hanzi] = { ...word };
    for (const c of word.chars || []) {
      const b = findBrick(state, c);
      if (b) state.archive[`brick:${c}`] = { ...b };
    }
    const moved = graduate(state, word);
    result.action = `Graduated to 4 — row deleted, hanzi appended to the Learned list.${
      moved.bricks.length ? ` Bricks flattened too (every word they were taught in is now learned): ${moved.bricks.join(' · ')}` : ''
    }`;
  } else {
    word.level = to;
    word.leveled_at = today();
    (word.notes ||= []).push(`${args.reason || 'relevel'} → lvl ${to} ${today()}`);
    result.action = `Now at level ${to}: ${LEVEL_RULE[to]}.`;
    if (to === 0) result.gloss = fullGloss(state, word);
    if (to === 1) result.footer = footerGloss(word);
  }

  saveState(state);
  return result;
}

function toolAdd(state, args) {
  if (findWord(state, args.hanzi) || state.learned.words.includes(args.hanzi)) {
    return { error: `${args.hanzi} is already tracked.` };
  }
  const { session } = currentSession(state, false);

  for (const b of args.bricks || []) {
    if (!findBrick(state, b.char) && !isBrickLearned(state, b.char)) state.bricks.push(b);
  }

  const word = {
    hanzi: args.hanzi,
    pinyin: args.pinyin,
    meaning: args.meaning,
    level: 0,
    parts: args.parts || '',
    chars: args.chars || Array.from(args.hanzi),
    added: today(),
    leveled_at: today(),
    notes: args.note ? [args.note] : [],
    uses: [],
  };
  state.words.push(word);

  const before = state.pipeline.length;
  state.pipeline = state.pipeline.filter((p) => p.hanzi !== args.hanzi);
  delete state.passthrough[args.hanzi];

  session.new_tracked.push(args.hanzi);
  session.last = new Date().toISOString();
  saveState(state);

  const warnings = [];
  if (session.new_tracked.length > SESSION_NEW_TRACKED_BUDGET) {
    warnings.push(
      `Session budget is ~${SESSION_NEW_TRACKED_BUDGET} new tracked words; this is #${session.new_tracked.length}. Reinforcement beats novelty — prefer reusing known words.`,
    );
  }
  if (session.new_tracked.length > REPLY_NEW_TRACKED_BUDGET) {
    warnings.push(`Keep it to ${REPLY_NEW_TRACKED_BUDGET} new tracked word per reply.`);
  }

  return {
    added: args.hanzi,
    level: 0,
    gloss: fullGloss(state, word),
    use: LEVEL_RULE[0],
    pulled_from_pipeline: before !== state.pipeline.length,
    session_new_tracked: session.new_tracked,
    warnings,
  };
}

const HANDLERS = {
  drip_status: toolStatus,
  drip_record: toolRecord,
  drip_level: toolLevel,
  drip_add: toolAdd,
};

// ------------------------------------------------------------ MCP transport

const SUPPORTED_PROTOCOLS = ['2025-06-18', '2025-03-26', '2024-11-05'];

function handle(msg) {
  const { id, method, params } = msg;

  if (method === 'initialize') {
    const asked = params && params.protocolVersion;
    return {
      protocolVersion: SUPPORTED_PROTOCOLS.includes(asked) ? asked : SUPPORTED_PROTOCOLS[0],
      capabilities: { tools: {} },
      serverInfo: { name: 'chinese-drip-counter', version: '1.0.0' },
      instructions:
        'Bookkeeping for the chinese-drip immersion experiment. Call drip_status once early in a session instead of reading wordlist.md, and drip_record after composing any reply that contains Chinese to check it against the density band before sending.',
    };
  }
  // notifications/initialized and friends are fire-and-forget; acknowledging them
  // as unknown methods would spam stderr on every client handshake.
  if (method.startsWith('notifications/')) return {};
  if (method === 'ping') return {};
  if (method === 'tools/list') return { tools: TOOLS };
  if (method === 'resources/list') return { resources: [] };
  if (method === 'prompts/list') return { prompts: [] };

  if (method === 'tools/call') {
    const handler = HANDLERS[params && params.name];
    if (!handler) {
      const err = new Error(`Unknown tool: ${params && params.name}`);
      err.code = -32602;
      throw err;
    }
    const state = loadState();
    const result = handler(state, (params && params.arguments) || {});
    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
      isError: !!result.error,
    };
  }

  const err = new Error(`Method not found: ${method}`);
  err.code = -32601;
  throw err;
}

let buffer = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let nl;
  while ((nl = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, nl).trim();
    buffer = buffer.slice(nl + 1);
    if (!line) continue;

    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      process.stdout.write(
        `${JSON.stringify({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } })}\n`,
      );
      continue;
    }

    // Notifications carry no id and must never get a response.
    const isNotification = msg.id === undefined || msg.id === null;
    try {
      const result = handle(msg);
      if (!isNotification) process.stdout.write(`${JSON.stringify({ jsonrpc: '2.0', id: msg.id, result })}\n`);
    } catch (e) {
      if (!isNotification) {
        process.stdout.write(
          `${JSON.stringify({
            jsonrpc: '2.0',
            id: msg.id,
            error: { code: e.code || -32603, message: e.message },
          })}\n`,
        );
      } else {
        process.stderr.write(`[chinese-drip-counter] ${e.message}\n`);
      }
    }
  }
});

process.stdin.on('end', () => process.exit(0));
