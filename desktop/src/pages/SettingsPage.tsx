import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'

import { getSystemInfo } from '../api/system'
import ExtensionsSettings from '../components/ExtensionsSettings'
import ModelSettingsPanel from '../components/ModelSettingsPanel'
import { ErrorState } from '../components/PageStates'
import { PageShell } from '../components/PageShell'

export default function SettingsPage(): React.JSX.Element {
  const [section, setSection] = useState<'general' | 'models' | 'extensions'>('general')

  const infoQuery = useQuery({
    queryKey: ['system-info'],
    queryFn: () => getSystemInfo(),
    refetchInterval: 5000,
    retry: false,
  })

  const desktop = window.amy

  return (
    <PageShell
      title="设置"
      subtitle="管理 Amy 的运行环境与扩展能力。"
      maxWidth={1120}
    >
      <div className="settings-layout">
        <aside className="settings-nav" aria-label="设置分类">
          <button className={section === 'general' ? 'active' : ''} onClick={() => setSection('general')}>
            <strong>通用</strong><span>运行环境与权限</span>
          </button>
          <button className={section === 'models' ? 'active' : ''} onClick={() => setSection('models')}>
            <strong>模型</strong><span>Provider 与后台模型</span>
          </button>
          <button className={section === 'extensions' ? 'active' : ''} onClick={() => setSection('extensions')}>
            <strong>扩展能力</strong><span>Skills 与 MCP</span>
          </button>
        </aside>

        <main className="settings-content">
          {section === 'extensions' ? <ExtensionsSettings /> : section === 'models' ? <ModelSettingsPanel /> : (
            <div className="settings-general">
              <header className="settings-content__header">
                <h2>通用</h2>
                <p>查看 Host 和桌面客户端环境。</p>
              </header>

              <section className="settings-group">
                <header className="settings-group__header">
                  <div><h3>Amy Host</h3><p>模型服务与本地数据运行状态</p></div>
                  {!infoQuery.isLoading && !infoQuery.isError ? <span className="settings-status"><i />已连接</span> : null}
                </header>
                {infoQuery.isLoading ? (
                  <div className="settings-loading"><span className="spinner" />正在检查 Host…</div>
                ) : infoQuery.isError ? (
                  <ErrorState
                    message="无法连接 Amy Host"
                    hint="请在 backend 目录运行 python -m app.server，然后重试。"
                    onRetry={() => void infoQuery.refetch()}
                  />
                ) : (
                  <dl className="settings-info-list">
                    <InfoRow label="模型提供商" value={infoQuery.data?.provider ?? '—'} />
                    <InfoRow label="当前模型" value={infoQuery.data?.model ?? '—'} />
                    <InfoRow label="Host 版本" value={infoQuery.data?.version ?? '—'} />
                    <InfoRow label="数据库" value={infoQuery.data?.database ?? '—'} mono />
                  </dl>
                )}
              </section>

              <section className="settings-group">
                <header className="settings-group__header">
                  <div><h3>桌面客户端</h3><p>当前应用与运行环境版本</p></div>
                </header>
                <dl className="settings-info-list">
                  <InfoRow label="应用版本" value="0.1.0" />
                  <InfoRow label="平台" value={desktop?.platform ?? 'web'} />
                  <InfoRow label="Electron" value={desktop?.versions.electron ?? '—'} />
                  <InfoRow label="Chrome / Node" value={`${desktop?.versions.chrome ?? '—'} / ${desktop?.versions.node ?? '—'}`} />
                </dl>
              </section>
            </div>
          )}
        </main>
      </div>
    </PageShell>
  )
}

function InfoRow({
  label,
  value,
  mono = false,
}: {
  label: string
  value: string
  mono?: boolean
}): React.JSX.Element {
  return <div><dt>{label}</dt><dd className={mono ? 'mono' : undefined}>{value}</dd></div>
}
