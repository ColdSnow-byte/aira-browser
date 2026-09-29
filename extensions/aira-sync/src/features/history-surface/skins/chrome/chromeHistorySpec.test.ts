import { describe, expect, test } from 'vitest';
import { formatChromeHistoryDay } from './chromeHistorySpec';
import { resolveHistorySkin } from '../registry';

describe('chrome history skin', () => {
  test('formats the native Chinese day heading', () => {
    const label = formatChromeHistoryDay(Date.parse('2026-09-29T23:47:00+08:00'), 'zh-CN', Date.parse('2026-09-30T12:00:00+08:00'));
    expect(label.startsWith('昨天 - ')).toBe(true);
    expect(label).toContain('2026');
    expect(label).toContain('9月29日');
    expect(label).toContain('星期二');
  });

  test('registers Chrome and Edge skins separately', () => {
    expect(resolveHistorySkin('chrome')).not.toBeNull();
    expect(resolveHistorySkin('edge')).not.toBeNull();
    expect(resolveHistorySkin('brave')).toBeNull();
  });
});
