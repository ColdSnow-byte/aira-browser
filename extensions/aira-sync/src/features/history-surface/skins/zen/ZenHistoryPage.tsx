import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { HistorySyncVisit } from '@/features/sync/history/HistorySyncModels';
import {
  historyFaviconUrl,
  historyHostname,
  useHistorySurfaceData,
} from '../../useHistorySurfaceData';
import {
  zenDisplayUrl,
  zenHistoryCopy,
  type ZenHistorySort,
  type ZenHistoryWhen,
} from './zenHistorySpec';
import './zen-history.css';

const DAY_MS = 86_400_000;
const WHEN_DAYS: Record<ZenHistoryWhen, number> = { today: 1, week: 7, month: 30 };

export function ZenHistoryPage() {
  const { i18n } = useTranslation();
  const copy = zenHistoryCopy(i18n.language);
  const data = useHistorySurfaceData();
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [when, setWhen] = useState<ZenHistoryWhen | null>(null);
  const [sort, setSort] = useState<ZenHistorySort>('date');
  const [theme, setTheme] = useState<'light' | 'dark'>(readZenTheme);

  useEffect(() => {
    document.title = copy.title;
    document.body.classList.add('zen-history-body');
    return () => {
      document.body.classList.remove('zen-history-body');
    };
  }, [copy.title]);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const apply = () => setTheme(readZenTheme());
    media.addEventListener('change', apply);
    return () => media.removeEventListener('change', apply);
  }, []);

  const groups = useMemo(
    () => groupZenVisits(data.visits, when, sort, i18n.language, copy.other),
    [copy.other, data.visits, i18n.language, sort, when],
  );

  const openVisit = (url: string) => {
    if (globalThis.chrome?.tabs?.create) void globalThis.chrome.tabs.create({ url, active: true });
    else window.location.assign(url);
  };

  const toggleWhen = (next: ZenHistoryWhen) => setWhen((current) => (current === next ? null : next));
  const toggleSort = (next: ZenHistorySort) => setSort((current) => (current === next ? 'date' : next));

  return (
    <div className="zen-history" data-zen-theme={theme}>
      <aside className="zen-history-panel" aria-label={copy.history}>
        <nav className="zen-history-side">
          <button type="button" className="zen-history-tab is-active" aria-current="page">
            <HistoryIcon />
            <span>{copy.history}</span>
          </button>
          <div className="zen-history-tab"><span>{copy.downloads}</span></div>
          <div className="zen-history-tab"><span>{copy.boosts}</span></div>
          <div className="zen-history-tab"><span>{copy.spaces}</span></div>
          <div className="zen-history-tab"><span>{copy.media}</span></div>
        </nav>
        <section className="zen-history-content">
          <div className={`zen-history-search-top${filtersOpen ? ' is-open' : ''}`}>
            <div className="zen-history-search-header">
              <label className="zen-history-search-box">
                <SearchIcon />
                <input
                  type="search"
                  value={data.query}
                  placeholder={copy.search}
                  aria-label={copy.search}
                  onChange={(event) => data.setQuery(event.target.value)}
                />
              </label>
              <button type="button" className="zen-history-filter-button" onClick={() => setFiltersOpen(true)}>
                {copy.filter}
              </button>
            </div>
            <div className="zen-history-filter-header">
              <h2>{copy.filterTitle}</h2>
              <button type="button" className="zen-history-filter-done" onClick={() => setFiltersOpen(false)}>{copy.done}</button>
            </div>
            <div className="zen-history-filter-panel">
              <div className="zen-history-filter-group">
                <h3>{copy.when}</h3>
                <div className="zen-history-filter-options">
                  <FilterChip active={when === 'today'} label={copy.today} onClick={() => toggleWhen('today')} />
                  <FilterChip active={when === 'week'} label={copy.week} onClick={() => toggleWhen('week')} />
                  <FilterChip active={when === 'month'} label={copy.month} onClick={() => toggleWhen('month')} />
                </div>
              </div>
              <div className="zen-history-filter-group">
                <h3>{copy.sort}</h3>
                <div className="zen-history-filter-options">
                  <FilterChip active={sort === 'date'} label={copy.byDate} onClick={() => toggleSort('date')} />
                  <FilterChip active={sort === 'site'} label={copy.bySite} onClick={() => toggleSort('site')} />
                  <FilterChip active={sort === 'mostvisited'} label={copy.mostVisited} onClick={() => toggleSort('mostvisited')} />
                  <FilterChip active={sort === 'lastvisited'} label={copy.lastVisited} onClick={() => toggleSort('lastvisited')} />
                </div>
              </div>
            </div>
          </div>
          <div className="zen-history-results">
            {data.loading && groups.length === 0 ? <p className="zen-history-empty">{copy.loading}</p> : null}
            {!data.loading && groups.length === 0 ? <p className="zen-history-empty">{copy.empty}</p> : null}
            {groups.map((group) => (
              <div className="zen-history-group" key={group.key}>
                {group.label ? <h3>{group.label}</h3> : null}
                {group.visits.map((visit) => (
                  <div key={visit.visitId} className="zen-history-row" role="link" tabIndex={0} onClick={() => openVisit(visit.url)}>
                    <Favicon url={visit.url} />
                    <span className="zen-history-row-text">
                      <span className="zen-history-row-title">{visit.title || visit.url}</span>
                      <span className="zen-history-row-subtitle">
                        <span className="zen-history-url">{zenDisplayUrl(visit.url)}</span>
                        <span className="zen-history-date">{formatVisitTime(visit.visitedAt, i18n.language)}</span>
                      </span>
                    </span>
                    <span className="zen-history-actions">
                      <button type="button" aria-label={copy.remove} onClick={(event) => { event.stopPropagation(); void data.deleteVisit(visit.visitId); }}>
                        <TrashIcon />
                      </button>
                      <button type="button" aria-label={copy.reopen} onClick={(event) => { event.stopPropagation(); openVisit(visit.url); }}>
                        <ReopenIcon />
                      </button>
                    </span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </section>
      </aside>
    </div>
  );
}

function FilterChip({ active, label, onClick }: { active: boolean; label: string; onClick: () => void }) {
  return <button type="button" className={`zen-history-chip${active ? ' is-active' : ''}`} onClick={onClick}>{label}</button>;
}

function readZenTheme(): 'light' | 'dark' {
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function groupZenVisits(
  visits: HistorySyncVisit[],
  when: ZenHistoryWhen | null,
  sort: ZenHistorySort,
  language: string,
  otherLabel: string,
): Array<{ key: string; label: string; visits: HistorySyncVisit[] }> {
  const cutoff = when ? Date.now() - WHEN_DAYS[when] * DAY_MS : 0;
  const filtered = visits.filter((visit) => visit.visitedAt >= cutoff);
  if (sort === 'mostvisited') {
    return [{ key: 'most', label: '', visits: sortByVisitCount(filtered) }];
  }
  if (sort === 'lastvisited') {
    return [{ key: 'last', label: '', visits: latestByUrl(filtered) }];
  }
  if (sort === 'site') return groupBySite(filtered, otherLabel);
  return groupByDay(filtered, language);
}

function sortByVisitCount(visits: HistorySyncVisit[]): HistorySyncVisit[] {
  const counts = new Map<string, number>();
  visits.forEach((visit) => counts.set(visit.url, (counts.get(visit.url) || 0) + 1));
  return latestByUrl(visits).sort((left, right) => (counts.get(right.url) || 0) - (counts.get(left.url) || 0));
}

function latestByUrl(visits: HistorySyncVisit[]): HistorySyncVisit[] {
  const latest = new Map<string, HistorySyncVisit>();
  visits.forEach((visit) => {
    const current = latest.get(visit.url);
    if (!current || visit.visitedAt > current.visitedAt) latest.set(visit.url, visit);
  });
  return [...latest.values()].sort((left, right) => right.visitedAt - left.visitedAt);
}

function groupBySite(visits: HistorySyncVisit[], otherLabel: string) {
  const groups = new Map<string, HistorySyncVisit[]>();
  latestByUrl(visits).forEach((visit) => {
    const key = historyHostname(visit.url) || otherLabel;
    groups.set(key, [...(groups.get(key) || []), visit]);
  });
  return [...groups.entries()]
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, items]) => ({ key, label: key, visits: items }));
}

function groupByDay(visits: HistorySyncVisit[], language: string) {
  const groups = new Map<number, HistorySyncVisit[]>();
  [...visits].sort((left, right) => right.visitedAt - left.visitedAt).forEach((visit) => {
    const day = startOfDay(visit.visitedAt);
    groups.set(day, [...(groups.get(day) || []), visit]);
  });
  return [...groups.entries()].map(([day, items]) => ({
    key: String(day),
    label: formatDay(day, language),
    visits: items,
  }));
}

function startOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function formatDay(day: number, language: string): string {
  const locale = language.toLowerCase().startsWith('zh') ? 'zh-CN' : language || 'en';
  const daysAgo = Math.round((startOfDay(Date.now()) - day) / DAY_MS);
  const formatted = daysAgo <= 6
    ? new Intl.RelativeTimeFormat(locale, { numeric: 'auto' }).format(-daysAgo, 'day')
    : new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(day);
  return formatted.charAt(0).toLocaleUpperCase() + formatted.slice(1);
}

function formatVisitTime(timestamp: number, language: string): string {
  const locale = language.toLowerCase().startsWith('zh') ? 'zh-CN' : language || 'en';
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeStyle: 'short' }).format(timestamp);
}

function Favicon({ url }: { url: string }) {
  const [failed, setFailed] = useState(false);
  const src = historyFaviconUrl(url);
  if (!src || failed) return <span className="zen-history-favicon" />;
  return <img className="zen-history-favicon" src={src} alt="" onError={() => setFailed(true)} />;
}

function HistoryIcon() {
  return (
    <svg className="zen-history-tab-icon" viewBox="0 0 24 24" aria-hidden="true">
      <circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" strokeWidth="1.8" />
      <path d="M12 8v5l3 2" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="7" cy="7" r="4.5" fill="none" stroke="currentColor" strokeWidth="1.4" opacity="0.5" />
      <path d="M10.5 10.5 13 13" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" opacity="0.5" />
    </svg>
  );
}

function TrashIcon() {
  return (
    <svg viewBox="0 0 16 16" aria-hidden="true">
      <path d="M6 2.5h4l.5 1.5h3v1.2H2.5V4h3L6 2.5Zm.4 3.2h1.1v6H6.4v-6Zm2.1 0h1.1v6H8.5v-6ZM4.8 5.7h1.1l.3 6.4H5.1L4.8 5.7Zm5.3 0h1.1l-.3 6.4H10.4l-.3-6.4Z" />
    </svg>
  );
}

function ReopenIcon() {
  return (
    <svg viewBox="0 0 16 16" aria-hidden="true">
      <path d="M7.2 3.2a4.8 4.8 0 1 0 1.4 7.8l-.8-1a3.6 3.6 0 1 1-1-5.8H8.2v1.6L11.4 3.6 8.2 1.4v1.8H7.2Z" />
    </svg>
  );
}
