import { BrowserHomePageStyle } from '../../common/models/HomePagePresentationSettingsModels';
import { HomePagePresentationSettingsRepository } from '../../data/preferences/HomePagePresentationSettingsRepository';
import { PreferencesRepository } from '../../data/preferences/PreferencesRepository';
import { CustomHomepageSettingsCoordinator } from './CustomHomepageSettingsCoordinator';
import { HomePageSettingsCoordinator } from '../settings/HomePageSettingsCoordinator';
import { resolveSystemHomepageToolbarChrome } from './SystemHomepageStyleCatalog';

/**
 * Picking a built-in homepage writes which frame the new tab uses. That frame is part of
 * Personalization Sync. An imported custom homepage stays on this device, because its files
 * are not in the snapshot.
 *
 * The recovery-entry guard runs last. The centered frame pins its settings tile, the
 * minimal frame has no on-page entry and must not rewrite stored flags, and the classic
 * frame forces its bottom settings button on when favorites and recently closed are both off.
 */
export class SystemHomepageSelectionService {
  private customHomepageCoordinator: CustomHomepageSettingsCoordinator;
  private presentationRepository: HomePagePresentationSettingsRepository;
  private recoveryEntryGuard: HomePageSettingsCoordinator;
  private preferencesRepository: PreferencesRepository;

  constructor(
    customHomepageCoordinator: CustomHomepageSettingsCoordinator,
    presentationRepository: HomePagePresentationSettingsRepository,
    recoveryEntryGuard: HomePageSettingsCoordinator,
    preferencesRepository: PreferencesRepository
  ) {
    this.customHomepageCoordinator = customHomepageCoordinator;
    this.presentationRepository = presentationRepository;
    this.recoveryEntryGuard = recoveryEntryGuard;
    this.preferencesRepository = preferencesRepository;
  }

  async selectSystemHomepageStyle(style: BrowserHomePageStyle): Promise<void> {
    await this.customHomepageCoordinator.selectSystemHomepage();
    await this.presentationRepository.setHomePageStyle(style);
    await this.preferencesRepository.updateToolbarChromeStyle(resolveSystemHomepageToolbarChrome(style));
    await this.recoveryEntryGuard.ensureRecoveryEntryAvailable();
  }
}
