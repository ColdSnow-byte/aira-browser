import { DesktopWebEntryRecord } from '../../data/webapps/WebAppInstallModels';

export const DESKTOP_INSTALL_REMOVAL_GRACE_MS: number = 15000;

export type WebAppDesktopShortcutPresence = 'present' | 'absent' | 'unknown';

export interface WebAppPinShortcutSnapshot {
  shortcutId: string;
  parameterShortcutId: string;
}

export function collectPinnedShortcutIds(infos: WebAppPinShortcutSnapshot[]): string[] {
  const ids: string[] = [];
  infos.forEach((info: WebAppPinShortcutSnapshot) => {
    appendShortcutId(ids, info.shortcutId);
    appendShortcutId(ids, info.parameterShortcutId);
  });
  return ids;
}

export function selectRemovedDesktopInstallShortcutIds(
  records: DesktopWebEntryRecord[],
  presenceByShortcutId: Record<string, WebAppDesktopShortcutPresence>,
  now: number,
  graceMs: number = DESKTOP_INSTALL_REMOVAL_GRACE_MS
): string[] {
  const removedIds: string[] = [];
  records.forEach((record: DesktopWebEntryRecord) => {
    const shortcutId = record.shortcutId.trim();
    if (shortcutId.length === 0 || removedIds.indexOf(shortcutId) >= 0) {
      return;
    }
    if (record.installState !== 'installed') {
      return;
    }
    if (presenceByShortcutId[shortcutId] !== 'absent') {
      return;
    }
    if (now - record.updatedAt < graceMs) {
      return;
    }
    removedIds.push(shortcutId);
  });
  return removedIds;
}

function appendShortcutId(ids: string[], value: string): void {
  const shortcutId = value.trim();
  if (shortcutId.length === 0 || ids.indexOf(shortcutId) >= 0) {
    return;
  }
  ids.push(shortcutId);
}
