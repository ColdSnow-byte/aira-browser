import { describe, expect, it } from '@ohos/hypium';
import {
  AiraMembershipState,
  buildDefaultMembershipState
} from '../main/ets/common/models/MembershipModels';
import {
  MembershipAccountPresence,
  MembershipEntitlementRetentionPolicy
} from '../main/ets/services/membership/MembershipEntitlementRetentionPolicy';

const NOW: number = Date.UTC(2026, 8, 27);

export default function membershipEntitlementRetentionPolicyTest(): void {
  describe('Membership entitlement retention', () => {
    it('keeps asking the account that already holds long-term Pro when cloud and space disagree', 0, () => {
      const policy = new MembershipEntitlementRetentionPolicy();
      const stored = proState('lifetime-user', 0);
      const presence = accounts('cloud-user', 'lifetime-user', 'cloud-user');
      expect(policy.retainQueryUid(stored, presence, NOW)).assertEqual('lifetime-user');
    });

    it('follows the signed-in account once the confirmed Pro account is gone', 0, () => {
      const policy = new MembershipEntitlementRetentionPolicy();
      const stored = proState('lifetime-user', 0);
      const presence = accounts('other-user', 'other-user', 'other-user');
      expect(policy.retainQueryUid(stored, presence, NOW)).assertEqual('other-user');
    });

    it('does not keep a timed grant past the instant the server already reported', 0, () => {
      const policy = new MembershipEntitlementRetentionPolicy();
      const stored = proState('subscriber', NOW - 1000);
      const presence = accounts('cloud-user', 'subscriber', 'cloud-user');
      expect(policy.retainQueryUid(stored, presence, NOW)).assertEqual('cloud-user');
    });

    it('refuses to persist a Pro downgrade before the membership service answers', 0, () => {
      const policy = new MembershipEntitlementRetentionPolicy();
      const previous = proState('lifetime-user', 0);
      const club = buildDefaultMembershipState(NOW);
      club.userId = 'lifetime-user';
      club.plan = 'club';
      const guest = buildDefaultMembershipState(NOW);
      expect(policy.allowsUnconfirmedPersist(previous, club)).assertFalse();
      expect(policy.allowsUnconfirmedPersist(previous, guest)).assertFalse();
    });

    it('still persists a confirmed upgrade and a Pro field update', 0, () => {
      const policy = new MembershipEntitlementRetentionPolicy();
      const club = buildDefaultMembershipState(NOW);
      club.userId = 'lifetime-user';
      club.plan = 'club';
      const pro = proState('lifetime-user', 0);
      const renamed = proState('lifetime-user', 0);
      renamed.subscriptionProductId = 'aira_pro_lifetime';
      expect(policy.allowsUnconfirmedPersist(club, pro)).assertTrue();
      expect(policy.allowsUnconfirmedPersist(pro, renamed)).assertTrue();
    });
  });
}

function proState(userId: string, planExpiresAt: number): AiraMembershipState {
  const state = buildDefaultMembershipState(NOW);
  state.userId = userId;
  state.plan = 'pro';
  state.planExpiresAt = planExpiresAt;
  state.accessFlags = ['club'];
  return state;
}

function accounts(cloudUid: string, spaceUid: string, resolvedUid: string): MembershipAccountPresence {
  return {
    cloudUid: cloudUid,
    spaceUid: spaceUid,
    resolvedUid: resolvedUid
  };
}
