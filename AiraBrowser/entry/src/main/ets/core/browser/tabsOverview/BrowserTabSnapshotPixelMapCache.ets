import { image } from '@kit.ImageKit';

/**
 * The drawable copy of a tab's component snapshot.
 *
 * Huawei keeps this in PixelMapCache and the card's image reads it back with
 * getPixelMapCache. The object returned by component snapshot itself is not what
 * Image paints.
 */
let pixelMapsByTabId: Record<string, image.PixelMap> = {};
let generationByTabId: Record<string, number> = {};

export class BrowserTabSnapshotPixelMapCache {
  static put(tabId: string, pixelMap: image.PixelMap): void {
    const key = tabId.trim();
    if (key.length === 0) {
      return;
    }
    pixelMapsByTabId[key] = pixelMap;
    generationByTabId[key] = (generationByTabId[key] ?? 0) + 1;
  }

  static get(tabId: string): image.PixelMap | undefined {
    return pixelMapsByTabId[tabId.trim()];
  }

  static generation(tabId: string): number {
    return generationByTabId[tabId.trim()] ?? 0;
  }

  static clear(): void {
    pixelMapsByTabId = {};
    generationByTabId = {};
  }
}
