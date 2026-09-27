import { image } from '@kit.ImageKit';

/**
 * The drawable copy of a tab's component snapshot.
 *
 * Huawei keeps this in PixelMapCache and the card's image reads it back with
 * getPixelMapCache. The object returned by component snapshot itself is not what
 * Image paints.
 */
let pixelMapsByTabId: Record<string, image.PixelMap> = {};

export class BrowserTabSnapshotPixelMapCache {
  static put(tabId: string, pixelMap: image.PixelMap): void {
    const key = tabId.trim();
    if (key.length === 0) {
      return;
    }
    pixelMapsByTabId[key] = pixelMap;
  }

  static get(tabId: string): image.PixelMap | undefined {
    return pixelMapsByTabId[tabId.trim()];
  }

  static clear(): void {
    pixelMapsByTabId = {};
  }
}
