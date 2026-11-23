import { atom, memberOf, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CardMessage } from '../types'
import { BACKGROUND, fit } from './layout'

const PANE = 'session-title'
// ctrl+shift+y is bound to this in ~/.claude/keybindings.json; the REPL has no handler
// for it, so a mounted Button naming it gets the chord.
const SHORTCUT = 'app:toggleReplTab'
// The transcript rows that report `onScreen`, less InfoNotice: the logo's
// header insets it from the right edge.
const ROWS = [
  'UserMessage',
  'AssistantMessage',
  'ToolUse',
  'ToolResult',
  'ToolGroup',
  'CommandOutput',
  'TurnDuration',
] as const
const HOST_TIMEOUT_MS = 1000
const POLL_MS = 3000
const POLL_LIMIT = 100

const title = atom({ plugin: 'session-title', key: 'title' } as const, null)
const transcript = atom({ plugin: 'session-title', key: 'transcript' } as const, null)
const host = atom({ plugin: 'session-title', key: 'host' } as const, null)
const epoch = atom({ plugin: 'session-title', key: 'epoch' } as const, 0)

// A host member written by an earlier load of this module never equals it.
const LOAD = Math.random().toString(36).slice(2)

type Seen = { order: number; first: number | null }
// In first-draw order, which is transcript order.
const rows = new Map<string, Seen>()
let drawn = 0
let current: string | null = null
// Set when the host draws; a host the transcript dropped never does.
let confirmed: string | null = null
// The card's text while it is being edited.
let draft: string | undefined
// What the pane's field opens with in place of the title.
let seed: string | undefined
// The title of a /rename in flight; the transcript lacks it until that finishes.
let renaming: string | undefined
let isReconcileQueued = false
let poll: { cancel: () => void } | undefined
let polls = 0

// The row whose top sits on the viewport's top edge: the one cut by it, else
// the first visible.
function pickHost(): string | null {
  let found: string | null = null
  let order = Infinity
  for (const [id, row] of rows) {
    if (row.first === null) continue
    if (row.first > 0) return id
    if (row.order < order) {
      found = id
      order = row.order
    }
  }

  return found
}

async function reconcile($: EngineInterface) {
  isReconcileQueued = false
  const next = pickHost()
  if (next === current) return
  if (draft !== undefined) {
    if (current !== null && (rows.get(current)?.first ?? null) !== null) return
    // The edit's row scrolled away, taking the card and its focus with it.
    void openEditor($, draft)
    draft = undefined
  }
  const previous = current
  current = next
  if (previous !== null) await update($, memberOf(host, { requestId: previous }), () => null)
  if (next === null) return
  await update($, memberOf(host, { requestId: next }), () => LOAD)
  $.clock.after(HOST_TIMEOUT_MS, () => {
    if (current !== next || confirmed === next) return
    rows.delete(next)
    void reconcile($)
  })
}

// A render hook may not write state, so the host moves on a timer after it.
function queueReconcile($: EngineInterface) {
  if (isReconcileQueued) return
  isReconcileQueued = true
  $.clock.after(0, () => void reconcile($))
}

async function forgetRows($: EngineInterface) {
  const previous = current
  rows.clear()
  current = null
  if (previous !== null) await update($, memberOf(host, { requestId: previous }), () => null)
}

async function refresh($: EngineInterface) {
  const path = await read($, transcript)
  if (path === null) return
  const found = await $.process
    .run(['grep', '-E', '^\\{"type":"(custom|ai)-title"', path])
    .catch(() => undefined)
  if (found === undefined) return
  let custom: string | undefined
  let generated: string | undefined
  for (const line of found.stdout.split('\n')) {
    let entry: { type?: unknown; customTitle?: unknown; aiTitle?: unknown }
    try {
      entry = JSON.parse(line)
    } catch {
      continue
    }
    if (entry.type === 'custom-title') custom = typeof entry.customTitle === 'string' && entry.customTitle !== '' ? entry.customTitle : undefined
    if (entry.type === 'ai-title' && typeof entry.aiTitle === 'string') generated = entry.aiTitle
  }
  const latest = renaming ?? custom ?? generated
  if (latest === undefined) return
  stopPolling()
  if (latest !== (await read($, title))) await update($, title, () => latest)
}

// The engine names a session a few seconds into its first turn.
function startPolling($: EngineInterface) {
  if (poll !== undefined) return
  polls = 0
  poll = $.clock.every(POLL_MS, () => {
    polls += 1
    if (polls > POLL_LIMIT) stopPolling()
    else void refresh($)
  })
}

function stopPolling() {
  poll?.cancel()
  poll = undefined
}

// Remounting the card ends an edit and returns key focus to the prompt.
async function closeCard($: EngineInterface) {
  draft = undefined
  await update($, epoch, n => n + 1)
  queueReconcile($)
}

async function rename($: EngineInterface, typed: string) {
  const next = typed.replace(/\s+/g, ' ').trim()
  if (next === '' || next === (await read($, title))) return
  await update($, title, () => next)
  renaming = next
  try {
    await $.command.run({ command: 'rename', args: next })
  } catch (error) {
    $.ui.toast(`Could not rename the session: ${String(error)}`)
  } finally {
    renaming = undefined
  }
  await refresh($)
}

async function openEditor($: EngineInterface, text?: string) {
  seed = text
  const shown = text ?? (await read($, title))
  await $.ui.open({
    id: PANE,
    title: 'Session title',
    focus: true,
    closeOnEscape: true,
    holdToasts: true,
    rows: 1,
    columns: Math.max(24, (shown?.length ?? 0) + 12),
  })
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await refresh($)
    if ((await read($, title)) === null) startPolling($)

    return started
  })

  on('classic.SessionStart', async ($, e, next) => {
    await forgetRows($)
    await update($, transcript, () => e.transcript_path)
    if (e.source !== 'compact') await update($, title, () => e.session_title ?? null)
    await refresh($)
    if ((await read($, title)) === null) startPolling($)

    return next(e)
  })

  on('classic.UserPromptSubmit', async ($, e, next) => {
    await update($, transcript, () => e.transcript_path)
    const named = e.session_title
    if (named !== undefined && (await read($, title)) === null) await update($, title, () => named)
    if ((await read($, title)) === null) startPolling($)

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    void refresh($)

    return next(e)
  })

  on('command.run', { command: 'rename' }, async ($, e, next) => {
    const ran = await next(e)
    void refresh($)

    return ran
  })

  // Escape hands the keys back without telling the card: the prompt's next edit closes it.
  on('prompt.edit', async ($, e, next) => {
    if (draft !== undefined) await closeCard($)

    return next(e)
  })

  on('prompt.change', async ($, e, next) => {
    if (draft !== undefined) await closeCard($)

    return next(e)
  })

  on('ui.message', async ($, e, next) => {
    const message = e.data as Partial<CardMessage> | null
    if (message?.type === 'rename' && typeof message.title === 'string') {
      await closeCard($)
      void rename($, message.title)
    } else if (message?.type === 'draft' && typeof message.text === 'string') {
      draft = message.text
    }

    return next(e)
  })

  on('ui.render', { component: ROWS }, async ($, e, next) => {
    const row = await next(e)
    if (e.surface !== 'terminal' || e.viewport?.isFullscreen !== true) return row
    const first = e.props.onScreen?.first ?? null
    const seen = rows.get(e.requestId)
    rows.set(e.requestId, { order: seen?.order ?? drawn++, first })
    queueReconcile($)
    const isHost = (await read($, memberOf(host, e))) === LOAD
    const { Box, Button, Client } = $.ui.resolve(e)
    if (!isHost || first === null) return <Box flexDirection="column">{row}</Box>
    confirmed = e.requestId
    const shown = await read($, title)
    const width = Math.max(12, Math.floor(e.viewport.columns * 0.4))

    return (
      <Box flexDirection="column">
        {row}
        <Box position="absolute" top={first} right={0}>
          {shown !== null && (
            <Client key={`card-${await read($, epoch)}`} module="./card.tsx" props={{ title: shown, width }} />
          )}
          <Box display="none">
            <Button key="shortcut" plain action={SHORTCUT} onPress={() => void openEditor($)}>
              rename
            </Button>
          </Box>
        </Box>
      </Box>
    )
  })

  // Off the fullscreen layout nothing floats over the transcript: the band holds the card.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || (e.surface === 'terminal' && e.viewport?.isFullscreen === true)) return next(e)
    const shown = await read($, title)
    if (shown === null) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box justifyContent="flex-end">
        <Button key="title" plain action={SHORTCUT} onPress={() => void openEditor($)}>
          <Text color="black" backgroundColor={BACKGROUND}>
            {fit(shown, Math.max(12, Math.floor(e.props.bodyColumns * 0.4))).join('\n')}
          </Text>
        </Button>
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Input } = $.ui.resolve(e)

    return (
      <Input
        key="title"
        autoFocus
        value={seed ?? (await read($, title)) ?? ''}
        placeholder="Session title"
        submitLabel="rename"
        onSubmit={typed => {
          void $.ui.close({ id: PANE })
          void rename($, typed)
        }}
      />
    )
  })
}
