import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';
import {
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_HEIGHT_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_URI_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_WIDTH_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_ID_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY,
  HOME_PAGE_PRESENTATION_HOME_PAGE_STYLE_KEY,
  HOME_PAGE_PRESENTATION_SHOW_FAVORITES_TITLE_KEY,
  HOME_PAGE_PRESENTATION_SHOW_RECENTLY_CLOSED_TITLE_KEY,
  HOME_PAGE_PRESENTATION_SHOW_SETTINGS_BUTTON_KEY,
  HOME_PAGE_PRESENTATION_SHOW_SHORTCUT_NAMES_KEY
} from '../../common/constants/HomePagePresentationStorageKeys';
import {
  findHomeLogoCustomAsset,
  HOME_LOGO_BUILTIN_ID,
  HomeLogoCustomAsset,
  HomeLogoSelection,
  normalizeHomeLogoCustomAssets,
  normalizeHomeLogoSelection
} from '../../common/models/HomeLogoModels';
import {
  BrowserHomePageStyle,
  HomePagePresentationSettings,
  normalizeBrowserHomePageStyle
} from '../../common/models/HomePagePresentationSettingsModels';
import {
  HOME_LOGO_OPACITY_DEFAULT,
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  normalizeHomeLogoOpacity,
  normalizeHomeLogoScaleRatio
} from '../../core/settings/HomeLogoSettingsPolicy';
import {
  PersonalizationSettingsChangeOrigin,
  PersonalizationSettingsLocalChangeHandler
} from '../../common/models/PersonalizationSyncModels';

const PREFERENCES_NAME: string = 'aira_home_page_presentation';
const SETTINGS_KEY: string = 'settings_v1';

export const DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS: HomePagePresentationSettings = {
  showFavoritesTitle: true,
  showShortcutNames: true,
  showRecentlyClosedTitle: true,
  showSettingsButton: true,
  homePageStyle: 'classic',
  homeLogoId: HOME_LOGO_BUILTIN_ID,
  homeLogoCustomAssets: [],
  homeLogoScaleRatio: HOME_LOGO_SCALE_DEFAULT_RATIO,
  homeLogoOpacity: HOME_LOGO_OPACITY_DEFAULT
};

export class HomePagePresentationSettingsRepository {
  private store?: preferences.Preferences;
  private storePromise?: Promise<preferences.Preferences>;
  private settings: HomePagePresentationSettings = this.copySettings(DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS);
  private localChangeHandler?: PersonalizationSettingsLocalChangeHandler;

  setLocalChangeHandler(handler?: PersonalizationSettingsLocalChangeHandler): void {
    this.localChangeHandler = handler;
  }

  async initialize(): Promise<HomePagePresentationSettings> {
    const store = await this.getStore();
    const rawSettings = String(store.getSync(SETTINGS_KEY, ''));
    this.settings = this.normalizeSettings(this.parseSettings(rawSettings));
    this.publishSettings();
    if (rawSettings.trim().length === 0) {
      await this.persistSettings(this.settings, 'system');
    }
    return this.getSettings();
  }

  getSettings(): HomePagePresentationSettings {
    return this.copySettings(this.settings);
  }

  async updateSettings(
    settings: HomePagePresentationSettings,
    origin: PersonalizationSettingsChangeOrigin = 'local'
  ): Promise<HomePagePresentationSettings> {
    return this.persistSettings(settings, origin);
  }

  async setHomePageStyle(style: BrowserHomePageStyle): Promise<HomePagePresentationSettings> {
    const next = this.getSettings();
    next.homePageStyle = normalizeBrowserHomePageStyle(style);
    return this.persistSettings(next, 'local');
  }

  async setHomeLogoSelection(
    selection: HomeLogoSelection,
    origin: PersonalizationSettingsChangeOrigin = 'local'
  ): Promise<HomePagePresentationSettings> {
    const next = this.getSettings();
    const normalized = normalizeHomeLogoSelection(selection);
    next.homeLogoId = normalized.id;
    next.homeLogoCustomAssets = normalized.customAssets;
    return this.persistSettings(next, origin);
  }

  async setHomeLogoScaleRatio(
    scaleRatio: number,
    origin: PersonalizationSettingsChangeOrigin = 'local'
  ): Promise<HomePagePresentationSettings> {
    const next = this.getSettings();
    next.homeLogoScaleRatio = normalizeHomeLogoScaleRatio(scaleRatio);
    return this.persistSettings(next, origin);
  }

  async setHomeLogoOpacity(
    opacity: number,
    origin: PersonalizationSettingsChangeOrigin = 'local'
  ): Promise<HomePagePresentationSettings> {
    const next = this.getSettings();
    next.homeLogoOpacity = normalizeHomeLogoOpacity(opacity);
    return this.persistSettings(next, origin);
  }

  private async persistSettings(
    settings: HomePagePresentationSettings,
    origin: PersonalizationSettingsChangeOrigin
  ): Promise<HomePagePresentationSettings> {
    const previous = this.getSettings();
    this.settings = this.normalizeSettings(settings);
    const store = await this.getStore();
    store.putSync(SETTINGS_KEY, JSON.stringify(this.settings));
    store.flushSync();
    this.publishSettings();
    if (origin === 'local' && !this.isSameSettings(previous, this.settings)) {
      this.localChangeHandler?.();
    }
    return this.getSettings();
  }

  private isSameSettings(
    left: HomePagePresentationSettings,
    right: HomePagePresentationSettings
  ): boolean {
    return left.showFavoritesTitle === right.showFavoritesTitle &&
      left.showShortcutNames === right.showShortcutNames &&
      left.showRecentlyClosedTitle === right.showRecentlyClosedTitle &&
      left.showSettingsButton === right.showSettingsButton &&
      left.homePageStyle === right.homePageStyle &&
      left.homeLogoId === right.homeLogoId &&
      left.homeLogoScaleRatio === right.homeLogoScaleRatio &&
      left.homeLogoOpacity === right.homeLogoOpacity &&
      this.isSameLogoAssets(left.homeLogoCustomAssets, right.homeLogoCustomAssets);
  }

  private isSameLogoAssets(left: HomeLogoCustomAsset[], right: HomeLogoCustomAsset[]): boolean {
    if (left.length !== right.length) {
      return false;
    }
    for (let index = 0; index < left.length; index += 1) {
      if (left[index].id !== right[index].id || left[index].uri !== right[index].uri) {
        return false;
      }
    }
    return true;
  }

  private publishSettings(): void {
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_SHOW_FAVORITES_TITLE_KEY,
      this.settings.showFavoritesTitle
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_SHOW_SHORTCUT_NAMES_KEY,
      this.settings.showShortcutNames
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_SHOW_RECENTLY_CLOSED_TITLE_KEY,
      this.settings.showRecentlyClosedTitle
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_SHOW_SETTINGS_BUTTON_KEY,
      this.settings.showSettingsButton
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_PAGE_STYLE_KEY,
      this.settings.homePageStyle
    );
    AppStorage.setOrCreate(HOME_PAGE_PRESENTATION_HOME_LOGO_ID_KEY, this.settings.homeLogoId);
    // The mark resolves through these three keys, so they publish the selected custom asset.
    const selectedAsset = findHomeLogoCustomAsset(
      this.settings.homeLogoCustomAssets,
      this.settings.homeLogoId
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_URI_KEY,
      selectedAsset === undefined ? '' : selectedAsset.uri
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_WIDTH_KEY,
      selectedAsset === undefined ? 0 : selectedAsset.width
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_LOGO_CUSTOM_HEIGHT_KEY,
      selectedAsset === undefined ? 0 : selectedAsset.height
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY,
      this.settings.homeLogoScaleRatio
    );
    AppStorage.setOrCreate(
      HOME_PAGE_PRESENTATION_HOME_LOGO_OPACITY_KEY,
      this.settings.homeLogoOpacity
    );
  }

  private parseSettings(value: string): HomePagePresentationSettings | undefined {
    if (value.trim().length === 0) {
      return undefined;
    }
    try {
      return JSON.parse(value) as HomePagePresentationSettings;
    } catch (_error) {
      return undefined;
    }
  }

  private normalizeSettings(
    settings: HomePagePresentationSettings | undefined
  ): HomePagePresentationSettings {
    const logo = this.normalizeLogoSelection(settings);
    return {
      showFavoritesTitle: typeof settings?.showFavoritesTitle === 'boolean'
        ? settings.showFavoritesTitle
        : DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS.showFavoritesTitle,
      showShortcutNames: typeof settings?.showShortcutNames === 'boolean'
        ? settings.showShortcutNames
        : DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS.showShortcutNames,
      showRecentlyClosedTitle: typeof settings?.showRecentlyClosedTitle === 'boolean'
        ? settings.showRecentlyClosedTitle
        : DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS.showRecentlyClosedTitle,
      showSettingsButton: typeof settings?.showSettingsButton === 'boolean'
        ? settings.showSettingsButton
        : DEFAULT_HOME_PAGE_PRESENTATION_SETTINGS.showSettingsButton,
      homePageStyle: normalizeBrowserHomePageStyle(settings?.homePageStyle),
      homeLogoId: logo.id,
      homeLogoCustomAssets: logo.customAssets,
      homeLogoScaleRatio: normalizeHomeLogoScaleRatio(settings?.homeLogoScaleRatio),
      homeLogoOpacity: normalizeHomeLogoOpacity(settings?.homeLogoOpacity)
    };
  }

  private normalizeLogoSelection(
    settings: HomePagePresentationSettings | undefined
  ): HomeLogoSelection {
    return normalizeHomeLogoSelection({
      id: settings?.homeLogoId ?? HOME_LOGO_BUILTIN_ID,
      customAssets: normalizeHomeLogoCustomAssets(settings?.homeLogoCustomAssets)
    });
  }

  private copySettings(settings: HomePagePresentationSettings): HomePagePresentationSettings {
    return {
      showFavoritesTitle: settings.showFavoritesTitle,
      showShortcutNames: settings.showShortcutNames,
      showRecentlyClosedTitle: settings.showRecentlyClosedTitle,
      showSettingsButton: settings.showSettingsButton,
      homePageStyle: normalizeBrowserHomePageStyle(settings.homePageStyle),
      homeLogoId: settings.homeLogoId,
      homeLogoCustomAssets: this.copyLogoAssets(settings.homeLogoCustomAssets),
      homeLogoScaleRatio: normalizeHomeLogoScaleRatio(settings.homeLogoScaleRatio),
      homeLogoOpacity: normalizeHomeLogoOpacity(settings.homeLogoOpacity)
    };
  }

  private copyLogoAssets(assets: HomeLogoCustomAsset[]): HomeLogoCustomAsset[] {
    const copy: HomeLogoCustomAsset[] = [];
    for (let index = 0; index < assets.length; index += 1) {
      const asset = assets[index];
      copy.push({
        id: asset.id,
        uri: asset.uri,
        fileName: asset.fileName,
        width: asset.width,
        height: asset.height
      });
    }
    return copy;
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== undefined) {
      return this.store;
    }
    if (this.storePromise === undefined) {
      this.storePromise = preferences.getPreferences(AppRuntimeContext.getApplicationContext(), PREFERENCES_NAME)
        .then((store: preferences.Preferences) => {
          this.store = store;
          return store;
        });
    }
    return this.storePromise;
  }
}
