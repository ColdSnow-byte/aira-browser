import {
  sharedPreferencesRepository,
  sharedSearchEngineRepository
} from '../../app/bootstrap/BrowserAppRuntime';
import { SearchEngineSelectionCoordinator } from '../search/SearchEngineSelectionCoordinator';
import { FeatureIntroExitDestination } from './FeatureIntroRoutePolicy';
import { FeatureIntroCoordinator, FeatureIntroHost } from './FeatureIntroCoordinator';
import { resolveFeatureIntroSearchEngineChoice } from './FeatureIntroSearchEngineViewModel';

export interface FeatureIntroSearchEngineHost extends FeatureIntroHost {
  openHomepageStyle: () => void;
  leave: (destination: FeatureIntroExitDestination) => void;
}

export class FeatureIntroSearchEngineCoordinator {
  private readonly host: FeatureIntroSearchEngineHost;
  private readonly intro: FeatureIntroCoordinator;
  private readonly selection: SearchEngineSelectionCoordinator;
  private leaving: boolean = false;

  constructor(host: FeatureIntroSearchEngineHost) {
    this.host = host;
    this.intro = new FeatureIntroCoordinator(host);
    this.selection = new SearchEngineSelectionCoordinator(
      sharedSearchEngineRepository,
      sharedPreferencesRepository
    );
  }

  continueWith(engineId: string): void {
    if (this.leaving) {
      return;
    }
    this.leaving = true;
    const choice = resolveFeatureIntroSearchEngineChoice(engineId);
    this.selection.select(choice, 'profile_persistent')
      .then((): void => {
        this.host.openHomepageStyle();
      })
      .catch((_error: Error): void => {
        this.host.openHomepageStyle();
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
