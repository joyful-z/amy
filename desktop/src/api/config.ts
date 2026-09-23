/** Amy Host 地址与 WebSocket 地址（可通过 VITE_AGENT_SERVER_URL 覆盖）。
 *
 * 桌面端默认连本机 Host；浏览器从其他机器访问 Web 版时，默认连接同一台
 * 服务器的 8000 端口，避免写死 127.0.0.1 导致远程用户连到自己的电脑。
 */

function defaultServerUrl(): string {
  if (typeof window === 'undefined') return 'http://127.0.0.1:8000'

  const { hostname, protocol } = window.location
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return 'http://127.0.0.1:8000'
  }

  return `${protocol}//${hostname}:8000`
}

export const SERVER_URL: string =
  (import.meta.env.VITE_AGENT_SERVER_URL as string | undefined) ??
  defaultServerUrl()

export const WS_URL: string = SERVER_URL.replace(/^http/, 'ws')

/** 共享 JSON-RPC WebSocket 端点。 */
export const RPC_URL: string = `${WS_URL}/rpc`
