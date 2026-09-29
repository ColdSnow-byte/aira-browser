import { describe, expect, it } from '@ohos/hypium';
import { AIRA_PRO_ONE_TIME_PLAN } from '../main/ets/services/membership/HuaweiIapProductCatalog';
import {
  readCachedAiraProLifetimeStorePrice,
  rememberAiraProLifetimeStorePrice,
  resolveAiraProLifetimePricePresentation,
  shouldPresentAiraProNationalDayOffer
} from '../main/ets/services/membership/AiraProStorePricePolicy';

const BEFORE_WINDOW_MS: number = Date.UTC(2026, 8, 29, 4, 0, 0);
const DURING_WINDOW_MS: number = Date.UTC(2026, 9, 3, 4, 0, 0);
const LAST_WINDOW_MS: number = Date.UTC(2026, 9, 7, 15, 59, 0);
const AFTER_WINDOW_MS: number = Date.UTC(2026, 9, 7, 16, 0, 0);

function present(livePriceText: string, nowMs: number = BEFORE_WINDOW_MS): {
  amountText: string;
  displayPrice: string;
  originalPriceText: string;
} {
  return resolveAiraProLifetimePricePresentation(
    livePriceText,
    AIRA_PRO_ONE_TIME_PLAN.amountText,
    AIRA_PRO_ONE_TIME_PLAN.periodText,
    AIRA_PRO_ONE_TIME_PLAN.displayPrice,
    AIRA_PRO_ONE_TIME_PLAN.originalPriceText,
    nowMs
  );
}

export default function airaProStorePricePolicyTest(): void {
  describe('Aira Pro lifetime store price', () => {
    it('keeps the catalog price until Huawei returns a different CNY price', 0, () => {
      const missing = present('');
      expect(missing.amountText).assertEqual('¥68.8');
      expect(missing.displayPrice).assertEqual('¥68.8 长期');
      expect(missing.originalPriceText).assertEqual('原价¥98.8');

      const unchanged = present('¥68.80');
      expect(unchanged.amountText).assertEqual('¥68.8');
      expect(unchanged.originalPriceText).assertEqual('原价¥98.8');
    });

    it('shows a lower store price and strikes through the catalog price', 0, () => {
      const promo = present('¥48.00');
      expect(promo.amountText).assertEqual('¥48');
      expect(promo.displayPrice).assertEqual('¥48 长期');
      expect(promo.originalPriceText).assertEqual('原价¥68.8');

      const cny = present('CNY 48.00');
      expect(cny.amountText).assertEqual('¥48');
      expect(cny.originalPriceText).assertEqual('原价¥68.8');
    });

    it('does not treat another currency as the China price', 0, () => {
      const hongKong = present('HK$128.00');
      expect(hongKong.amountText).assertEqual('¥68.8');
      expect(hongKong.originalPriceText).assertEqual('原价¥98.8');
      const hongKongDuringWindow = present('HK$128.00', DURING_WINDOW_MS);
      expect(hongKongDuringWindow.amountText).assertEqual('¥68.8');
    });

    it('shows the National Day price even when Huawei still returns the original price', 0, () => {
      const during = present('¥68.80', DURING_WINDOW_MS);
      expect(during.amountText).assertEqual('¥48');
      expect(during.displayPrice).assertEqual('¥48 长期');
      expect(during.originalPriceText).assertEqual('原价¥68.8');

      const lastHour = present('', LAST_WINDOW_MS);
      expect(lastHour.amountText).assertEqual('¥48');
      expect(lastHour.discountBadgeText).assertEqual('7折');
      expect(lastHour.descriptionText).assertEqual('国庆特惠，10月7日前');
      expect(lastHour.originalPriceText).assertEqual('原价¥68.8');

      const after = present('¥68.80', AFTER_WINDOW_MS);
      expect(after.amountText).assertEqual('¥68.8');
      expect(after.originalPriceText).assertEqual('原价¥98.8');
      expect(after.discountBadgeText).assertEqual('');
    });

    it('offers the National Day purchase notice once, and not to a lifetime member', 0, () => {
      expect(shouldPresentAiraProNationalDayOffer(DURING_WINDOW_MS, false, false, true)).assertTrue();
      expect(shouldPresentAiraProNationalDayOffer(DURING_WINDOW_MS, true, false, true)).assertFalse();
      expect(shouldPresentAiraProNationalDayOffer(DURING_WINDOW_MS, false, true, true)).assertFalse();
      expect(shouldPresentAiraProNationalDayOffer(DURING_WINDOW_MS, false, false, false)).assertFalse();
      expect(shouldPresentAiraProNationalDayOffer(BEFORE_WINDOW_MS, false, false, true)).assertFalse();
    });

    it('drops the struck-through list price when the store price is higher', 0, () => {
      const raised = present('¥80.00');
      expect(raised.amountText).assertEqual('¥80');
      expect(raised.displayPrice).assertEqual('¥80 长期');
      expect(raised.originalPriceText).assertEqual('');
    });

    it('remembers the last store price for the next screen in this process', 0, () => {
      rememberAiraProLifetimeStorePrice(' ¥48.00 ');
      expect(readCachedAiraProLifetimeStorePrice()).assertEqual('¥48.00');
      rememberAiraProLifetimeStorePrice('¥68.80');
      expect(readCachedAiraProLifetimeStorePrice()).assertEqual('¥68.80');
      rememberAiraProLifetimeStorePrice('');
    });
  });
}
