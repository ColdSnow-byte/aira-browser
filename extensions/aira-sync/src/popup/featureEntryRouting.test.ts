import { describe, expect, test } from 'vitest';
import { resolveCloudFeatureEntryView, shouldAutoSelectAiraCloud } from './featureEntryRouting';

describe('cloud feature entry routing', () => {
  test('uses sync method setup when the desktop session exists without a selected provider', () => {
    expect(resolveCloudFeatureEntryView({
      hasAiraDesktopSession: true,
      airaCloudAvailable: true,
    })).toBe('sync-method');
  });

  test('turns on Aira cloud after login and leaves an explicit provider alone', () => {
    expect(shouldAutoSelectAiraCloud({
      airaCloudAvailable: true,
      loggedIn: true,
      selectedSource: 'webdav',
      loginJustCompleted: true,
    })).toBe(true);
    expect(shouldAutoSelectAiraCloud({
      airaCloudAvailable: true,
      loggedIn: true,
      selectedSource: null,
      loginJustCompleted: false,
    })).toBe(true);
    expect(shouldAutoSelectAiraCloud({
      airaCloudAvailable: true,
      loggedIn: true,
      selectedSource: 'personal-server',
      loginJustCompleted: false,
    })).toBe(false);
    expect(shouldAutoSelectAiraCloud({
      airaCloudAvailable: true,
      loggedIn: false,
      selectedSource: null,
      loginJustCompleted: true,
    })).toBe(false);
  });

  test('opens QR login only when there is no desktop session', () => {
    expect(resolveCloudFeatureEntryView({
      hasAiraDesktopSession: false,
      airaCloudAvailable: true,
    })).toBe('login');
  });
});
