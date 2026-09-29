import {
  chromeHistoryCopy,
  formatChromeHistoryDay,
  formatChromeHistoryTime,
  type ChromeHistoryCopy,
} from '../chrome/chromeHistorySpec';

export { formatChromeHistoryDay, formatChromeHistoryTime };

export function braveHistoryCopy(language: string): ChromeHistoryCopy {
  const copy = chromeHistoryCopy(language);
  const zh = language.toLowerCase().startsWith('zh');
  return {
    ...copy,
    history: zh ? 'Brave 历史记录' : 'Brave History',
  };
}
