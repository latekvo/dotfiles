import type { ClientKeyEvent, ClientModule } from 'claude-code'

import type { CardMessage } from '../types'
import { BACKGROUND, fit } from './layout'

type Props = { title: string; width: number }

type State = {
  isEditing: boolean
  text: string
  cursor: number
  // Refreshed every draw for the listeners, which are registered once.
  latest: { props: Props }
}

// The names the terminal gives keys that type nothing; function keys are `f1`, `f2`, ...
const NAMED_KEYS = new Set([
  'up',
  'down',
  'left',
  'right',
  'return',
  'tab',
  'backspace',
  'delete',
  'pageup',
  'pagedown',
  'home',
  'end',
  'escape',
  'insert',
  'clear',
])

// Up to two rows of the text, scrolled so the cursor, possibly one past the end, stays in view.
function visible(text: string, cursor: number, width: number) {
  const room = width * 2
  const offset = Math.max(0, Math.min(cursor + 1 - room, text.length + 1 - room))

  return { offset, shown: text.slice(offset, offset + room) }
}

function edit(state: State, key: ClientKeyEvent): State | CardMessage {
  const { text, cursor } = state
  const at = (next: string, nextCursor: number): State => ({
    ...state,
    text: next,
    cursor: Math.max(0, Math.min(nextCursor, next.length)),
  })

  if (key.ctrl) {
    switch (key.key) {
      case 'a':
        return at(text, 0)
      case 'e':
        return at(text, text.length)
      case 'u':
        return at(text.slice(cursor), 0)
      case 'k':
        return at(text.slice(0, cursor), cursor)
      case 'w': {
        const start = text.slice(0, cursor).replace(/\S+\s*$/, '').length

        return at(text.slice(0, start) + text.slice(cursor), start)
      }
      default:
        return state
    }
  }

  switch (key.key) {
    case 'return':
      return { type: 'rename', title: text }
    case 'left':
      return at(text, cursor - 1)
    case 'right':
      return at(text, cursor + 1)
    case 'home':
      return at(text, 0)
    case 'end':
      return at(text, text.length)
    case 'backspace':
      return at(text.slice(0, Math.max(0, cursor - 1)) + text.slice(cursor), cursor - 1)
    case 'delete':
      return at(text.slice(0, cursor) + text.slice(cursor + 1), cursor)
  }

  if (key.meta || NAMED_KEYS.has(key.key) || /^f\d+$/.test(key.key)) return state

  // A lone space is named; a burst of typing or a paste arrives as one key, and a title is one line.
  const typed = key.key === 'space' ? ' ' : key.key.replace(/[\u0000-\u001f\u007f]+/g, ' ')

  return at(text.slice(0, cursor) + typed + text.slice(cursor), cursor + typed.length)
}

const Card: ClientModule<Props, State> = (props, surface) => {
  const { Box, Text } = surface.elements
  const state = surface.state ?? { isEditing: false, text: '', cursor: 0, latest: { props } }
  state.latest.props = props

  if (surface.state === undefined) {
    surface.onPointer(event => {
      const state = surface.state
      if (state === undefined || event.type !== 'down' || event.button !== 'left') return
      const { width } = state.latest.props

      if (!state.isEditing) {
        const { title } = state.latest.props
        surface.setState({ ...state, isEditing: true, text: title, cursor: title.length })
        surface.post({ type: 'draft', text: title } satisfies CardMessage)

        return
      }

      const { offset } = visible(state.text, state.cursor, width)
      const cursor = Math.min(state.text.length, offset + event.y * width + event.x)
      surface.setState({ ...state, cursor })
    })

    surface.onKey(key => {
      const state = surface.state
      if (state === undefined || !state.isEditing) return
      const next = edit(state, key)

      if ('type' in next) {
        surface.setState({ ...state, isEditing: false })
        surface.post(next)

        return
      }

      surface.setState(next)
      if (next.text !== state.text) surface.post({ type: 'draft', text: next.text } satisfies CardMessage)
    })

    surface.setState(state)
  }


  if (!state.isEditing) {
    return (
      <Box flexDirection="column">
        {fit(props.title, props.width).map(row => (
          <Text color="black" backgroundColor={BACKGROUND}>
            {row}
          </Text>
        ))}
      </Box>
    )
  }

  const { offset, shown } = visible(state.text, state.cursor, props.width)
  const cells = `${shown} `
  const rows: string[] = []
  for (let start = 0; start < cells.length; start += props.width) {
    rows.push(cells.slice(start, start + props.width))
  }
  const columns = Math.max(...rows.map(row => row.length))
  const caret = state.cursor - offset

  return (
    <Box flexDirection="column">
      {rows.map((row, index) => {
        const start = index * props.width
        const padded = row.padEnd(columns)
        const isHere = caret >= start && caret < start + row.length

        return isHere ? (
          <Text color="black" backgroundColor={BACKGROUND}>
            {padded.slice(0, caret - start)}
            <Text inverse>{padded[caret - start]}</Text>
            {padded.slice(caret - start + 1)}
          </Text>
        ) : (
          <Text color="black" backgroundColor={BACKGROUND}>
            {padded}
          </Text>
        )
      })}
    </Box>
  )
}

export default Card
