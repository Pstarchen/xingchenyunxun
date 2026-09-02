export function buildRealtimeSocketUrl(baseUrl: string, socketPath: string, ticket: string): string {
  let root: string = baseUrl.trim()
  while (root.endsWith('/')) root = root.substring(0, root.length - 1)
  if (root.endsWith('/api')) root = root.substring(0, root.length - 4)
  if (root.startsWith('https://')) {
    root = `wss://${root.substring(8)}`
  } else if (root.startsWith('http://')) {
    root = `ws://${root.substring(7)}`
  } else {
    throw new Error('实时连接仅支持 HTTP 或 HTTPS 地址')
  }
  let path: string = socketPath.trim()
  if (path.length === 0) path = '/ws/realtime'
  if (!path.startsWith('/')) path = `/${path}`
  const delimiter: string = path.includes('?') ? '&' : '?'
  return `${root}${path}${delimiter}ticket=${encodeURIComponent(ticket)}`
}
