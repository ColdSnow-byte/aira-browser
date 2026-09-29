import { describe, expect, it } from '@ohos/hypium';
import { DesktopWebEntryRecord } from '../main/ets/data/webapps/WebAppInstallModels';
import {
  collectPinnedShortcutIds,
  DESKTOP_INSTALL_REMOVAL_GRACE_MS,
  selectRemovedDesktopInstallShortcutIds,
  WebAppDesktopShortcutPresence
} from '../main/ets/services/webapps/WebAppDesktopInstallSyncPolicy';

function record(
  shortcutId: string,
  installState: 'pending' | 'installed',
  updatedAt: number
): DesktopWebEntryRecord {
  return {
    shortcutId: shortcutId,
    installState: installState,
    title: shortcutId,
    iconPath: '',
    launchUrl: 'https://example.com',
    currentUrl: 'https://example.com',
    origin: 'https://example.com',
    manifestUrl: '',
    scope: '',
    display: '',
    themeColor: '',
    backgroundColor: '',
    settings: {
      defaultFullscreen: false
    },
    createdAt: updatedAt,
    updatedAt: updatedAt
  };
}

export default function webAppDesktopInstallSyncPolicyTest(): void {
  describe('WebAppDesktopInstallSyncPolicy', () => {
    it('collects_shortcut_ids_from_the_pin_payload_and_want', 0, () => {
      const ids = collectPinnedShortcutIds([
        { shortcutId: ' aira_web_page_a ', parameterShortcutId: 'aira_web_page_b' },
        { shortcutId: 'aira_web_page_a', parameterShortcutId: '  ' },
        { shortcutId: '', parameterShortcutId: '' }
      ]);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual('aira_web_page_a');
      expect(ids[1]).assertEqual('aira_web_page_b');
    });

    it('removes_only_installed_records_confirmed_absent_after_the_grace_window', 0, () => {
      const now = 20_000;
      const presence: Record<string, WebAppDesktopShortcutPresence> = {
        gone: 'absent',
        fresh: 'absent',
        pending: 'absent',
        kept: 'present',
        unsure: 'unknown'
      };
      const removedIds = selectRemovedDesktopInstallShortcutIds([
        record('gone', 'installed', now - DESKTOP_INSTALL_REMOVAL_GRACE_MS),
        record('fresh', 'installed', now - DESKTOP_INSTALL_REMOVAL_GRACE_MS + 1),
        record('pending', 'pending', 0),
        record('kept', 'installed', 0),
        record('unsure', 'installed', 0),
        record('gone', 'installed', 0)
      ], presence, now);
      expect(removedIds.length).assertEqual(1);
      expect(removedIds[0]).assertEqual('gone');
    });
  });
}
