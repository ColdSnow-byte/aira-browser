import { preferences } from '@kit.ArkData';
import { AppRuntimeContext } from '../../app/runtime/AppRuntimeContext';

const PREFERENCES_NAME: string = 'aira_membership_national_day_offer';
const SHOWN_KEY: string = 'shown_2026';

/**
 * Device-local memory for the National Day purchase notice. It records only
 * that this device has already shown the notice; the price itself does not
 * depend on it.
 */
export class NationalDayOfferStore {
  private store?: preferences.Preferences;
  private storePromise?: Promise<preferences.Preferences>;
  private shown: boolean = false;

  async hasShown(): Promise<boolean> {
    if (this.shown) {
      return true;
    }
    const store = await this.getStore();
    this.shown = store.getSync(SHOWN_KEY, false) === true;
    return this.shown;
  }

  async markShown(): Promise<void> {
    this.shown = true;
    const store = await this.getStore();
    store.putSync(SHOWN_KEY, true);
    store.flushSync();
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store !== undefined) {
      return this.store;
    }
    if (this.storePromise === undefined) {
      this.storePromise = preferences.getPreferences(AppRuntimeContext.getApplicationContext(), PREFERENCES_NAME)
        .then((store: preferences.Preferences): preferences.Preferences => {
          this.store = store;
          return store;
        });
    }
    return this.storePromise;
  }
}

export const sharedNationalDayOfferStore: NationalDayOfferStore = new NationalDayOfferStore();
