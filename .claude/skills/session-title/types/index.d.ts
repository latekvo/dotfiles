export type CardMessage =
  | { type: 'rename'; title: string }
  | { type: 'draft'; text: string }

declare module 'claude-code' {
  interface PluginState {
    'session-title': {
      title: string | null
      transcript: string | null
      // The load token of the row drawing the card; any other value is not the host.
      host: StateFamily<string | null>
      // Part of the card's key: bumped to remount it, closing an edit.
      epoch: number
    }
  }
}
