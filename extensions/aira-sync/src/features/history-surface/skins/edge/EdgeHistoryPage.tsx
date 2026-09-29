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
                      <div
                        key={visit.visitId}
                        className="edge-history-row"
                        onClick={() => openUrl(visit.url)}
                        onContextMenu={(event) => openMenu(event, visit.url, visit.visitId)}
                      >
                        <Favicon url={visit.url} />
                        <span className="title">{visit.title || historyHostname(visit.url) || visit.url}</span>
                        <span className="edge-history-time">{formatChromeHistoryTime(visit.visitedAt, i18n.language)}</span>
                        <button
                          type="button"
                          className="edge-history-remove"
                          aria-label={copy.remove}
                          onClick={(event) => {
                            event.stopPropagation();
                            void data.deleteVisit(visit.visitId);
                          }}
                        >
                          <DismissIcon />
                        </button>
                      </div>
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
    <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
      <path fill="currentColor" d="M8.5 4H11.5C11.5 3.17157 10.8284 2.5 10 2.5C9.17157 2.5 8.5 3.17157 8.5 4ZM7.5 4C7.5 2.61929 8.61929 1.5 10 1.5C11.3807 1.5 12.5 2.61929 12.5 4H17.5C17.7761 4 18 4.22386 18 4.5C18 4.77614 17.7761 5 17.5 5H16.4456L15.2521 15.3439C15.0774 16.8576 13.7957 18 12.2719 18H7.72813C6.20431 18 4.92256 16.8576 4.7479 15.3439L3.55437 5H2.5C2.22386 5 2 4.77614 2 4.5C2 4.22386 2.22386 4 2.5 4H7.5ZM5.74131 15.2292C5.85775 16.2384 6.71225 17 7.72813 17H12.2719C13.2878 17 14.1422 16.2384 14.2587 15.2292L15.439 5H4.56101L5.74131 15.2292ZM8.5 7.5C8.77614 7.5 9 7.72386 9 8V14C9 14.2761 8.77614 14.5 8.5 14.5C8.22386 14.5 8 14.2761 8 14V8C8 7.72386 8.22386 7.5 8.5 7.5ZM12 8C12 7.72386 11.7761 7.5 11.5 7.5C11.2239 7.5 11 7.72386 11 8V14C11 14.2761 11.2239 14.5 11.5 14.5C11.7761 14.5 12 14.2761 12 14V8Z" />
    </svg>
  );
}

function MoreIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
      <path fill="currentColor" d="M6.25 10C6.25 10.6904 5.69036 11.25 5 11.25C4.30964 11.25 3.75 10.6904 3.75 10C3.75 9.30964 4.30964 8.75 5 8.75C5.69036 8.75 6.25 9.30964 6.25 10ZM11.25 10C11.25 10.6904 10.6904 11.25 10 11.25C9.30964 11.25 8.75 10.6904 8.75 10C8.75 9.30964 9.30964 8.75 10 8.75C10.6904 8.75 11.25 9.30964 11.25 10ZM15 11.25C15.6904 11.25 16.25 10.6904 16.25 10C16.25 9.30964 15.6904 8.75 15 8.75C14.3096 8.75 13.75 9.30964 13.75 10C13.75 10.6904 14.3096 11.25 15 11.25Z" />
    </svg>
  );
}

function PinIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
      <path fill="currentColor" d="M10.1221 3.13715C10.7326 1.91616 12.3599 1.65208 13.3251 2.61737L17.382 6.67419C18.3472 7.63947 18.0832 9.26676 16.8622 9.87726L13.4037 11.6065C13.0751 11.7708 12.8183 12.0499 12.6818 12.391L11.2459 15.981C10.9792 16.6476 10.1179 16.8244 9.61027 16.3167L7 13.7064L3.70711 16.9993H3V16.2922L6.29289 12.9993L3.68262 10.3891C3.17498 9.88142 3.35177 9.02011 4.01834 8.75348L7.60829 7.3175C7.94939 7.18106 8.22855 6.92419 8.39285 6.5956L10.1221 3.13715ZM12.618 3.32447C12.1354 2.84183 11.3217 2.97387 11.0165 3.58437L9.28727 7.04282C9.01345 7.59046 8.54818 8.01858 7.97968 8.24598L4.38973 9.68196L10.3174 15.6096L11.7534 12.0197C11.9808 11.4512 12.4089 10.9859 12.9565 10.7121L16.415 8.98283C17.0255 8.67758 17.1575 7.86394 16.6749 7.3813L12.618 3.32447Z" />
    </svg>
  );
}

function DismissIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 20 20" aria-hidden="true">
      <path fill="currentColor" d="M4.08859 4.21569L4.14645 4.14645C4.32001 3.97288 4.58944 3.9536 4.78431 4.08859L4.85355 4.14645L10 9.293L15.1464 4.14645C15.32 3.97288 15.5894 3.9536 15.7843 4.08859L15.8536 4.14645C16.0271 4.32001 16.0464 4.58944 15.9114 4.78431L15.8536 4.85355L10.707 10L15.8536 15.1464C16.0271 15.32 16.0464 15.5894 15.9114 15.7843L15.8536 15.8536C15.68 16.0271 15.4106 16.0464 15.2157 15.9114L15.1464 15.8536L10 10.707L4.85355 15.8536C4.67999 16.0271 4.41056 16.0464 4.21569 15.9114L4.14645 15.8536C3.97288 15.68 3.9536 15.4106 4.08859 15.2157L4.14645 15.1464L9.293 10L4.14645 4.85355C3.97288 4.67999 3.9536 4.41056 4.08859 4.21569L4.14645 4.14645L4.08859 4.21569Z" />
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
