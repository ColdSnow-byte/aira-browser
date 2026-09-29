import {
  DEFAULT_HOME_WALLPAPER_PRESENTATION_STATE,
  findHomeWallpaperChoice,
  HomeWallpaperForegroundTone,
  HomeWallpaperPresentationKind,
  HomeWallpaperPresentationState,
  normalizeHomeWallpaperSolidColorId,
  WallpaperAsset,
  WallpaperMode,
  WallpaperRepositorySnapshot,
  WallpaperSettings,
  cloneHomeWallpaperPresentationState
} from '../../common/models/WallpaperModels';
import { HOME_IMAGE_WALLPAPER_MASK_OPACITY } from './HomeWallpaperAnalysisPolicy';


interface WallpaperPresentationContentState {
  kind: HomeWallpaperPresentationKind;
  mode: WallpaperMode;
  foregroundTone: HomeWallpaperForegroundTone;
  imagePath: string;
  videoPath: string;
  solidColor: string;
  assetId: string;
  updatedAt: number;
}

export class WallpaperPresentationService {
  buildPresentationState(
    snapshot: WallpaperRepositorySnapshot,
    nowMs: number = Date.now()
  ): HomeWallpaperPresentationState {
    const settings = snapshot.settings;
    switch (settings.mode) {
      case 'auto':
        return this.buildAutoPresentationState(settings);
      case 'solid':
        return this.buildSolidPresentationState(settings);
      case 'bing':
        return this.buildBingPresentationState(settings, snapshot.assets);
      case 'custom':
        return this.buildCustomPresentationState(settings, snapshot.assets);
      case 'theme':
      default:
        return this.buildDefaultPresentationState();
    }
  }

  buildDefaultPresentationState(): HomeWallpaperPresentationState {
    return this.clonePresentationState(DEFAULT_HOME_WALLPAPER_PRESENTATION_STATE);
  }

  /**
   * Auto black/white carries no color of its own: the layer paints white or black from the
   * current light or dark mode, and the tone stays the theme's, which already matches.
   */
  private buildAutoPresentationState(settings: WallpaperSettings): HomeWallpaperPresentationState {
    return this.withSharedSettings(settings, {
      kind: 'auto',
      mode: 'auto',
      foregroundTone: 'darkText',
      imagePath: '',
      videoPath: '',
      solidColor: '',
      assetId: '',
      updatedAt: settings.updatedAt
    });
  }

  /** A flat color paints the home the way a photo does, minus the readability mask. */
  private buildSolidPresentationState(settings: WallpaperSettings): HomeWallpaperPresentationState {
    const solidColorId = normalizeHomeWallpaperSolidColorId(settings.solidColorId);
    const choice = findHomeWallpaperChoice(solidColorId);
    return this.withSharedSettings(settings, {
      kind: 'solid',
      mode: 'solid',
      foregroundTone: choice === undefined ? 'darkText' : choice.foregroundTone,
      imagePath: '',
      videoPath: '',
      solidColor: choice === undefined ? '#FFFFFF' : choice.color,
      assetId: solidColorId,
      updatedAt: settings.updatedAt
    });
  }

  private buildBingPresentationState(
    settings: WallpaperSettings,
    assets: WallpaperAsset[]
  ): HomeWallpaperPresentationState {
    const selectedAssetId = settings.bingWallpaperId.length > 0
      ? settings.bingWallpaperId
      : settings.bing.currentAssetId;
    const bingAssets = this.filterUsableImageAssets(assets, 'bing');
    const asset = this.findAsset(bingAssets, selectedAssetId);
    if (asset === undefined) {
      return this.buildDefaultPresentationState();
    }
    return this.withSharedSettings(settings, {
      kind: 'image',
      mode: 'bing',
      foregroundTone: asset.foregroundTone,
      imagePath: asset.displayPath,
      videoPath: '',
      solidColor: '',
      assetId: asset.id,
      updatedAt: this.resolveContentUpdatedAt(asset.updatedAt, settings.updatedAt)
    });
  }

  private buildCustomPresentationState(
    settings: WallpaperSettings,
    assets: WallpaperAsset[]
  ): HomeWallpaperPresentationState {
    // Video stays on the custom mode so sync still sends one preference, not a new mode string.
    // A device without the file falls back the same way a missing custom photo does.
    const selectedVideo = this.findSelectedVideoAsset(assets, settings.customWallpaperId);
    if (selectedVideo !== undefined) {
      return this.withSharedSettings(settings, {
        kind: 'video',
        mode: 'custom',
        foregroundTone: selectedVideo.foregroundTone,
        imagePath: this.resolveVideoPosterPath(selectedVideo),
        videoPath: this.resolvePlayableVideoPath(selectedVideo.displayPath),
        solidColor: '',
        assetId: selectedVideo.id,
        updatedAt: this.resolveContentUpdatedAt(selectedVideo.updatedAt, settings.updatedAt)
      });
    }
    const customAssets = this.filterUsableImageAssets(assets, 'custom');
    const asset = this.findAsset(customAssets, settings.customWallpaperId);
    if (asset === undefined) {
      return this.buildDefaultPresentationState();
    }
    return this.withSharedSettings(settings, {
      kind: 'image',
      mode: 'custom',
      foregroundTone: asset.foregroundTone,
      imagePath: asset.displayPath,
      videoPath: '',
      solidColor: '',
      assetId: asset.id,
      updatedAt: this.resolveContentUpdatedAt(asset.updatedAt, settings.updatedAt)
    });
  }

  private findSelectedVideoAsset(assets: WallpaperAsset[], assetId: string): WallpaperAsset | undefined {
    const selectedId = assetId.trim();
    if (selectedId.length <= 0) {
      return undefined;
    }
    return assets.find((asset: WallpaperAsset) => {
      return asset.source === 'custom' &&
        asset.id === selectedId &&
        asset.mediaType === 'video' &&
        asset.displayPath.length > 0;
    });
  }

  /** The video player wants a sandbox path. Image still uses the file URI. */
  private resolvePlayableVideoPath(uri: string): string {
    const normalized = uri.trim();
    if (!normalized.startsWith('file://')) {
      return normalized;
    }
    const path = normalized.substring('file://'.length);
    return path.startsWith('/') ? path : normalized;
  }

  private resolveVideoPosterPath(asset: WallpaperAsset): string {
    const thumb = asset.thumbPath.trim();
    if (thumb.length <= 0 || thumb === asset.displayPath.trim()) {
      return '';
    }
    return thumb;
  }

  private filterUsableImageAssets(assets: WallpaperAsset[], source: string): WallpaperAsset[] {
    const results: WallpaperAsset[] = [];
    assets.forEach((asset: WallpaperAsset) => {
      if (asset.source === source && asset.mediaType === 'image' && asset.displayPath.length > 0) {
        results.push(asset);
      }
    });
    return results;
  }

  private findAsset(assets: WallpaperAsset[], assetId: string): WallpaperAsset | undefined {
    const normalizedAssetId = assetId.trim();
    let fallback: WallpaperAsset | undefined = undefined;
    assets.forEach((asset: WallpaperAsset) => {
      if (fallback === undefined) {
        fallback = asset;
      }
    });
    const asset = assets.find((item: WallpaperAsset) => item.id === normalizedAssetId);
    return asset === undefined ? fallback : asset;
  }

  private withSharedSettings(
    settings: WallpaperSettings,
    state: WallpaperPresentationContentState
  ): HomeWallpaperPresentationState {
    return {
      kind: state.kind,
      mode: state.mode,
      foregroundTone: state.foregroundTone,
      imagePath: state.imagePath,
      videoPath: state.videoPath,
      solidColor: state.solidColor,
      maskOpacity: state.kind === 'image' || state.kind === 'video' ? HOME_IMAGE_WALLPAPER_MASK_OPACITY : 0,
      assetId: state.assetId,
      updatedAt: this.resolveContentUpdatedAt(state.updatedAt, settings.updatedAt)
    };
  }

  private resolveContentUpdatedAt(primary: number, fallback: number): number {
    const primaryValue = this.normalizeTimestamp(primary);
    if (primaryValue > 0) {
      return primaryValue;
    }
    return this.normalizeTimestamp(fallback);
  }

  private normalizeTimestamp(value: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return 0;
    }
    return Math.floor(value);
  }

  private clonePresentationState(state: HomeWallpaperPresentationState): HomeWallpaperPresentationState {
    return cloneHomeWallpaperPresentationState(state);
  }

}
