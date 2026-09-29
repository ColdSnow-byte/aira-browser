import {
  readExtensionStorageRecord,
  writeExtensionStorageRecord,
} from '@/platform/extensionStorage';
import { HISTORY_TAKEOVER_ENABLED_KEY } from './historyTakeoverPolicy';

function mirrorHistoryTakeoverEnabled(enabled: boolean): void {
  if (typeof localStorage === 'undefined') return;
  try {
    localStorage.setItem(HISTORY_TAKEOVER_ENABLED_KEY, enabled ? '1' : '0');
  } catch {
    // Extension pages mirror the setting for a synchronous override-page read.
  }
}

export function readHistoryTakeoverEnabledSync(): boolean | null {
  if (typeof localStorage === 'undefined') return null;
  try {
    const raw = localStorage.getItem(HISTORY_TAKEOVER_ENABLED_KEY);
    if (raw === '1') return true;
    if (raw === '0') return false;
    return null;
  } catch {
    return null;
  }
}

export async function readHistoryTakeoverEnabled(): Promise<boolean> {
  const synced = readHistoryTakeoverEnabledSync();
  try {
    const record = await readExtensionStorageRecord([HISTORY_TAKEOVER_ENABLED_KEY]);
    if (Object.prototype.hasOwnProperty.call(record, HISTORY_TAKEOVER_ENABLED_KEY)) {
      const enabled = record[HISTORY_TAKEOVER_ENABLED_KEY] === true;
      mirrorHistoryTakeoverEnabled(enabled);
      return enabled;
    }
  } catch {
    // Fall back to the extension-page mirror when storage is unavailable.
  }
  return synced === true;
}

export async function writeHistoryTakeoverEnabled(enabled: boolean): Promise<void> {
  mirrorHistoryTakeoverEnabled(enabled);
  await writeExtensionStorageRecord({
    [HISTORY_TAKEOVER_ENABLED_KEY]: enabled,
  });
}
