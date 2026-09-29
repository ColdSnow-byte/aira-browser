import { describe, expect, it } from '@ohos/hypium';
import {
  AiraMembershipState,
  AiraSubscriptionStatus,
  buildDefaultMembershipState
} from '../main/ets/common/models/MembershipModels';
import { AiraProPurchasePolicyService } from '../main/ets/services/membership/AiraProPurchasePolicyService';
import { AIRA_PRO_YEARLY_PRODUCT_ID } from '../main/ets/services/membership/HuaweiIapProductCatalog';

const NOW: number = Date.UTC(2026, 3, 8);
const THIRTY_DAYS_MS: number = 30 * 24 * 60 * 60 * 1000;

export default function airaProPurchasePolicyServiceTest(): void {
  describe('Aira Pro purchase policy', () => {
    it('lets a timed claim buy the permanent plan without waiting for the expiry date', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      const claimed = membership('pro', NOW + THIRTY_DAYS_MS);
      expect(policy.resolveOneTimePlanAction(claimed)).assertEqual('purchase');
    });

    it('lets a live subscription buy the permanent plan without leaving the purchase button', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      const live = subscription('pro', 'active');
      expect(policy.resolveOneTimePlanAction(live)).assertEqual('purchase');
      expect(policy.resolveOneTimePlanAction(subscription('pro', 'grace_period')))
        .assertEqual('purchase');
      expect(policy.resolveOneTimePlanAction(subscription('pro', 'unknown')))
        .assertEqual('purchase');
    });

    it('opens the permanent purchase once auto-renewal is cancelled', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      // Cancelled keeps the paid period alive, but the store no longer renews it,
      // so the permanent plan is exactly what the user should be sold.
      expect(policy.resolveOneTimePlanAction(subscription('pro', 'cancelled'))).assertEqual('purchase');
      expect(policy.resolveOneTimePlanAction(subscription('pro', 'expired'))).assertEqual('purchase');
    });

    it('keeps a long-term member from buying anything again', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      const permanent = membership('pro', 0);
      expect(policy.resolveOneTimePlanAction(permanent)).assertEqual('unavailable');
      expect(policy.resolveSubscriptionPlanAction(permanent)).assertEqual('unavailable');
    });

    it('offers the subscription plans only while no store subscription is live', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      expect(policy.resolveSubscriptionPlanAction(membership('pro', NOW + THIRTY_DAYS_MS)))
        .assertEqual('purchase');
      expect(policy.resolveSubscriptionPlanAction(subscription('pro', 'active'))).assertEqual('unavailable');
      expect(policy.resolveSubscriptionPlanAction(subscription('pro', 'cancelled'))).assertEqual('unavailable');
      expect(policy.resolveSubscriptionPlanAction(membership('guest', 0))).assertEqual('purchase');
    });

    it('blocks every purchase inside a private session', 0, () => {
      const policy = new AiraProPurchasePolicyService();
      const guest = membership('guest', 0);
      expect(policy.resolveOneTimePlanAction(guest, 'privacy_restricted')).assertEqual('unavailable');
      expect(policy.resolveSubscriptionPlanAction(guest, 'privacy_restricted')).assertEqual('unavailable');
    });
  });
}

function membership(plan: 'guest' | 'pro', planExpiresAt: number): AiraMembershipState {
  const state = buildDefaultMembershipState(NOW);
  state.plan = plan;
  state.planExpiresAt = planExpiresAt;
  return state;
}

function subscription(plan: 'guest' | 'pro', status: AiraSubscriptionStatus): AiraMembershipState {
  const state = membership(plan, NOW + THIRTY_DAYS_MS);
  state.subscriptionStatus = status;
  state.subscriptionProductId = AIRA_PRO_YEARLY_PRODUCT_ID;
  return state;
}
