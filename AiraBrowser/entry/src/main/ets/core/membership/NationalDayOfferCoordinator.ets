import { MembershipFeature } from '../../features/membership/MembershipFeature';
import { NationalDayOfferStore } from '../../data/membership/NationalDayOfferStore';
import { MembershipPresentationService } from '../../services/membership/MembershipPresentationService';
import { AIRA_DISTRIBUTION_CAPABILITY_OWNER } from '../../common/config/AiraDistributionCapabilityOwner';
import { shouldPresentAiraProNationalDayOffer } from '../../services/membership/AiraProStorePricePolicy';

const NATIONAL_DAY_OFFER_DELAY_MS: number = 900;

export interface NationalDayOfferShell {
  promptsBlocked: () => boolean;
  openOffer: () => void;
}

/**
 * Shows the National Day lifetime offer once, after the shell is in front and
 * no other automatic prompt is holding the lane.
 */
export class NationalDayOfferCoordinator {
  private readonly membershipFeature: MembershipFeature;
  private readonly store: NationalDayOfferStore;
  private readonly shell: NationalDayOfferShell;
  private readonly presentationService: MembershipPresentationService = new MembershipPresentationService();
  private evaluateTimer: number = -1;
  private presenting: boolean = false;

  constructor(
    membershipFeature: MembershipFeature,
    store: NationalDayOfferStore,
    shell: NationalDayOfferShell
  ) {
    this.membershipFeature = membershipFeature;
    this.store = store;
    this.shell = shell;
  }

  scheduleEvaluation(): void {
    this.cancelEvaluation();
    this.evaluateTimer = setTimeout((): void => {
      this.evaluateTimer = -1;
      void this.evaluate();
    }, NATIONAL_DAY_OFFER_DELAY_MS);
  }

  private cancelEvaluation(): void {
    if (this.evaluateTimer >= 0) {
      clearTimeout(this.evaluateTimer);
      this.evaluateTimer = -1;
    }
  }

  private async evaluate(): Promise<void> {
    if (this.presenting || this.shell.promptsBlocked()) {
      return;
    }
    const lifetimeMember = this.presentationService.isLongTermMember(this.membershipFeature.getState());
    const purchaseAvailable = AIRA_DISTRIBUTION_CAPABILITY_OWNER.isAvailable('huawei_iap');
    if (!shouldPresentAiraProNationalDayOffer(Date.now(), false, lifetimeMember, purchaseAvailable)) {
      return;
    }
    let shown = false;
    try {
      shown = await this.store.hasShown();
    } catch (_error) {
      return;
    }
    if (shown || this.shell.promptsBlocked()) {
      return;
    }
    if (!shouldPresentAiraProNationalDayOffer(Date.now(), false, lifetimeMember, purchaseAvailable)) {
      return;
    }
    this.presenting = true;
    try {
      this.shell.openOffer();
    } catch (_error) {
      this.presenting = false;
      return;
    }
    try {
      await this.store.markShown();
    } catch (_error) {
    }
  }
}
