import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';
import { DesktopWebEntryRecord } from '../../data/webapps/WebAppInstallModels';
import {
  WebAppInstallRepository,
  sharedWebAppInstallRepository
} from '../../data/webapps/WebAppInstallRepository';
import {
  WebAppPinnedShortcutCoordinator,
  WebAppPinnedShortcutState
} from '../../core/webapps/WebAppPinnedShortcutCoordinator';
import { DesktopShortcutService } from '../shortcuts/DesktopShortcutService';
import {
  DESKTOP_INSTALL_REMOVAL_GRACE_MS,
  selectRemovedDesktopInstallShortcutIds,
  WebAppDesktopShortcutPresence
} from './WebAppDesktopInstallSyncPolicy';

const DOMAIN: number = 0x0000;
const TAG: string = 'WebAppDesktopInstallSync';

export interface WebAppDesktopInstallSyncResult {
  generation: number;
  pinnedShortcutIds: string[];
  pinQueryTrusted: boolean;
}

export type WebAppDesktopInstallSyncListener = (generation: number) => void;

class WebAppDesktopInstallSyncListenerRecord {
  key: string;
  listener: WebAppDesktopInstallSyncListener | undefined;

  constructor(key: string, listener: WebAppDesktopInstallSyncListener) {
    this.key = key;
    this.listener = listener;
  }
}

export class WebAppDesktopInstallSyncService {
  private repository: WebAppInstallRepository;
  private pinnedShortcutCoordinator: WebAppPinnedShortcutCoordinator;
  private shortcutService: DesktopShortcutService;
  private inFlight?: Promise<WebAppDesktopInstallSyncResult>;
  private syncGeneration: number = 0;
  private listenerSerial: number = 0;
  private listeners: WebAppDesktopInstallSyncListenerRecord[] = [];

  constructor(
    repository: WebAppInstallRepository = sharedWebAppInstallRepository,
    pinnedShortcutCoordinator: WebAppPinnedShortcutCoordinator = new WebAppPinnedShortcutCoordinator(),
    shortcutService: DesktopShortcutService = new DesktopShortcutService(repository)
  ) {
    this.repository = repository;
    this.pinnedShortcutCoordinator = pinnedShortcutCoordinator;
    this.shortcutService = shortcutService;
  }

  observe(listener: WebAppDesktopInstallSyncListener): string {
    this.listenerSerial += 1;
    const key = `web-app-desktop-install-sync-${this.listenerSerial}`;
    this.listeners.push(new WebAppDesktopInstallSyncListenerRecord(key, listener));
    return key;
  }

  unobserve(key: string): void {
    for (let index = 0; index < this.listeners.length; index += 1) {
      const record = this.listeners[index];
      if (record.key === key) {
        record.listener = undefined;
        return;
      }
    }
  }

  sync(): Promise<WebAppDesktopInstallSyncResult> {
    if (this.inFlight !== undefined) {
      return this.inFlight;
    }
    const task = this.runSync();
    this.inFlight = task;
    return task;
  }

  private async runSync(): Promise<WebAppDesktopInstallSyncResult> {
    try {
      return await this.syncInternal();
    } catch (_error) {
      return this.buildResult(this.syncGeneration, [], false);
    } finally {
      this.inFlight = undefined;
    }
  }

  private async syncInternal(): Promise<WebAppDesktopInstallSyncResult> {
    const generation = this.syncGeneration + 1;
    this.syncGeneration = generation;
    const empty = this.buildResult(generation, [], false);
    let records: DesktopWebEntryRecord[] = [];
    try {
      records = await this.repository.getAll();
    } catch (_error) {
      return empty;
    }
    const pinState = await this.pinnedShortcutCoordinator.queryPinnedShortcutState();
    const now = Date.now();
    const presenceByShortcutId: Record<string, WebAppDesktopShortcutPresence> = {};
    const displayIds = pinState.shortcutIds.slice();
    const installedRecords = records.filter((record: DesktopWebEntryRecord): boolean => {
      return record.installState === 'installed' && record.shortcutId.trim().length > 0;
    });
    for (let index = 0; index < installedRecords.length; index += 1) {
      const record = installedRecords[index];
      const shortcutId = record.shortcutId.trim();
      const presence = await this.resolvePresence(record, shortcutId, pinState, now);
      presenceByShortcutId[shortcutId] = presence;
      if (presence === 'present') {
        this.appendShortcutId(displayIds, shortcutId);
      }
    }
    const removedIds = selectRemovedDesktopInstallShortcutIds(
      records,
      presenceByShortcutId,
      now
    );
    const removedShortcutIds = await this.removeRecords(installedRecords, removedIds);
    if (removedShortcutIds.length > 0) {
      this.publishRemovedLater(generation);
    }
    return this.buildResult(generation, displayIds, pinState.isTrusted);
  }

  private async resolvePresence(
    record: DesktopWebEntryRecord,
    shortcutId: string,
    pinState: WebAppPinnedShortcutState,
    now: number
  ): Promise<WebAppDesktopShortcutPresence> {
    if (now - record.updatedAt < DESKTOP_INSTALL_REMOVAL_GRACE_MS) {
      return 'present';
    }
    if (!AppRuntimeContext.hasUIAbilityContext()) {
      return pinState.isTrusted && pinState.shortcutIds.indexOf(shortcutId) >= 0 ? 'present' : 'unknown';
    }
    const probed = await this.shortcutService.probeInstalledShortcut(
      AppRuntimeContext.getUIAbilityContext(),
      record
    );
    if (probed === 'present' || probed === 'absent') {
      return probed;
    }
    if (pinState.isTrusted && pinState.shortcutIds.indexOf(shortcutId) >= 0) {
      return 'present';
    }
    return 'unknown';
  }

  private async removeRecords(
    records: DesktopWebEntryRecord[],
    shortcutIds: string[]
  ): Promise<string[]> {
    const removedIds: string[] = [];
    for (let index = 0; index < shortcutIds.length; index += 1) {
      const shortcutId = shortcutIds[index];
      try {
        const removed = await this.repository.remove(shortcutId);
        if (!removed) {
          continue;
        }
        removedIds.push(shortcutId);
        const record = records.find((item: DesktopWebEntryRecord): boolean => item.shortcutId === shortcutId);
        if (record !== undefined) {
          await this.discardIcon(record.iconPath);
        }
        hilog.info(DOMAIN, TAG, 'Removed desktop web app no longer pinned: %{public}s', shortcutId);
      } catch (_error) {
        hilog.warn(DOMAIN, TAG, 'Failed to remove desktop web app record: %{public}s', shortcutId);
      }
    }
    return removedIds;
  }

  private async discardIcon(iconPath: string): Promise<void> {
    const path = iconPath.trim();
    if (path.length === 0 || path.indexOf('aira_desktop_') < 0 || !path.endsWith('.png')) {
      return;
    }
    try {
      await fileIo.unlink(path);
    } catch (_error) {
    }
  }

  private appendShortcutId(ids: string[], shortcutId: string): void {
    if (shortcutId.length === 0 || ids.indexOf(shortcutId) >= 0) {
      return;
    }
    ids.push(shortcutId);
  }

  private buildResult(
    generation: number,
    pinnedShortcutIds: string[],
    pinQueryTrusted: boolean
  ): WebAppDesktopInstallSyncResult {
    return {
      generation: generation,
      pinnedShortcutIds: pinnedShortcutIds,
      pinQueryTrusted: pinQueryTrusted
    };
  }

  private publishRemovedLater(generation: number): void {
    setTimeout((): void => {
      this.publishRemoved(generation);
    }, 0);
  }

  private publishRemoved(generation: number): void {
    for (let index = 0; index < this.listeners.length; index += 1) {
      const listener = this.listeners[index].listener;
      if (listener !== undefined) {
        listener(generation);
      }
    }
  }
}

export const sharedWebAppDesktopInstallSyncService: WebAppDesktopInstallSyncService =
  new WebAppDesktopInstallSyncService();
