import { Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { productViewManager } from '@kit.AppGalleryKit';
import { DESKTOP_WEB_SHORTCUT_WANT_KEYS } from '../../data/webapps/WebAppInstallModels';
import {
  collectPinnedShortcutIds,
  WebAppPinShortcutSnapshot
} from '../../services/webapps/WebAppDesktopInstallSyncPolicy';

export interface WebAppPinnedShortcutState {
  shortcutIds: string[];
  isTrusted: boolean;
  errorCode: number;
}

interface PinShortcutInfoCompat {
  shortcutId?: string;
  want?: Want;
}

export class WebAppPinnedShortcutCoordinator {
  async queryPinnedShortcutState(): Promise<WebAppPinnedShortcutState> {
    try {
      const infos = await productViewManager.getPinShortcutInfos() as Object[];
      if (!Array.isArray(infos)) {
        return {
          shortcutIds: [],
          isTrusted: false,
          errorCode: 0
        };
      }
      return {
        shortcutIds: collectPinnedShortcutIds(this.toSnapshots(infos)),
        isTrusted: true,
        errorCode: 0
      };
    } catch (error) {
      const businessError = error as BusinessError;
      return {
        shortcutIds: [],
        isTrusted: false,
        errorCode: Number(businessError?.code ?? 0)
      };
    }
  }

  private toSnapshots(infos: Object[]): WebAppPinShortcutSnapshot[] {
    const snapshots: WebAppPinShortcutSnapshot[] = [];
    infos.forEach((info: Object) => {
      try {
        snapshots.push(this.toSnapshot(info));
      } catch (_error) {
      }
    });
    return snapshots;
  }

  private toSnapshot(info: Object): WebAppPinShortcutSnapshot {
    const record = info as PinShortcutInfoCompat;
    const parameters = record.want?.parameters as Record<string, Object> | undefined;
    return {
      shortcutId: this.readString(record.shortcutId),
      parameterShortcutId: this.readString(parameters?.[DESKTOP_WEB_SHORTCUT_WANT_KEYS.shortcutId])
    };
  }

  private readString(value: Object | string | undefined): string {
    if (typeof value !== 'string') {
      return '';
    }
    return value.trim();
  }
}
