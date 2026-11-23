export const BACKGROUND = '#fff3b0'

// At most two rows of `width` cells, broken at a space in the first row's
// second half, else mid-word; a cut text ends in an ellipsis. Rows are padded
// to one width so the card is a block.
export function fit(text: string, width: number): string[] {
  if (text.length <= width) return [text]
  const space = text.lastIndexOf(' ', width)
  const cut = space > width / 2 ? space : width
  const first = text.slice(0, cut).trimEnd()
  const rest = text.slice(cut).trimStart()
  const second = rest.length > width ? `${rest.slice(0, width - 1)}…` : rest
  const columns = Math.max(first.length, second.length)
  return [first.padEnd(columns), second.padEnd(columns)]
}
