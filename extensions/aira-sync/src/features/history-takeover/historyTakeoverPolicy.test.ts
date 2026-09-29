import { describe, expect, test } from 'vitest';
import {
  detectHistoryBrowserKind,
  detectHistoryPlatform,
  isHistoryTakeoverShortcut,
  isNativeHistoryPageUrl,
} from './historyTakeoverPolicy';

const down = {
  ctrlKey: false,
  metaKey: false,
  altKey: false,
  shiftKey: false,
};

describe('history takeover browser detection', () => {
  test('keeps Chromium forks distinct from generic Chrome', () => {
    expect(detectHistoryBrowserKind('Mozilla/5.0 Firefox/128.0')).toBe('firefox');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 OPR/114.0')).toBe('opera');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 Vivaldi/6.8')).toBe('vivaldi');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 Edg/128.0')).toBe('edge');
    expect(detectHistoryBrowserKind('Mozilla/5.0 Chrome/128.0 Brave')).toBe('chromium');
    expect(detectHistoryPlatform('MacIntel')).toBe('mac');
    expect(detectHistoryPlatform('Win32')).toBe('other');
  });
});

describe('history takeover shortcuts', () => {
  test('captures Edge Ctrl+Y without stealing Redo or the overridden Ctrl+H', () => {
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, code: 'KeyY' })).toBe(true);
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('edge', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('edge', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('chromium', 'other', { ...down, ctrlKey: true, code: 'KeyY' })).toBe(false);
    expect(isHistoryTakeoverShortcut('chromium', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(false);
  });

  test('captures the history shortcuts of browsers that cannot replace the history page', () => {
    expect(isHistoryTakeoverShortcut('opera', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('opera', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('opera', 'mac', { ...down, metaKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('firefox', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('firefox', 'other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('firefox', 'mac', { ...down, metaKey: true, shiftKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('firefox', 'mac', { ...down, metaKey: true, code: 'KeyH' })).toBe(false);
    expect(isHistoryTakeoverShortcut('vivaldi', 'other', { ...down, ctrlKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('vivaldi', 'other', { ...down, ctrlKey: true, shiftKey: true, code: 'KeyH' })).toBe(true);
    expect(isHistoryTakeoverShortcut('vivaldi', 'mac', { ...down, metaKey: true, code: 'KeyY' })).toBe(true);
    expect(isHistoryTakeoverShortcut('vivaldi', 'other', { ...down, ctrlKey: true, altKey: true, code: 'KeyH' })).toBe(false);
  });
});

describe('native history page urls', () => {
  test('matches history pages across browser schemes and ignores nearby pages', () => {
    expect(isNativeHistoryPageUrl('chrome://history')).toBe(true);
    expect(isNativeHistoryPageUrl('edge://history/?q=aira')).toBe(true);
    expect(isNativeHistoryPageUrl('brave://history/')).toBe(true);
    expect(isNativeHistoryPageUrl('opera://history')).toBe(true);
    expect(isNativeHistoryPageUrl('vivaldi://history')).toBe(true);
    expect(isNativeHistoryPageUrl('about:history')).toBe(true);
    expect(isNativeHistoryPageUrl('chrome://history-clusters')).toBe(false);
    expect(isNativeHistoryPageUrl('https://example.com/history')).toBe(false);
  });
});
