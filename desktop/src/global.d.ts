/// <reference types="vite/client" />

interface AmyDesktopApi {
  platform: string
  versions: {
    electron: string
    node: string
    chrome: string
  }
  openExternal: (url: string) => Promise<boolean>
  notify: (notification: {
    title: string
    body: string
    kind: 'approval' | 'run' | 'artifact'
  }) => void
}

interface Window {
  amy?: AmyDesktopApi
}
