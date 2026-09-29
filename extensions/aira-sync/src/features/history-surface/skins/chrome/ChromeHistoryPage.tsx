import { useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { HistorySyncVisit } from '@/features/sync/history/HistorySyncModels';
import {
  historyFaviconUrl,
  historyHostname,
  useHistorySurfaceData,
} from '../../useHistorySurfaceData';
import {
  chromeHistoryCopy,
  formatChromeHistoryDay,
  formatChromeHistoryTime,
} from './chromeHistorySpec';
import { useChromeOtherDeviceTabs } from './useChromeOtherDeviceTabs';
import './chrome-history.css';

type ChromeHistorySection = 'history' | 'other-devices';

export function ChromeHistoryPage() {
  const { i18n } = useTranslation();
  const copy = chromeHistoryCopy(i18n.language);
  const data = useHistorySurfaceData();
  const [section, setSection] = useState<ChromeHistorySection>('history');
  const [theme, setTheme] = useState<'light' | 'dark'>(readChromeTheme);
  const [menuVisitId, setMenuVisitId] = useState('');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [compact, setCompact] = useState(() => window.matchMedia('(max-width: 960px)').matches);
  const [navOpen, setNavOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const cardRef = useRef<HTMLElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    document.title = copy.title;
    document.documentElement.dataset.chromeTheme = theme;
    document.body.classList.add('chrome-history-body');
    return () => {
      document.body.classList.remove('chrome-history-body');
      delete document.documentElement.dataset.chromeTheme;
    };
  }, [copy.title, theme]);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const apply = () => setTheme(readChromeTheme());
    media.addEventListener('change', apply);
    return () => media.removeEventListener('change', apply);
  }, []);

  useEffect(() => {
    const media = window.matchMedia('(max-width: 960px)');
    const apply = () => {
      setCompact(media.matches);
      if (!media.matches) {
        setNavOpen(false);
        setSearchOpen(false);
      }
    };
    apply();
    media.addEventListener('change', apply);
    return () => media.removeEventListener('change', apply);
  }, []);

  useEffect(() => {
    if (searchOpen) searchRef.current?.focus();
  }, [searchOpen]);

  useEffect(() => {
    if (!navOpen && !searchOpen) return undefined;
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      setNavOpen(false);
      setSearchOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [navOpen, searchOpen]);

  useEffect(() => {
    const onScroll = () => {
      if (!data.hasMore || data.loading) return;
      if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 240) data.loadMore();
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, [data]);

  const otherDevices = useChromeOtherDeviceTabs(section === 'other-devices');
  const visits = data.visits;
  const groups = useMemo(
    () => groupChromeVisits(visits, i18n.language),
    [i18n.language, visits],
  );

  const openVisit = (url: string, newTab = false) => {
    if (newTab && globalThis.chrome?.tabs?.create) {
      void globalThis.chrome.tabs.create({ url, active: true });
      return;
    }
    window.location.assign(url);
  };

  const openClearData = () => {
    const url = 'chrome://settings/clearBrowserData';
    if (globalThis.chrome?.tabs?.create) void globalThis.chrome.tabs.create({ url });
    else window.location.assign(url);
  };

  const closeNav = () => setNavOpen(false);
  const selectedVisits = visits.filter((visit) => selectedIds.includes(visit.visitId));
  const toggleSelected = (visitId: string) => {
    setSelectedIds((current) => current.includes(visitId)
      ? current.filter((id) => id !== visitId)
      : [...current, visitId]);
  };
  const openSelected = () => {
    selectedVisits.forEach((visit) => openVisit(visit.url, true));
  };
  const deleteSelected = () => {
    const ids = selectedVisits.map((visit) => visit.visitId);
    setSelectedIds([]);
    void ids.reduce(async (previous, visitId) => {
      await previous;
      await data.deleteVisit(visitId);
    }, Promise.resolve());
  };

  return (
    <div
      className={`chrome-history${navOpen ? ' is-nav-open' : ''}${searchOpen ? ' is-search-open' : ''}`}
      data-chrome-theme={theme}
    >
      {selectedVisits.length > 0 ? (
        <div className="chrome-history-selection">
          <div className="chrome-history-selection-start">
            <button
              type="button"
              className="chrome-history-icon-button"
              style={{ display: 'flex' }}
              aria-label={copy.closeSelection}
              onClick={() => setSelectedIds([])}
            >
              <CloseIcon />
            </button>
            <span>{copy.selected(selectedVisits.length)}</span>
          </div>
          <div className="chrome-history-selection-actions">
            <button type="button" className="chrome-history-selection-button" onClick={openSelected}>{copy.open}</button>
            <button type="button" className="chrome-history-selection-button" onClick={deleteSelected}>{copy.deleteSelected}</button>
          </div>
        </div>
      ) : (
      <header className="chrome-history-header">
        <div className="chrome-history-brand">
          <button
            type="button"
            className="chrome-history-icon-button chrome-history-menu-button"
            aria-label={copy.title}
            aria-expanded={navOpen}
            onClick={() => setNavOpen((open) => !open)}
          >
            <MenuIcon />
          </button>
          <ChromeLogo theme={theme} />
          <h1>{copy.title}</h1>
        </div>
        <form className="chrome-history-search" role="search" onSubmit={(event) => event.preventDefault()}>
          <SearchIcon />
          <input
            ref={searchRef}
            type="search"
            value={data.query}
            placeholder={copy.search}
            aria-label={copy.search}
            onChange={(event) => data.setQuery(event.target.value)}
          />
        </form>
        <button
          type="button"
          className="chrome-history-icon-button chrome-history-search-button"
          aria-label={copy.search}
          onClick={() => setSearchOpen((open) => !open)}
        >
          <SearchIcon />
        </button>
      </header>
      )}
      {compact ? (
        <>
          <button type="button" className="chrome-history-scrim" aria-label={copy.title} onClick={closeNav} />
          <aside className="chrome-history-drawer">
            <div className="chrome-history-drawer-brand">
              <ChromeLogo theme={theme} />
              <h1>{copy.title}</h1>
            </div>
            <HistoryNav
              copy={copy}
              section={section}
              onSelect={(next) => {
                setSection(next);
                closeNav();
              }}
              onClear={() => {
                closeNav();
                openClearData();
              }}
            />
          </aside>
        </>
      ) : null}
      <div className="chrome-history-body">
        <HistoryNav
          copy={copy}
          section={section}
          onSelect={setSection}
          onClear={openClearData}
        />
        <main className="chrome-history-card" ref={cardRef} onClick={() => setMenuVisitId('')}>
          {section === 'other-devices' ? (
            <OtherDeviceTabs
              copy={copy}
              devices={otherDevices.devices}
              loading={otherDevices.loading}
              error={otherDevices.error}
              onOpen={openVisit}
            />
          ) : data.status === 'login-required' ? (
            <p className="chrome-history-status">{copy.login}</p>
          ) : data.loading && visits.length === 0 ? (
            <p className="chrome-history-status">{copy.loading}</p>
          ) : groups.length === 0 ? (
            <p className="chrome-history-status">{copy.empty}</p>
          ) : groups.map((group) => (
            <section className="chrome-history-day" key={group.label}>
              <h2>{group.label}</h2>
              {group.visits.map((visit) => (
                <article className="chrome-history-row" key={visit.visitId}>
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(visit.visitId)}
                    aria-label={visit.title || visit.url}
                    onChange={() => toggleSelected(visit.visitId)}
                  />
                  <span className="chrome-history-time">{formatChromeHistoryTime(visit.visitedAt, i18n.language)}</span>
                  <Favicon url={visit.url} />
                  <button type="button" className="chrome-history-link" onClick={() => openVisit(visit.url)}>
                    <span className="title">{visit.title || historyHostname(visit.url) || visit.url}</span>
                    <span className="domain">{historyHostname(visit.url) || visit.url}</span>
                  </button>
                  <button
                    type="button"
                    className="chrome-history-more"
                    aria-label={copy.remove}
                    aria-expanded={menuVisitId === visit.visitId}
                    onClick={(event) => {
                      event.stopPropagation();
                      setMenuVisitId((current) => current === visit.visitId ? '' : visit.visitId);
                    }}
                  >
                    <MoreIcon />
                  </button>
                  {menuVisitId === visit.visitId ? (
                    <div className="chrome-history-menu" style={{ top: 40, right: 12 }} onClick={(event) => event.stopPropagation()}>
                      <button type="button" onClick={() => openVisit(visit.url)}>{copy.open}</button>
                      <button type="button" onClick={() => openVisit(visit.url, true)}>{copy.openNewTab}</button>
                      <button type="button" onClick={() => {
                        setMenuVisitId('');
                        void data.deleteVisit(visit.visitId);
                      }}
                      >{copy.remove}</button>
                    </div>
                  ) : null}
                </article>
              ))}
            </section>
          ))}
        </main>
      </div>
    </div>
  );
}

function OtherDeviceTabs({
  copy,
  devices,
  loading,
  error,
  onOpen,
}: {
  copy: ReturnType<typeof chromeHistoryCopy>;
  devices: ReturnType<typeof useChromeOtherDeviceTabs>['devices'];
  loading: boolean;
  error: string;
  onOpen: (url: string, newTab?: boolean) => void;
}) {
  if (loading && devices.length === 0) {
    return <p className="chrome-history-status">{copy.loading}</p>;
  }
  if (error && devices.length === 0) {
    return <p className="chrome-history-status">{error}</p>;
  }
  if (devices.length === 0) {
    return <p className="chrome-history-status">{copy.emptyOther}</p>;
  }
  return (
    <>
      {devices.map((device) => {
        const label = device.deviceName || device.model || device.platform || device.browserName;
        return (
          <section className="chrome-history-day" key={device.deviceId}>
            <h2>{label}</h2>
            {device.tabs.map((tab, index) => (
              <article className="chrome-history-row is-remote" key={`${device.deviceId}:${tab.url}:${index}`}>
                <Favicon url={tab.url} />
                <button type="button" className="chrome-history-link" onClick={() => onOpen(tab.url, true)}>
                  <span className="title">{tab.title || historyHostname(tab.url) || tab.url}</span>
                  <span className="domain">{historyHostname(tab.url) || tab.url}</span>
                </button>
              </article>
            ))}
          </section>
        );
      })}
    </>
  );
}

function HistoryNav({
  copy,
  section,
  onSelect,
  onClear,
}: {
  copy: ReturnType<typeof chromeHistoryCopy>;
  section: ChromeHistorySection;
  onSelect: (section: ChromeHistorySection) => void;
  onClear: () => void;
}) {
  return (
    <nav className="chrome-history-nav" aria-label={copy.title}>
      <button
        type="button"
        className={section === 'history' ? 'is-selected' : undefined}
        onClick={() => onSelect('history')}
      >
        <HistoryIcon />
        <span className="nav-label">{copy.history}</span>
      </button>
      <button
        type="button"
        className={section === 'other-devices' ? 'is-selected' : undefined}
        onClick={() => onSelect('other-devices')}
      >
        <DevicesIcon />
        <span className="nav-label">{copy.otherDevices}</span>
      </button>
      <button type="button" onClick={onClear}>
        <DeleteIcon />
        <span className="nav-label">{copy.clearData}</span>
        <OpenInNewIcon />
      </button>
    </nav>
  );
}

function readChromeTheme(): 'light' | 'dark' {
  if (document.documentElement.classList.contains('dark')) return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function groupChromeVisits(visits: HistorySyncVisit[], language: string) {
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
  return (
    <img
      className="chrome-history-favicon"
      src={src}
      alt=""
      onError={() => setFailed(true)}
    />
  );
}

function ChromeLogo({ theme }: { theme: 'light' | 'dark' }) {
  const file = theme === 'dark' ? 'history-skins/chrome-logo-dark.svg' : 'history-skins/chrome-logo.png';
  const src = globalThis.chrome?.runtime?.getURL?.(file) || `/${file}`;
  return <img src={src} width={24} height={24} alt="" />;
}

function CloseIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function MenuIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="11" cy="11" r="6.25" stroke="currentColor" strokeWidth="2" />
      <path d="M16 16.5 20 20.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function HistoryIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 7.5V12l3 2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M12 20.5a8.5 8.5 0 1 0-7.4-4.3" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M4.2 12.2 4.6 16l3.7-1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function DevicesIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="3.5" y="5" width="13" height="10" rx="1.4" stroke="currentColor" strokeWidth="1.8" />
      <path d="M7 19h6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <rect x="15" y="9" width="5.5" height="8" rx="1" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

function DeleteIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M5 7.5h14" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M9.5 7.2V5.8h5v1.4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M8 7.5 8.8 18h6.4l.8-10.5" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" />
    </svg>
  );
}

function OpenInNewIcon() {
  return (
    <svg className="external" width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M14 5h5v5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M19 5 11 13" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      <path d="M17 13.5V18a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h4.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function MoreIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <circle cx="12" cy="5.5" r="1.6" />
      <circle cx="12" cy="12" r="1.6" />
      <circle cx="12" cy="18.5" r="1.6" />
    </svg>
  );
}

function GlobeIcon() {
  return (
    <svg className="chrome-history-favicon" width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="12" cy="12" r="8" stroke="currentColor" strokeWidth="1.6" />
      <path d="M4 12h16M12 4c2.4 2.6 2.4 13.4 0 16M12 4c-2.4 2.6-2.4 13.4 0 16" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}
