import {
  findHomeWallpaperChoice,
  HomeWallpaperChoice,
  HomeWallpaperChoiceKind,
  listHomeWallpaperChoices,
  normalizeHomeWallpaperSolidColorId,
  WallpaperAsset,
  WallpaperAssetSource,
  WallpaperMode,
  WallpaperRepositorySnapshot,
  WallpaperSettings
} from '../../common/models/WallpaperModels';

export type WallpaperImageMode = 'bing' | 'custom';
export type WallpaperBingPreviewStatus = 'idle' | 'loading' | 'ready' | 'error';

export interface WallpaperModeOptionViewState {
  id: WallpaperMode;
  title: string;
  summary: string;
  isSelected: boolean;
  isEnabled: boolean;
}

export interface WallpaperImageOptionViewState {
  id: WallpaperImageMode;
  title: string;
  previewPath: string;
  isSelected: boolean;
  isEmpty: boolean;
  isEnabled: boolean;
}

export interface WallpaperColorChoiceViewState {
  id: string;
  label: string;
  kind: HomeWallpaperChoiceKind;
  /** Empty for the auto and follow-theme choices, which paint more than one color. */
  color: string;
  isSelected: boolean;
  isEnabled: boolean;
}

export interface WallpaperSettingsViewState {
  mode: WallpaperMode;
  modeTitle: string;
  colorChoices: WallpaperColorChoiceViewState[];
  imageOptions: WallpaperImageOptionViewState[];
  bingPreviewStatus: WallpaperBingPreviewStatus;
  bingPreviewStatusText: string;
  bingRetryVisible: boolean;
  footerText: string;
}

export class WallpaperSettingsViewModel {
  buildState(
    snapshot: WallpaperRepositorySnapshot,
    bingPreviewStatus: WallpaperBingPreviewStatus = 'idle'
  ): WallpaperSettingsViewState {
    const settings = snapshot.settings;
    const hasBingPreview = this.findImageAsset('bing', snapshot) !== undefined;
    const bingPreviewStatusText = this.buildBingPreviewStatusText(bingPreviewStatus, hasBingPreview);
    const bingRetryVisible = bingPreviewStatus === 'error';
    const footerText = '必应壁纸每天自动检查更新，仅用于 Aira 原生主页；自定义主页和隐私主页不会显示。';
    return {
      mode: settings.mode,
      modeTitle: this.resolveModeTitle(settings),
      colorChoices: this.buildColorChoices(settings),
      imageOptions: this.buildImageOptions(snapshot),
      bingPreviewStatus: bingPreviewStatus,
      bingPreviewStatusText: bingPreviewStatusText,
      bingRetryVisible: bingRetryVisible,
      footerText: footerText
    };
  }

  /** Auto black/white first, then the flat colors, then follow-theme last. */
  private buildColorChoices(settings: WallpaperSettings): WallpaperColorChoiceViewState[] {
    const choices: WallpaperColorChoiceViewState[] = [];
    listHomeWallpaperChoices().forEach((choice: HomeWallpaperChoice) => {
      choices.push({
        id: choice.id,
        label: choice.label,
        kind: choice.kind,
        color: choice.color,
        isSelected: this.isChoiceSelected(settings, choice),
        isEnabled: true
      });
    });
    return choices;
  }

  private isChoiceSelected(settings: WallpaperSettings, choice: HomeWallpaperChoice): boolean {
    if (choice.kind === 'auto') {
      return settings.mode === 'auto';
    }
    if (choice.kind === 'theme') {
      return settings.mode === 'theme';
    }
    return settings.mode === 'solid' &&
      normalizeHomeWallpaperSolidColorId(settings.solidColorId) === choice.id;
  }

  buildSettingsWithMode(settings: WallpaperSettings, mode: WallpaperMode): WallpaperSettings {
    return {
      mode: mode,
      solidColorId: settings.solidColorId,
      bingWallpaperId: settings.bingWallpaperId,
      customWallpaperId: settings.customWallpaperId,
      bing: settings.bing,
      updatedAt: Date.now()
    };
  }

  buildSettingsWithSolidColor(settings: WallpaperSettings, solidColorId: string): WallpaperSettings {
    return {
      mode: 'solid',
      solidColorId: normalizeHomeWallpaperSolidColorId(solidColorId),
      bingWallpaperId: settings.bingWallpaperId,
      customWallpaperId: settings.customWallpaperId,
      bing: settings.bing,
      updatedAt: Date.now()
    };
  }

  /** Names the current wallpaper, so the settings row can show what is actually painted. */
  private resolveModeTitle(settings: WallpaperSettings): string {
    if (settings.mode === 'solid') {
      const choice = findHomeWallpaperChoice(settings.solidColorId);
      return choice === undefined ? this.getModeTitle('solid') : choice.label;
    }
    return this.getModeTitle(settings.mode);
  }

  private buildImageOptions(snapshot: WallpaperRepositorySnapshot): WallpaperImageOptionViewState[] {
    return [
      this.buildImageOption('bing', snapshot),
      this.buildImageOption('custom', snapshot)
    ];
  }

  private buildImageOption(
    mode: WallpaperImageMode,
    snapshot: WallpaperRepositorySnapshot
  ): WallpaperImageOptionViewState {
    const asset = this.findImageAsset(mode, snapshot);
    const previewPath = this.resolvePreviewPath(asset);
    return {
      id: mode,
      title: this.getModeTitle(mode),
      previewPath: previewPath,
      isSelected: snapshot.settings.mode === mode,
      isEmpty: previewPath.trim().length <= 0,
      isEnabled: true
    };
  }

  private findImageAsset(
    mode: WallpaperImageMode,
    snapshot: WallpaperRepositorySnapshot
  ): WallpaperAsset | undefined {
    const source: WallpaperAssetSource = mode;
    const selectedId = mode === 'bing' ?
      (snapshot.settings.bingWallpaperId.trim().length > 0 ?
        snapshot.settings.bingWallpaperId : snapshot.settings.bing.currentAssetId) :
      snapshot.settings.customWallpaperId;
    if (mode === 'custom' && selectedId.trim().length <= 0) {
      return undefined;
    }
    const selected = snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === source && asset.id === selectedId && this.resolvePreviewPath(asset).length > 0;
    });
    if (selected !== undefined || mode === 'custom') {
      return selected;
    }
    return snapshot.assets.find((asset: WallpaperAsset) => {
      return asset.source === source && this.resolvePreviewPath(asset).length > 0;
    });
  }

  private resolvePreviewPath(asset: WallpaperAsset | undefined): string {
    if (asset === undefined) {
      return '';
    }
    if (asset.thumbPath.trim().length > 0) {
      return asset.thumbPath;
    }
    return asset.displayPath.trim();
  }

  private getModeTitle(mode: WallpaperMode): string {
    switch (mode) {
      case 'auto':
        return '自动黑白';
      case 'theme':
        return '跟随主题色';
      case 'solid':
        return '纯色背景';
      case 'bing':
        return '必应壁纸';
      case 'custom':
        return '自定义壁纸';
      default:
        return '跟随主题色';
    }
  }

  private buildBingPreviewStatusText(
    status: WallpaperBingPreviewStatus,
    hasBingPreview: boolean
  ): string {
    if (status === 'loading') {
      return hasBingPreview ? '正在检查必应每日壁纸更新…' : '正在获取必应每日壁纸…';
    }
    if (status === 'error') {
      return hasBingPreview ? '今日壁纸更新失败，正在继续使用缓存。' : '必应壁纸加载失败，请检查网络后重试。';
    }
    return '';
  }

}
