export type AiraProMembershipRedeemGrantKind = 'month' | 'year' | 'lifetime';

export interface AiraProMembershipRedeemResultState {
  valueText: string;
  unitText: string;
  caption: string;
  actionText: string;
}

/**
 * Membership redeem codes are 8 characters from a 32-symbol alphabet, shown as
 * XXXX-XXXX. 0/O and 1/I are omitted so a code can be read aloud. The last
 * character is a checksum; the grant kind is not encoded in the code.
 */
const AIRA_MEMBERSHIP_REDEEM_CODE_ALPHABET: string = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH: number = 8;
const AIRA_MEMBERSHIP_REDEEM_CODE_BODY_LENGTH: number = 7;
export const AIRA_MEMBERSHIP_REDEEM_CODE_GROUP_LENGTH: number = 4;
export const AIRA_MEMBERSHIP_REDEEM_CODE_PLACEHOLDER: string = 'XXXX-XXXX';

export function normalizeMembershipRedeemCode(code: string): string {
  const upper = code.toUpperCase();
  let normalized = '';
  for (let index = 0; index < upper.length; index++) {
    const symbol = upper.charAt(index);
    if (AIRA_MEMBERSHIP_REDEEM_CODE_ALPHABET.indexOf(symbol) < 0) {
      continue;
    }
    normalized += symbol;
    if (normalized.length >= AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH) {
      break;
    }
  }
  return normalized;
}

export function formatMembershipRedeemCode(code: string): string {
  const normalized = normalizeMembershipRedeemCode(code);
  let formatted = '';
  for (let index = 0; index < normalized.length; index++) {
    if (index > 0 && index % AIRA_MEMBERSHIP_REDEEM_CODE_GROUP_LENGTH === 0) {
      formatted += '-';
    }
    formatted += normalized.charAt(index);
  }
  return formatted;
}

export function isValidMembershipRedeemCode(code: string): boolean {
  const normalized = normalizeMembershipRedeemCode(code);
  if (normalized.length !== AIRA_MEMBERSHIP_REDEEM_CODE_LENGTH) {
    return false;
  }
  let sum = 0;
  for (let index = 0; index < AIRA_MEMBERSHIP_REDEEM_CODE_BODY_LENGTH; index++) {
    sum += (index + 1) * AIRA_MEMBERSHIP_REDEEM_CODE_ALPHABET.indexOf(normalized.charAt(index));
  }
  const expected = AIRA_MEMBERSHIP_REDEEM_CODE_ALPHABET.charAt(sum % AIRA_MEMBERSHIP_REDEEM_CODE_ALPHABET.length);
  return normalized.charAt(AIRA_MEMBERSHIP_REDEEM_CODE_BODY_LENGTH) === expected;
}

export function resolveAiraProMembershipRedeemResult(
  kind: AiraProMembershipRedeemGrantKind
): AiraProMembershipRedeemResultState {
  if (kind === 'year') {
    return {
      valueText: '1',
      unitText: '年',
      caption: '已兑换一年会员',
      actionText: '知道了'
    };
  }
  if (kind === 'lifetime') {
    return {
      valueText: '永久',
      unitText: '',
      caption: '已兑换长期会员',
      actionText: '知道了'
    };
  }
  return {
    valueText: '1',
    unitText: '个月',
    caption: '已兑换一个月会员',
    actionText: '知道了'
  };
}
