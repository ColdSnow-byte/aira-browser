import { useEffect, useMemo, useState, type MouseEvent } from 'react';
import { useTranslation } from 'react-i18next';
import type { HistorySyncVisit } from '@/features/sync/history/HistorySyncModels';
import {
  historyFaviconUrl,
  historyHostname,
  useHistorySurfaceData,
} from '../../useHistorySurfaceData';
import { useChromeOtherDeviceTabs } from '../chrome/useChromeOtherDeviceTabs';
import {
  edgeHistoryCopy,
  edgeHistorySearchPlaceholder,
  type EdgeHistorySection,
} from './edgeHistorySpec';
import {
  restoreEdgeSession,
  useEdgeRecentlyClosed,
  type EdgeClosedEntry,
} from './useEdgeRecentlyClosed';
import { formatChromeHistoryDay, formatChromeHistoryTime } from '../chrome/chromeHistorySpec';
import './edge-history.css';

type EdgeMenuState = {
  x: number;
  y: number;
  url: string;
  visitId: string;
};

export function EdgeHistoryPage() {
  const { i18n } = useTranslation();
  const copy = edgeHistoryCopy(i18n.language, globalThis.navigator?.platform || '');
  const data = useHistorySurfaceData();
  const [section, setSection] = useState<EdgeHistorySection>('all');
  const [query, setQuery] = useState('');
  const [theme, setTheme] = useState<'light' | 'dark'>(readEdgeTheme);
  const [menu, setMenu] = useState<EdgeMenuState | null>(null);
  const [expanded, setExpanded] = useState<Record<string, boolean>>({});
  const closed = useEdgeRecentlyClosed(section === 'closed');
  const devices = useChromeOtherDeviceTabs(section === 'devices');

  useEffect(() => {
    document.title = copy.title;
    document.documentElement.dataset.edgeTheme = theme;
    document.body.classList.add('edge-history-body');
    return () => {
      document.body.classList.remove('edge-history-body');
      delete document.documentElement.dataset.edgeTheme;
    };
  }, [copy.title, theme]);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const apply = () => setTheme(readEdgeTheme());
    media.addEventListener('change', apply);
    return () => media.removeEventListener('change', apply);
  }, []);

  const filteredVisits = useMemo(() => filterByQuery(data.visits, query), [data.visits, query]);
  const groups = useMemo(
    () => groupVisits(filteredVisits, i18n.language),
    [filteredVisits, i18n.language],
  );

  const openUrl = (url: string, mode: 'tab' | 'window' | 'private' = 'tab') => {
    if (!url) return;
    if (mode === 'window' || mode === 'private') {
      const windows = globalThis.chrome?.windows;
      if (windows?.create) {
        void windows.create({ url, incognito: mode === 'private', focused: true }).catch(() => {
          void globalThis.chrome?.tabs?.create({ url, active: true });
        });
        return;
      }
    }
    if (globalThis.chrome?.tabs?.create) void globalThis.chrome.tabs.create({ url, active: true });
    else window.open(url, '_blank', 'noopener,noreferrer');
  };

  const openMenu = (event: MouseEvent, url: string, visitId = '') => {
    event.preventDefault();
    const width = 260;
    const height = 280;
    const x = Math.min(event.clientX, window.innerWidth - width - 8);
    const y = Math.min(event.clientY, window.innerHeight - height - 8);
    setMenu({ x: Math.max(8, x), y: Math.max(8, y), url, visitId });
  };

  return (
    <div className="edge-history" data-edge-theme={theme} onClick={() => setMenu(null)}>
      <header className="edge-history-header">
        <h1>{copy.title}</h1>
        <div className="edge-history-tools">
          <button type="button" className="edge-history-icon" aria-label={copy.remove} onClick={openClearData}>
            <TrashIcon />
          </button>
          <span className="edge-history-icon" aria-hidden="true"><MoreIcon /></span>
          <span className="edge-history-icon" aria-hidden="true"><PinIcon /></span>
        </div>
      </header>
      <form className="edge-history-search" role="search" onSubmit={(event) => event.preventDefault()}>
        <SearchIcon />
        <input
          type="search"
          value={query}
          placeholder={edgeHistorySearchPlaceholder(section, copy)}
          aria-label={edgeHistorySearchPlaceholder(section, copy)}
          onChange={(event) => setQuery(event.target.value)}
        />
      </form>
      <div className="edge-history-tabs" role="tablist">
        {(['all', 'closed', 'devices'] as const).map((item) => (
          <button
            key={item}
            type="button"
            role="tab"
            className={section === item ? 'is-selected' : undefined}
            aria-selected={section === item}
            onClick={() => setSection(item)}
          >
            {item === 'all' ? copy.all : item === 'closed' ? copy.closed : copy.devices}
          </button>
        ))}
      </div>
      <div className="edge-history-list">
        {section === 'all' ? (
          data.status === 'login-required' ? <p className="edge-history-status">{copy.login}</p>
            : data.loading && groups.length === 0 ? <p className="edge-history-status">{copy.loading}</p>
              : groups.length === 0 ? <p className="edge-history-status">{copy.empty}</p>
                : groups.map((group) => (
                  <section key={group.label}>
                    <h2 className="edge-history-day">{group.label}</h2>
                    {group.visits.map((visit) => (
                      <button
                        key={visit.visitId}
                        type="button"
                        className="edge-history-row"
                        onClick={() => openUrl(visit.url)}
                        onContextMenu={(event) => openMenu(event, visit.url, visit.visitId)}
                      >
                        <Favicon url={visit.url} />
                        <span className="title">{visit.title || historyHostname(visit.url) || visit.url}</span>
                        <span className="edge-history-time">{formatChromeHistoryTime(visit.visitedAt, i18n.language)}</span>
                      </button>
                    ))}
                  </section>
                ))
        ) : null}
        {section === 'closed' ? (
          <ClosedList
            copy={copy}
            entries={filterClosed(closed.entries, query)}
            loading={closed.loading}
            expanded={expanded}
            onToggle={(id) => setExpanded((current) => ({ ...current, [id]: !current[id] }))}
          />
        ) : null}
        {section === 'devices' ? (
          <DeviceList
            copy={copy}
            devices={devices.devices}
            loading={devices.loading}
            error={devices.error}
            query={query}
            onOpen={openUrl}
          />
        ) : null}
      </div>
      {menu ? (
        <div className="edge-history-menu" style={{ left: menu.x, top: menu.y }} onClick={(event) => event.stopPropagation()}>
          <button type="button" onClick={() => { openUrl(menu.url); setMenu(null); }}><TabIcon />{copy.openTab}</button>
          <button type="button" onClick={() => { openUrl(menu.url, 'window'); setMenu(null); }}><WindowIcon />{copy.openWindow}</button>
          <button type="button" onClick={() => { openUrl(menu.url, 'private'); setMenu(null); }}><PrivateIcon />{copy.openPrivate}</button>
          <div className="divider" />
          <button type="button" onClick={() => { void navigator.clipboard?.writeText(menu.url); setMenu(null); }}><CopyIcon />{copy.copyLink}</button>
          <button type="button" onClick={() => { if (menu.visitId) void data.deleteVisit(menu.visitId); setMenu(null); }}><TrashIcon />{copy.remove}</button>
          <div className="divider" />
          <button
            type="button"
            className="site-more"
            onClick={() => {
              setSection('all');
              setQuery(historyHostname(menu.url));
              setMenu(null);
            }}
          >{copy.moreFromSite}</button>
        </div>
      ) : null}
    </div>
  );
}

function ClosedList({
  copy,
  entries,
  loading,
  expanded,
  onToggle,
}: {
  copy: ReturnType<typeof edgeHistoryCopy>;
  entries: EdgeClosedEntry[];
  loading: boolean;
  expanded: Record<string, boolean>;
  onToggle: (id: string) => void;
}) {
  if (loading && entries.length === 0) return <p className="edge-history-status">{copy.loading}</p>;
  if (entries.length === 0) return <p className="edge-history-status">{copy.emptyClosed}</p>;
  return (
    <>
      {entries.map((entry, index) => {
        const grouped = entry.tabs.length > 1;
        const title = grouped ? `${entry.title} ${copy.andMore(entry.tabs.length - 1)}` : entry.title;
        return (
          <div key={entry.id}>
            <button
              type="button"
              className="edge-history-closed"
              onClick={() => grouped ? onToggle(entry.id) : restoreEdgeSession(entry.sessionId, entry.url)}
            >
              {grouped ? <ChevronIcon open={expanded[entry.id] === true} /> : <Favicon url={entry.url} />}
              <span className="title">{title}</span>
              <span className="edge-history-hint">{index === 0 && !grouped ? copy.reopenHint : ''}</span>
            </button>
            {grouped && expanded[entry.id] ? entry.tabs.map((tab) => (
              <button
                key={tab.sessionId || tab.url}
                type="button"
                className="edge-history-closed is-child"
                onClick={() => restoreEdgeSession(tab.sessionId, tab.url)}
              >
                <Favicon url={tab.url} />
                <span className="title">{tab.title || tab.url}</span>
                <span />
              </button>
            )) : null}
          </div>
        );
      })}
    </>
  );
}

function DeviceList({
  copy,
  devices,
  loading,
  error,
  query,
  onOpen,
}: {
  copy: ReturnType<typeof edgeHistoryCopy>;
  devices: ReturnType<typeof useChromeOtherDeviceTabs>['devices'];
  loading: boolean;
  error: string;
  query: string;
  onOpen: (url: string) => void;
}) {
  const needle = query.trim().toLowerCase();
  const visible = devices.map((device) => ({
    ...device,
    tabs: device.tabs.filter((tab) => !needle || `${tab.title} ${tab.url}`.toLowerCase().includes(needle)),
  })).filter((device) => device.tabs.length > 0);
  if (loading && visible.length === 0) return <p className="edge-history-status">{copy.loading}</p>;
  if (error && visible.length === 0) return <p className="edge-history-status">{error}</p>;
  if (visible.length === 0) return <p className="edge-history-status">{copy.emptyDevices}</p>;
  return (
    <>
      {visible.map((device) => (
        <section key={device.deviceId}>
          <h2 className="edge-history-day">{device.deviceName || device.model || device.platform}</h2>
          {device.tabs.map((tab, index) => (
            <button
              key={`${device.deviceId}:${tab.url}:${index}`}
              type="button"
              className="edge-history-row"
              onClick={() => onOpen(tab.url)}
            >
              <Favicon url={tab.url} />
              <span className="title">{tab.title || historyHostname(tab.url) || tab.url}</span>
              <span />
            </button>
          ))}
        </section>
      ))}
    </>
  );
}

function readEdgeTheme(): 'light' | 'dark' {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function openClearData(): void {
  const url = 'edge://settings/clearBrowserData';
  if (globalThis.chrome?.tabs?.create) void globalThis.chrome.tabs.create({ url });
}

function filterByQuery(visits: HistorySyncVisit[], query: string): HistorySyncVisit[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return visits;
  return visits.filter((visit) => `${visit.title} ${visit.url}`.toLowerCase().includes(needle));
}

function filterClosed(entries: EdgeClosedEntry[], query: string): EdgeClosedEntry[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return entries;
  return entries.filter((entry) => `${entry.title} ${entry.url} ${entry.tabs.map((tab) => `${tab.title} ${tab.url}`).join(' ')}`.toLowerCase().includes(needle));
}

function groupVisits(visits: HistorySyncVisit[], language: string) {
  const groups = new Map<string, HistorySyncVisit[]>();
  visits.forEach((visit) => {
    const label = formatChromeHistoryDay(visit.visitedAt, language);
    const group = groups.get(label) || [];
    group.push(visit);
    groups.set(label, group);
  });
  return Array.from(groups, ([label, grouped]) => ({ label, visits: grouped }));
}

function Favicon({ url }: { url: string }) {
  const [failed, setFailed] = useState(false);
  const src = historyFaviconUrl(url);
  if (!src || failed) return <GlobeIcon />;
  return <img className="edge-history-favicon" src={src} alt="" onError={() => setFailed(true)} />;
}

function SearchIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="11" cy="11" r="6.25" stroke="currentColor" strokeWidth="1.8" />
      <path d="M16 16.5 20 20.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 7.5h14M9.5 7.2V5.8h5v1.4M8 7.5 8.8 18h6.4l.8-10.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function MoreIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <circle cx="6" cy="12" r="1.5" /><circle cx="12" cy="12" r="1.5" /><circle cx="18" cy="12" r="1.5" />
    </svg>
  );
}

function PinIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M8 10.5 14.5 4l5.5 5.5-6.5 6.5" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M10 14.5 4.5 20" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

function GlobeIcon() {
  return (
    <svg className="edge-history-favicon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="1.6" />
      <path d="M4 12h16M12 4c2.2 2.4 2.2 13.6 0 16M12 4c-2.2 2.4-2.2 13.6 0 16" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}

function ChevronIcon({ open }: { open: boolean }) {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" aria-hidden="true" style={{ transform: open ? 'rotate(90deg)' : undefined }}>
      <path d="M9 6l8 6-8 6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function TabIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="4" y="5" width="16" height="14" rx="2" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}

function WindowIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="3" y="4" width="18" height="16" rx="2" stroke="currentColor" strokeWidth="1.6" />
      <path d="M3 8h18" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}

function PrivateIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M7 11V8a5 5 0 0 1 10 0v3" stroke="currentColor" strokeWidth="1.6" />
      <rect x="5" y="11" width="14" height="9" rx="2" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}

function CopyIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M8 8h10v12H8z" stroke="currentColor" strokeWidth="1.6" />
      <path d="M6 16H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}
