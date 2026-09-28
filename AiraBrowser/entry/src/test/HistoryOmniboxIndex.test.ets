import { describe, expect, it } from '@ohos/hypium';
import {
  HISTORY_OMNIBOX_HOT_SET_LIMIT,
  HistoryOmniboxEntry,
  HistoryOmniboxIndex
} from '../main/ets/services/search/HistoryOmniboxIndex';

function entry(
  id: string,
  title: string,
  url: string,
  host: string,
  lastVisitAt: number,
  visitCount: number = 1
): HistoryOmniboxEntry {
  return {
    id: id,
    title: title,
    url: url,
    host: host,
    visitCount: visitCount,
    typedCount: 0,
    lastVisitAt: lastVisitAt
  };
}

export default function historyOmniboxIndexTest(): void {
  describe('HistoryOmniboxIndex', () => {
    it('matches a host prefix without scanning the hot set', 0, () => {
      const index = new HistoryOmniboxIndex();
      const now = 1_700_000_000_000;
      const entries: HistoryOmniboxEntry[] = [];
      for (let offset = 0; offset < 3000; offset += 1) {
        entries.push(entry(
          `filler-${offset}`,
          `页面 ${offset}`,
          `https://aa${offset}.example/item`,
          `aa${offset}.example`,
          now - offset * 1000
        ));
      }
      entries.push(entry(
        'target',
        'Aira 仓库',
        'https://zz-omnibox-target.example/aira',
        'zz-omnibox-target.example',
        now
      ));
      index.replace(entries, now);

      const matches = index.match('zz-omnibox-target', 3, now);
      const stats = index.lastQueryStats();

      expect(matches.length).assertEqual(1);
      expect(matches[0].entry.id).assertEqual('target');
      expect(stats.hotSetSize).assertEqual(3001);
      expect(stats.examined < 20).assertTrue();
    });

    it('matches a title substring through the bigram posting', 0, () => {
      const index = new HistoryOmniboxIndex();
      const now = 1_700_000_000_000;
      index.replace([
        entry('invoice', '三月发票管理', 'https://bank.example/invoice', 'bank.example', now),
        entry('other', '天气', 'https://weather.example', 'weather.example', now - 1000)
      ], now);

      const matches = index.match('发票', 3, now);

      expect(matches.length).assertEqual(1);
      expect(matches[0].entry.url).assertEqual('https://bank.example/invoice');
    });

    it('drops internal urls and keeps the hot set capped', 0, () => {
      const index = new HistoryOmniboxIndex();
      const now = 1_700_000_000_000;
      const entries: HistoryOmniboxEntry[] = [
        entry('blank', '空白', 'about:blank', '', now)
      ];
      for (let offset = 0; offset < HISTORY_OMNIBOX_HOT_SET_LIMIT + 20; offset += 1) {
        entries.push(entry(
          `page-${offset}`,
          `页面 ${offset}`,
          `https://page${offset}.example`,
          `page${offset}.example`,
          now - offset
        ));
      }
      index.replace(entries, now);

      expect(index.size()).assertEqual(HISTORY_OMNIBOX_HOT_SET_LIMIT);
      expect(index.match('about', 3, now).length).assertEqual(0);
      expect(index.match('page0.example', 1, now)[0].entry.id).assertEqual('page-0');
    });

    it('makes a just-visited page findable without rebuilding', 0, () => {
      const index = new HistoryOmniboxIndex();
      const now = 1_700_000_000_000;
      index.replace([
        entry('old', '旧页面', 'https://old.example', 'old.example', now - 5000)
      ], now);
      index.upsert(entry('fresh', '新笔记', 'https://notes.example/fresh', 'notes.example', now), now);

      const matches = index.match('notes.example', 3, now);

      expect(matches.length).assertEqual(1);
      expect(matches[0].entry.id).assertEqual('fresh');
    });
  });
}
