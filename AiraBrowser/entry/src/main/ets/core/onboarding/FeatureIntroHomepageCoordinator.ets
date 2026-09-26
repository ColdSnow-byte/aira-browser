import {
  sharedCustomHomepageRepository,
  sharedHomePagePresentationSettingsRepository,
  sharedPreferencesRepository
} from '../../app/bootstrap/BrowserAppRuntime';
import { CustomHomepageSettingsCoordinator } from '../customhome/CustomHomepageSettingsCoordinator';
import { SystemHomepageSelectionService } from '../customhome/SystemHomepageSelectionService';
import { HomePageSettingsCoordinator } from '../settings/HomePageSettingsCoordinator';
import { FeatureIntroCoordinator, FeatureIntroHost } from './FeatureIntroCoordinator';
import { resolveFeatureIntroHomepageStyle } from './FeatureIntroHomepageViewModel';

export class FeatureIntroHomepageCoordinator {
  private readonly intro: FeatureIntroCoordinator;
  private readonly selection: SystemHomepageSelectionService;
  private leaving: boolean = false;

  constructor(host: FeatureIntroHost) {
    this.intro = new FeatureIntroCoordinator(host);
    this.selection = new SystemHomepageSelectionService(
      new CustomHomepageSettingsCoordinator(sharedCustomHomepageRepository),
      sharedHomePagePresentationSettingsRepository,
      new HomePageSettingsCoordinator(
        sharedPreferencesRepository,
        sharedCustomHomepageRepository,
        sharedHomePagePresentationSettingsRepository
      ),
      sharedPreferencesRepository
    );
  }

  continueWith(style: string): void {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    this.selection.selectSystemHomepageStyle(resolveFeatureIntroHomepageStyle(style))
      .then((): void => {
        this.intro.finish();
      })
      .catch((_error: Error): void => {
        this.intro.finish();
      });
  }

  skip(): void {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    this.intro.skipToBrowser();
  }

  abandonLeave(): void {
    this.leaving = false;
    this.intro.abandonLeave();
  }
}
