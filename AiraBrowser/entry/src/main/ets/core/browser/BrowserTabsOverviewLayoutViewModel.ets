import { BrowserTabsOverviewLayoutStyle } from '../../common/models/BrowserModels';
import {
  AppWindowResponsiveFacts,
  AppWindowResponsiveLayoutService
} from '../../services/layout/AppWindowResponsiveLayoutService';
import {
  BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT,
  BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP
} from './BrowserTabsOverviewVisualTokens';

export interface BrowserTabsOverviewLayoutInput {
  gridWidth: number;
  sheetWidth: number;
  sheetHeight: number;
  layoutStyle?: BrowserTabsOverviewLayoutStyle | string;
}

export interface BrowserTabsOverviewLayoutState {
  layoutStyle: BrowserTabsOverviewLayoutStyle;
  columnCount: number;
  columnsTemplate: string;
  gridGap: number;
  cardWidth: number;
  previewHeight: number;
  identityHeaderHeight: number;
  identityPreviewGap: number;
  itemHeight: number;
  horizontalContentInset: number;
}

export function isSameTabsOverviewLayoutState(
  current: BrowserTabsOverviewLayoutState,
  next: BrowserTabsOverviewLayoutState
): boolean {
  return current.layoutStyle === next.layoutStyle &&
    current.columnCount === next.columnCount &&
    current.columnsTemplate === next.columnsTemplate &&
    current.gridGap === next.gridGap &&
    current.cardWidth === next.cardWidth &&
    current.previewHeight === next.previewHeight &&
    current.identityHeaderHeight === next.identityHeaderHeight &&
    current.identityPreviewGap === next.identityPreviewGap &&
    current.itemHeight === next.itemHeight &&
    current.horizontalContentInset === next.horizontalContentInset;
}

interface BrowserTabsOverviewLayoutFrame {
  width: number;
  height: number;
}

interface BrowserTabsOverviewLayoutBaseState {
  layoutStyle: BrowserTabsOverviewLayoutStyle;
  columnCount: number;
  columnsTemplate: string;
  gridGap: number;
  cardWidth: number;
  previewHeight: number;
  horizontalContentInset: number;
}

const TAB_OVERVIEW_LAYOUT_MIN_CARD_WIDTH: number = 132;
const TAB_OVERVIEW_LAYOUT_MIN_PREVIEW_HEIGHT: number = 118;
const TAB_OVERVIEW_LAYOUT_GRID_GAP: number = 16;
const TAB_OVERVIEW_LAYOUT_TOP_PADDING: number = 16;
const TAB_OVERVIEW_LAYOUT_TOP_SAFE_GAP: number = 10;
/**
 * Zero gap for the stacked deck.
 *
 * Every card is placed by its own offset inside a `Stack`, so there is no stride left for a gap to
 * sit in. The value only reaches the selection-displacement camera now, where a card travels its
 * own width and nothing more.
 */
const TAB_OVERVIEW_STACK_GAP: number = 0;
/**
 * Gap between the large cards of the horizontal strip.
 */
const TAB_OVERVIEW_HORIZONTAL_CARDS_GAP: number = 18;
/**
 * Focused card width, over the usable width, for the stacked deck on a portrait window.
 *
 * Smaller than the flat strip's 0.82 because a deck spends width on the leading strip and on the
 * trailing neighbour instead of on the focused card alone. Kept at 0.70 so the nearest leading
 * strip, which peeks `cardWidth * 0.22` past the focused card's edge, stays on the sheet on the
 * narrowest phones.
 */
const TAB_OVERVIEW_STACK_PHONE_WIDTH_RATIO: number = 0.70;
const TAB_OVERVIEW_STACK_LANDSCAPE_WIDTH_RATIO: number = 0.56;
const TAB_OVERVIEW_STACK_MAX_WIDTH: number = 520;
const TAB_OVERVIEW_STACK_MIN_WIDTH: number = 200;
const TAB_OVERVIEW_STACK_VIEWPORT_HEIGHT_RATIO: number = 0.66;
const TAB_OVERVIEW_STACK_MIN_HEIGHT: number = 180;
/**
 * Portrait width ratio of one large card in the horizontal strip.
 *
 * 0.82 leaves the neighbouring card a sliver of the sheet, which is what makes the strip read as
 * "swipe sideways for the next card" instead of "one card fills the screen".
 */
const TAB_OVERVIEW_HORIZONTAL_CARDS_PHONE_WIDTH_RATIO: number = 0.82;
const TAB_OVERVIEW_HORIZONTAL_CARDS_LANDSCAPE_WIDTH_RATIO: number = 0.56;
const TAB_OVERVIEW_HORIZONTAL_CARDS_MAX_WIDTH: number = 520;
const TAB_OVERVIEW_HORIZONTAL_CARDS_MIN_WIDTH: number = 220;
const TAB_OVERVIEW_HORIZONTAL_CARDS_VIEWPORT_HEIGHT_RATIO: number = 0.66;
const TAB_OVERVIEW_HORIZONTAL_CARDS_MIN_HEIGHT: number = 180;

export class BrowserTabsOverviewLayoutViewModel {
  private readonly responsiveLayoutService: AppWindowResponsiveLayoutService =
    new AppWindowResponsiveLayoutService();

  buildState(input: BrowserTabsOverviewLayoutInput): BrowserTabsOverviewLayoutState {
    const layoutStyle = this.normalizeLayoutStyle(input.layoutStyle);
    const usableWidth = this.resolveUsableWidth(input);
    if (layoutStyle === 'horizontal_cards') {
      return this.buildHorizontalCardsState(input, usableWidth);
    }
    if (layoutStyle === 'stack') {
      return this.buildStackState(input, usableWidth);
    }
    const responsiveFacts = this.resolveResponsiveFacts(input);
    const columnCount = this.resolveColumnCount(responsiveFacts);
    const cardWidth = this.resolveCardWidth(usableWidth, columnCount);
    const previewHeight = this.resolvePreviewHeight(input, cardWidth);
    return this.buildLayoutState({
      layoutStyle: 'grid',
      columnCount: columnCount,
      columnsTemplate: this.buildColumnsTemplate(columnCount),
      gridGap: TAB_OVERVIEW_LAYOUT_GRID_GAP,
      cardWidth: cardWidth,
      previewHeight: previewHeight,
      horizontalContentInset: 0
    });
  }

  /**
   * The large centred card strip.
   *
   * One card per page, centred by an equal inset on either edge so the first and the last card can
   * both rest in the middle of the sheet.
   */
  private buildHorizontalCardsState(
    input: BrowserTabsOverviewLayoutInput,
    usableWidth: number
  ): BrowserTabsOverviewLayoutState {
    const maxWidth = this.resolveHorizontalCardWidth(input, usableWidth);
    const maxHeight = this.resolveHorizontalPreviewHeight(input);
    // The shared box keeps the page's own aspect. Two independent ratios make a wider card than
    // the screenshot, and the picture then sits inside it with a white border.
    const frame = this.resolveViewportAspectFrame(input.sheetWidth, input.sheetHeight, maxWidth, maxHeight);
    return this.buildLayoutState({
      layoutStyle: 'horizontal_cards',
      columnCount: 1,
      columnsTemplate: '1fr',
      gridGap: TAB_OVERVIEW_HORIZONTAL_CARDS_GAP,
      cardWidth: frame.width,
      previewHeight: frame.height,
      horizontalContentInset: Math.max(0, (usableWidth - frame.width) / 2)
    });
  }

  /**
   * The stacked deck.
   *
   * Every card is placed by its own offset inside a `Stack`, so the state only carries the focused
   * card's width and the preview height the deck scales from.
   */
  private buildStackState(
    input: BrowserTabsOverviewLayoutInput,
    usableWidth: number
  ): BrowserTabsOverviewLayoutState {
    const cardWidth = this.resolveStackCardWidth(input, usableWidth);
    return this.buildLayoutState({
      layoutStyle: 'stack',
      columnCount: 1,
      columnsTemplate: '1fr',
      gridGap: TAB_OVERVIEW_STACK_GAP,
      cardWidth: cardWidth,
      previewHeight: this.resolveStackPreviewHeight(input),
      horizontalContentInset: 0
    });
  }

  private buildLayoutState(base: BrowserTabsOverviewLayoutBaseState): BrowserTabsOverviewLayoutState {
    return {
      layoutStyle: base.layoutStyle,
      columnCount: base.columnCount,
      columnsTemplate: base.columnsTemplate,
      gridGap: base.gridGap,
      cardWidth: base.cardWidth,
      previewHeight: base.previewHeight,
      identityHeaderHeight: BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT,
      identityPreviewGap: BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP,
      itemHeight: base.previewHeight + BROWSER_TABS_OVERVIEW_IDENTITY_HEADER_HEIGHT +
        BROWSER_TABS_OVERVIEW_IDENTITY_PREVIEW_GAP,
      horizontalContentInset: base.horizontalContentInset
    };
  }

  resolveTopPadding(topSafeInsetVp: number): number {
    return Math.max(TAB_OVERVIEW_LAYOUT_TOP_PADDING, topSafeInsetVp + TAB_OVERVIEW_LAYOUT_TOP_SAFE_GAP);
  }

  private resolveColumnCount(facts: AppWindowResponsiveFacts): number {
    if (facts.orientation === 'landscape' &&
      this.responsiveLayoutService.isAtLeastWidthClass(facts.widthClass, 'md')) {
      return 3;
    }
    if (this.responsiveLayoutService.isAtLeastWidthClass(facts.widthClass, 'lg')) {
      return 4;
    }
    return 2;
  }

  private resolveUsableWidth(input: BrowserTabsOverviewLayoutInput): number {
    if (input.gridWidth > 0) {
      return input.gridWidth;
    }
    return Math.max(1, input.sheetWidth - 32);
  }

  private resolveCardWidth(usableWidth: number, columnCount: number): number {
    const safeColumnCount = Math.max(1, columnCount);
    const totalGap = TAB_OVERVIEW_LAYOUT_GRID_GAP * Math.max(0, safeColumnCount - 1);
    return Math.max(TAB_OVERVIEW_LAYOUT_MIN_CARD_WIDTH, (Math.max(1, usableWidth) - totalGap) / safeColumnCount);
  }

  private resolvePreviewHeight(input: BrowserTabsOverviewLayoutInput, cardWidth: number): number {
    const pageWidth = Math.max(1, input.sheetWidth);
    const pageHeight = Math.max(1, input.sheetHeight);
    // Same proportion as the page, only smaller. A shorter card crops the bottom, and scaling the
    // page onto that card is what flattens it.
    return Math.max(
      TAB_OVERVIEW_LAYOUT_MIN_PREVIEW_HEIGHT,
      Math.round(cardWidth * pageHeight / pageWidth)
    );
  }

  private resolveHorizontalCardWidth(input: BrowserTabsOverviewLayoutInput, usableWidth: number): number {
    const landscape = input.sheetWidth > input.sheetHeight;
    const ratio = landscape ?
      TAB_OVERVIEW_HORIZONTAL_CARDS_LANDSCAPE_WIDTH_RATIO :
      TAB_OVERVIEW_HORIZONTAL_CARDS_PHONE_WIDTH_RATIO;
    return Math.round(Math.max(
      TAB_OVERVIEW_HORIZONTAL_CARDS_MIN_WIDTH,
      Math.min(TAB_OVERVIEW_HORIZONTAL_CARDS_MAX_WIDTH, Math.max(1, usableWidth) * ratio)
    ));
  }

  private resolveHorizontalPreviewHeight(input: BrowserTabsOverviewLayoutInput): number {
    return Math.round(Math.max(
      TAB_OVERVIEW_HORIZONTAL_CARDS_MIN_HEIGHT,
      Math.max(1, input.sheetHeight) * TAB_OVERVIEW_HORIZONTAL_CARDS_VIEWPORT_HEIGHT_RATIO
    ));
  }

  private resolveViewportAspectFrame(
    pageWidth: number,
    pageHeight: number,
    maxWidth: number,
    maxHeight: number
  ): BrowserTabsOverviewLayoutFrame {
    const safePageWidth = Math.max(1, pageWidth);
    const safePageHeight = Math.max(1, pageHeight);
    const scale = Math.min(
      Math.max(1, maxWidth) / safePageWidth,
      Math.max(1, maxHeight) / safePageHeight
    );
    return {
      width: Math.max(1, Math.round(safePageWidth * scale)),
      height: Math.max(1, Math.round(safePageHeight * scale))
    };
  }

  private resolveStackCardWidth(input: BrowserTabsOverviewLayoutInput, usableWidth: number): number {
    const landscape = input.sheetWidth > input.sheetHeight;
    const ratio = landscape ?
      TAB_OVERVIEW_STACK_LANDSCAPE_WIDTH_RATIO :
      TAB_OVERVIEW_STACK_PHONE_WIDTH_RATIO;
    return Math.round(Math.max(
      TAB_OVERVIEW_STACK_MIN_WIDTH,
      Math.min(TAB_OVERVIEW_STACK_MAX_WIDTH, Math.max(1, usableWidth) * ratio)
    ));
  }

  private resolveStackPreviewHeight(input: BrowserTabsOverviewLayoutInput): number {
    return Math.round(Math.max(
      TAB_OVERVIEW_STACK_MIN_HEIGHT,
      Math.max(1, input.sheetHeight) * TAB_OVERVIEW_STACK_VIEWPORT_HEIGHT_RATIO
    ));
  }

  private normalizeLayoutStyle(
    style: BrowserTabsOverviewLayoutStyle | string | undefined
  ): BrowserTabsOverviewLayoutStyle {
    // Each of the three styles is its own value; anything else is the default, 卡片平铺.
    return style === 'horizontal_cards' || style === 'stack' ? style : 'grid';
  }

  private buildColumnsTemplate(columnCount: number): string {
    const columns: string[] = [];
    for (let index = 0; index < Math.max(1, columnCount); index += 1) {
      columns.push('1fr');
    }
    return columns.join(' ');
  }

  private resolveResponsiveFacts(input: BrowserTabsOverviewLayoutInput): AppWindowResponsiveFacts {
    return this.responsiveLayoutService.resolve({
      viewportWidth: input.sheetWidth,
      viewportHeight: input.sheetHeight
    });
  }
}
