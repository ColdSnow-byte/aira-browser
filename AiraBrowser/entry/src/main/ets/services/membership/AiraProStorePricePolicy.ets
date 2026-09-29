/**
 * Turns a live Huawei store price into the membership card's price lines.
 * The catalog price is only the fallback. A console price change, including one
 * that starts and ends on its own, shows up the next time the store is queried.
 * No second release is required to put the price back.
 */
export interface AiraProLifetimePricePresentation {
  amountText: string;
  displayPrice: string;
  originalPriceText: string;
  /** Empty outside the National Day window. */
  discountBadgeText: string;
  /** Empty outside the National Day window; callers keep the catalog description. */
  descriptionText: string;
}

const PRICE_MATCH_EPSILON: number = 0.001;
const CHINA_STANDARD_OFFSET_MS: number = 8 * 60 * 60 * 1000;
/**
 * Huawei documents `localPrice` as the original price during a temporary price
 * adjustment, so the Oct 1–7 sale is not guaranteed to arrive on that field.
 * The window itself switches the card, then puts it back, without another release.
 * China Standard Time, inclusive of Oct 7 and exclusive of Oct 8 00:00.
 */
const NATIONAL_DAY_WINDOW_START_MS: number = Date.UTC(2026, 9, 1, 0, 0, 0) - CHINA_STANDARD_OFFSET_MS;
const NATIONAL_DAY_WINDOW_END_MS: number = Date.UTC(2026, 9, 8, 0, 0, 0) - CHINA_STANDARD_OFFSET_MS;
const NATIONAL_DAY_LIFETIME_PRICE: number = 48;
const NATIONAL_DAY_BADGE_TEXT: string = '7折';
const NATIONAL_DAY_DESCRIPTION_TEXT: string = '国庆特惠，10月7日前';
let cachedLifetimeStorePriceText: string = '';

export function readCachedAiraProLifetimeStorePrice(): string {
  return cachedLifetimeStorePriceText;
}

export function rememberAiraProLifetimeStorePrice(priceText: string): void {
  cachedLifetimeStorePriceText = priceText.trim();
}

export function resolveAiraProLifetimePricePresentation(
  livePriceText: string,
  catalogAmountText: string,
  catalogPeriodText: string,
  catalogDisplayPrice: string,
  catalogOriginalPriceText: string,
  nowMs: number
): AiraProLifetimePricePresentation {
  const catalog: AiraProLifetimePricePresentation = {
    amountText: catalogAmountText,
    displayPrice: catalogDisplayPrice,
    originalPriceText: catalogOriginalPriceText,
    discountBadgeText: '',
    descriptionText: ''
  };
  const inWindow = isAiraProNationalDayOfferWindow(nowMs) && !isForeignCurrencyPriceText(livePriceText);
  const livePresentation = resolveDifferentCnyPrice(
    livePriceText,
    catalogAmountText,
    catalogPeriodText,
    inWindow
  );
  if (livePresentation !== undefined) {
    return livePresentation;
  }
  if (inWindow) {
    return buildDiscountedPresentation(
      NATIONAL_DAY_LIFETIME_PRICE,
      catalogAmountText,
      catalogPeriodText,
      true
    );
  }
  return catalog;
}

export function isAiraProNationalDayOfferWindow(nowMs: number): boolean {
  return nowMs >= NATIONAL_DAY_WINDOW_START_MS && nowMs < NATIONAL_DAY_WINDOW_END_MS;
}

export function shouldPresentAiraProNationalDayOffer(
  nowMs: number,
  alreadyShown: boolean,
  lifetimeMember: boolean,
  purchaseAvailable: boolean
): boolean {
  return purchaseAvailable &&
    !alreadyShown &&
    !lifetimeMember &&
    isAiraProNationalDayOfferWindow(nowMs);
}

function resolveDifferentCnyPrice(
  livePriceText: string,
  catalogAmountText: string,
  catalogPeriodText: string,
  promoCopy: boolean
): AiraProLifetimePricePresentation | undefined {
  if (!isCnyPriceText(livePriceText)) {
    return undefined;
  }
  const liveAmount = parsePositiveAmount(livePriceText);
  const catalogAmount = parsePositiveAmount(catalogAmountText);
  if (liveAmount === undefined || catalogAmount === undefined) {
    return undefined;
  }
  if (Math.abs(liveAmount - catalogAmount) < PRICE_MATCH_EPSILON) {
    return undefined;
  }
  if (liveAmount < catalogAmount) {
    return buildDiscountedPresentation(liveAmount, catalogAmountText, catalogPeriodText, promoCopy);
  }
  const amountText = formatCnyAmount(liveAmount);
  return {
    amountText: amountText,
    displayPrice: joinPrice(amountText, catalogPeriodText),
    originalPriceText: '',
    discountBadgeText: '',
    descriptionText: ''
  };
}

function buildDiscountedPresentation(
  amount: number,
  catalogAmountText: string,
  catalogPeriodText: string,
  promoCopy: boolean
): AiraProLifetimePricePresentation {
  const amountText = formatCnyAmount(amount);
  return {
    amountText: amountText,
    displayPrice: joinPrice(amountText, catalogPeriodText),
    originalPriceText: `原价${catalogAmountText}`,
    discountBadgeText: promoCopy ? NATIONAL_DAY_BADGE_TEXT : '',
    descriptionText: promoCopy ? NATIONAL_DAY_DESCRIPTION_TEXT : ''
  };
}

function joinPrice(amountText: string, periodText: string): string {
  return periodText.length > 0 ? `${amountText} ${periodText}` : amountText;
}

function isForeignCurrencyPriceText(text: string): boolean {
  if (isCnyPriceText(text)) {
    return false;
  }
  const upper = text.toUpperCase();
  return upper.indexOf('HKD') >= 0 ||
    upper.indexOf('HK$') >= 0 ||
    upper.indexOf('USD') >= 0 ||
    upper.indexOf('EUR') >= 0 ||
    text.indexOf('$') >= 0;
}

function isCnyPriceText(text: string): boolean {
  const upper = text.toUpperCase();
  if (upper.indexOf('HKD') >= 0 || upper.indexOf('HK$') >= 0) {
    return false;
  }
  return text.indexOf('¥') >= 0 ||
    text.indexOf('￥') >= 0 ||
    upper.indexOf('CNY') >= 0 ||
    upper.indexOf('RMB') >= 0;
}

function parsePositiveAmount(text: string): number | undefined {
  let digits = '';
  let started = false;
  let sawDot = false;
  for (let index = 0; index < text.length; index++) {
    const character = text.charAt(index);
    const isDigit = character >= '0' && character <= '9';
    if (isDigit) {
      digits += character;
      started = true;
      continue;
    }
    if (character === '.' && started && !sawDot) {
      digits += character;
      sawDot = true;
      continue;
    }
    if (started) {
      break;
    }
  }
  if (digits.length === 0 || digits === '.') {
    return undefined;
  }
  const value = Number(digits);
  if (value !== value || !(value > 0)) {
    return undefined;
  }
  return value;
}

function formatCnyAmount(value: number): string {
  const cents = Math.round(value * 100);
  const whole = Math.floor(cents / 100);
  const fraction = cents % 100;
  if (fraction === 0) {
    return `¥${whole}`;
  }
  if (fraction % 10 === 0) {
    return `¥${whole}.${Math.floor(fraction / 10)}`;
  }
  const fractionText = fraction < 10 ? `0${fraction}` : `${fraction}`;
  return `¥${whole}.${fractionText}`;
}
