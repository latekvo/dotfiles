import { expect, mock, test } from 'claude-code/testing'
import type { On, PromptEditInput, PromptEditResult } from 'claude-code'

import { fit } from '../hooks/layout'

const PLUGIN = 'session-title'
const TRANSCRIPT = '/t/session.jsonl'
const FULLSCREEN = { columns: 160, rows: 45, isFullscreen: true }
const MESSAGE = {
  text: 'hi',
  origin: { kind: 'composer' },
  isExpanded: false,
} as const

const BAND = {
  hasSurvey: false,
  isCollapsed: false,
  isWorking: false,
  maxRows: 10,
  bodyColumns: 100,
  scroll: { offset: 0, bodyRows: 10 },
  view: {},
} as const
const PANE = {
  title: 'Session title',
  isFocused: true,
  bodyColumns: 40,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 20 },
  view: {},
} as const

// A session whose transcript holds `entries`; /rename runs `ran`, then appends
// its custom-title as the engine does.
function engine(on: On, entries: object[], ran: () => Promise<void> | void = () => {}) {
  const lines = [...entries]
  const renames: string[] = []
  const opened: unknown[] = []
  const toasts: string[] = []
  on('classic.SessionStart', () => ({}))
  on('turn.complete', () => ({ text: '' }))
  on('process.run', () => ({
    value: {
      exitCode: 0,
      stdout: lines.map(line => JSON.stringify(line)).join('\n'),
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))
  on('command.run', async (_, e) => {
    renames.push(e.args)
    await ran()
    lines.push({ type: 'custom-title', customTitle: e.args })

    return { text: '' }
  })
  on('ui.open', (_, e) => {
    opened.push(e)

    return { value: { isPlaced: true } }
  })
  on('ui.close', () => ({ value: undefined }))
  on('ui.toast', (_, e) => {
    toasts.push(e.text)

    return { value: undefined }
  })

  return { renames, opened, toasts }
}

test('fit keeps a short title on one row of its own width', async () => {
  expect(fit('Tree facts', 64)).toEqual(['Tree facts'])
})

test('fit breaks a long title at a late space and pads both rows', async () => {
  expect(fit('alpha beta gamma', 12)).toEqual(['alpha beta', 'gamma     '])
})

test('fit breaks mid-word past an early space and ends a cut text in an ellipsis', async () => {
  expect(fit('ab cdefghijklmnopqrstuvwxyz', 10)).toEqual(['ab cdefghi', 'jklmnopqr…'])
})

test('a renamed title wins over the generated one', async ($, on) => {
  engine(on, [
    { type: 'ai-title', aiTitle: 'Generated' },
    { type: 'custom-title', customTitle: 'Renamed' },
    { type: 'ai-title', aiTitle: 'Generated again' },
  ])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const band = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'desktop',
    component: 'AbovePrompt',
    props: BAND,
  })
  expect((await band.find({ type: 'Text' }))?.text).toBe('Renamed')
  await band.unmount()
})

test('an emptied custom title gives way to the generated one', async ($, on) => {
  engine(on, [
    { type: 'custom-title', customTitle: 'Renamed' },
    { type: 'ai-title', aiTitle: 'Generated' },
    { type: 'custom-title', customTitle: '' },
  ])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const band = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'desktop',
    component: 'AbovePrompt',
    props: BAND,
  })
  expect((await band.find({ type: 'Text' }))?.text).toBe('Generated')
  await band.unmount()
})

test('the pane renames through /rename with the title trimmed and collapsed', async ($, on) => {
  const { renames } = engine(on, [{ type: 'ai-title', aiTitle: 'Old' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const pane = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'Pane',
    requestId: 'session-title',
    props: PANE,
  })
  await pane.input({ key: 'title', text: '  New \n  name ' })
  expect(renames).toEqual(['New name'])
  await pane.unmount()
})

test('the pane ignores an empty or unchanged title', async ($, on) => {
  const { renames } = engine(on, [{ type: 'ai-title', aiTitle: 'Old' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const pane = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'Pane',
    requestId: 'session-title',
    props: PANE,
  })
  await pane.input({ key: 'title', text: '   ' })
  await pane.input({ key: 'title', text: ' Old ' })
  expect(renames).toEqual([])
  await pane.unmount()
})

test('a failed /rename is reported and the card keeps the session title', async ($, on) => {
  const { toasts } = engine(on, [{ type: 'ai-title', aiTitle: 'Old' }], () => {
    throw new Error('busy')
  })
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const band = await $.ui.mount({ plugin: PLUGIN, surface: 'desktop', component: 'AbovePrompt', props: BAND })
  const pane = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'Pane',
    requestId: 'session-title',
    props: PANE,
  })
  await pane.input({ key: 'title', text: 'New' })
  expect(toasts).toEqual([expect.stringMatching(/^Could not rename the session: /)])
  expect((await band.find({ type: 'Text' }))?.text).toBe('Old')
  await pane.unmount()
  await band.unmount()
})

test('a refresh while /rename is pending keeps the new title', async ($, on) => {
  let release = () => {}
  const held = new Promise<void>(resolve => {
    release = resolve
  })
  engine(on, [{ type: 'ai-title', aiTitle: 'Old' }], () => held)
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const band = await $.ui.mount({ plugin: PLUGIN, surface: 'desktop', component: 'AbovePrompt', props: BAND })
  const pane = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'Pane',
    requestId: 'session-title',
    props: PANE,
  })
  const renaming = pane.input({ key: 'title', text: 'New' })
  await $.turn.complete({ answer: '', durationMs: 0, isAborted: false, turnId: 't', reason: 'answer' })
  expect((await band.find({ type: 'Text' }))?.text).toBe('New')

  release()
  await renaming
  expect((await band.find({ type: 'Text' }))?.text).toBe('New')
  await pane.unmount()
  await band.unmount()
})

test('the row cut by the top edge hosts the card there; click, type and Enter rename', async ($, on) => {
  const clock = mock.clock(on)
  const { renames, opened } = engine(on, [{ type: 'ai-title', aiTitle: 'Tree facts' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const above = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'above',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 0, last: 3, of: 4 } },
  })
  const row = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'cut',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 3, last: 5, of: 6 } },
  })
  await clock.advance(1)

  expect(await above.find({ type: 'Client' })).toBeUndefined()
  expect(await row.drawn()).toMatchObject({
    type: 'Box',
    children: [expect.anything(), { type: 'Box', props: { position: 'absolute', top: 3, right: 0 } }],
  })
  const card = await row.find({ type: 'Client' })
  expect(card?.key).toBe('card-0')
  expect((await row.find({ type: 'Text', in: 'card-0' }))?.text).toBe('Tree facts')

  await row.press({ key: 'shortcut' })
  expect(opened).toMatchObject([{ id: 'session-title', focus: true }])

  await row.pointer({ type: 'down', x: 0, y: 0, button: 'left', in: 'card-0' })
  for (const key of ['space', 'f5', 'clear', '2']) await row.key({ key, in: 'card-0' })
  await row.key({ key: 'return', in: 'card-0' })
  expect(renames).toEqual(['Tree facts 2'])
  expect((await row.find({ type: 'Client' }))?.key).toBe('card-1')
  await row.redraw({ ...MESSAGE, onScreen: null })
  await clock.advance(1)
  expect(opened).toHaveLength(1)
  await above.unmount()
  await row.unmount()
})

test('typing in the prompt closes an edit the card was left in', async ($, on) => {
  const clock = mock.clock(on)
  const { renames } = engine(on, [{ type: 'ai-title', aiTitle: 'Kept' }])
  on('prompt.edit', (_, e) => ({ text: e.text, cursor: e.cursor }))
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const row = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 0, last: 1, of: 2 } },
  })
  await clock.advance(1)
  const edit: PromptEditInput = { origin: { kind: 'composer' }, text: 'x', cursor: 1, start: 0, end: 0, inputText: 'x' }
  // The kit raises prompt.edit, which its typings leave off the prompt noun.
  const prompt = $.prompt as unknown as { edit: (e: PromptEditInput) => Promise<PromptEditResult> }

  await prompt.edit(edit)
  expect((await row.find({ type: 'Client' }))?.key).toBe('card-0')

  await row.pointer({ type: 'down', x: 0, y: 0, button: 'left', in: 'card-0' })
  await prompt.edit(edit)
  expect((await row.find({ type: 'Client' }))?.key).toBe('card-1')
  expect((await row.find({ type: 'Text', in: 'card-1' }))?.text).toBe('Kept')
  expect(renames).toEqual([])
  await row.unmount()
})

test('an edit whose row scrolls away carries on in the pane', async ($, on) => {
  const clock = mock.clock(on)
  const { opened, renames } = engine(on, [{ type: 'ai-title', aiTitle: 'Kept' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const visible = { ...MESSAGE, onScreen: { first: 0, last: 1, of: 2 } }
  const top = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'top',
    viewport: FULLSCREEN,
    props: visible,
  })
  const below = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'below',
    viewport: FULLSCREEN,
    props: visible,
  })
  await clock.advance(1)
  await top.pointer({ type: 'down', x: 0, y: 0, button: 'left', in: 'card-0' })
  await top.key({ key: ' 2', in: 'card-0' })
  await below.redraw({ ...MESSAGE, onScreen: { first: 1, last: 1, of: 2 } })
  await clock.advance(1)
  expect(opened).toEqual([])

  await top.redraw({ ...MESSAGE, onScreen: null })
  await clock.advance(1)
  expect(opened).toMatchObject([{ id: 'session-title', focus: true }])
  const pane = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'Pane',
    requestId: 'session-title',
    props: PANE,
  })
  expect((await pane.find({ key: 'title' }))?.props.value).toBe('Kept 2')
  await pane.input({ key: 'title', text: 'Kept 2' })
  expect(renames).toEqual(['Kept 2'])
  await below.redraw({ ...MESSAGE, onScreen: null })
  await clock.advance(1)
  expect(opened).toHaveLength(1)
  await pane.unmount()
  await top.unmount()
  await below.unmount()
})

test('a host that never draws again is dropped for the next visible row', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, [{ type: 'ai-title', aiTitle: 'Kept' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const gone = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'gone',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 0, last: 1, of: 2 } },
  })
  await gone.unmount()
  const next = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    requestId: 'next',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 0, last: 1, of: 2 } },
  })
  await clock.advance(1)
  expect(await next.find({ type: 'Client' })).toBeUndefined()

  await clock.advance(1000)
  expect((await next.find({ type: 'Client' }))?.key).toBe('card-0')
  await next.unmount()
})

test('an untitled session hosts no card but keeps the shortcut', async ($, on) => {
  const clock = mock.clock(on)
  const { opened } = engine(on, [])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const row = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    viewport: FULLSCREEN,
    props: { ...MESSAGE, onScreen: { first: 0, last: 1, of: 2 } },
  })
  await clock.advance(1)
  expect(await row.find({ type: 'Client' })).toBeUndefined()
  await row.press({ key: 'shortcut' })
  expect(opened).toMatchObject([{ id: 'session-title' }])
  await row.unmount()
})

test('a notice under the logo never hosts the card', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, [{ type: 'ai-title', aiTitle: 'Kept' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const notice = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'InfoNotice',
    viewport: FULLSCREEN,
    props: { text: 'Debug mode enabled', command: null, onScreen: { first: 0, last: 0, of: 1 } },
  })
  await clock.advance(1000)
  expect(await notice.find({ type: 'Client' })).toBeUndefined()
  await notice.unmount()
})

test('off the fullscreen layout no row hosts the card', async ($, on) => {
  const clock = mock.clock(on)
  engine(on, [{ type: 'ai-title', aiTitle: 'Kept' }])
  await $.classic.SessionStart({ source: 'startup', transcript_path: TRANSCRIPT })
  const row = await $.ui.mount({
    plugin: PLUGIN,
    surface: 'terminal',
    component: 'UserMessage',
    viewport: { columns: 160, rows: 45, isFullscreen: false },
    props: { ...MESSAGE, onScreen: { first: 2, last: 3, of: 4 } },
  })
  await clock.advance(1000)
  expect(await row.find({ type: 'Client' })).toBeUndefined()
  expect(await row.find({ type: 'Button' })).toBeUndefined()
  await row.unmount()
})
