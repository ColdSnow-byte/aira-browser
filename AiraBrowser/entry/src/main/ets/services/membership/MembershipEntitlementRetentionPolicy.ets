import { AiraMembershipState } from '../../common/models/MembershipModels';

export interface MembershipAccountPresence {
  cloudUid: string;
  spaceUid: string;
  resolvedUid: string;
}

/**
 * Pro features all talk to the Aira server, so the local record is not an
 * offline unlock. It is the last answer the server already gave. A missed
 * refresh, a blank uid, or a cloud/space uid flip must not replace that answer.
 * Sign-out clears the stored state itself. A successful membership response is
 * the only other writer allowed to leave Pro.
 */
export class MembershipEntitlementRetentionPolicy {
  retainQueryUid(
    stored: AiraMembershipState,
    presence: MembershipAccountPresence,
    now: number
  ): string {
    const confirmedUid = stored.userId.trim();
    if (!this.isOpenPro(stored, now) || confirmedUid.length <= 0 || confirmedUid === 'local') {
      return presence.resolvedUid;
    }
    if (confirmedUid === presence.cloudUid || confirmedUid === presence.spaceUid) {
      return confirmedUid;
    }
    return presence.resolvedUid;
  }

  allowsUnconfirmedPersist(previous: AiraMembershipState, next: AiraMembershipState): boolean {
    return !(previous.plan === 'pro' && next.plan !== 'pro');
  }

  isOpenPro(state: AiraMembershipState, now: number): boolean {
    if (state.plan !== 'pro') {
      return false;
    }
    return state.planExpiresAt === 0 || state.planExpiresAt > now;
  }
}
