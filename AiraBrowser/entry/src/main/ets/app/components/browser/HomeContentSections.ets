import {
  createDefaultHomeContentSectionsPresentationState,
  HomeContentSectionsPresentationState,
  HomeContentThemePresentationState,
  HomeShortcutPresentationState,
  createDefaultHomeContentThemePresentationState
} from '../../../core/browser/HomeContentPresentationState';
import { ExternalAppSearchTargetId, SearchSuggestion } from '../../../common/models/BrowserModels';
import { HomeShortcutUserAction } from '../../../features/newtab/HomeShortcutTypes';
import { HomeShortcutViewModel } from '../../../features/newtab/HomeShortcutViewModel';
import { BrowserRecentlyClosedUserAction } from '../../../core/browser/BrowserRecentlyClosedApplicationCoordinator';
import { BrowserTabHomeContentAction } from '../../../core/browser/BrowserTabHomeCoordinator';
import { SPLIT_TOOLBAR_ADDRESS_HORIZONTAL_MARGIN_VP } from '../../../core/browser/BrowserToolbarChromeStylePolicy';
import {
  CenteredHomeFrame,
  CENTERED_HOME_WORDMARK_HEIGHT,
  resolveCenteredHomeFrame,
  shouldCenterCenteredHomePartialRows
} from '../../../features/newtab/CenteredHomeShortcutLayoutPolicy';
import { CenteredHomeHeader } from './CenteredHomeHeader';
import { HomeFavoritesSection } from './HomeFavoritesSection';
import { HomeRecentlyClosedSection } from './HomeRecentlyClosedSection';
import { HomeSettingsActionRow } from './HomeSettingsActionRow';
import {
  HOME_PAGE_PRESENTATION_SHOW_FAVORITES_TITLE_KEY,
  HOME_PAGE_PRESENTATION_SHOW_RECENTLY_CLOSED_TITLE_KEY,
  HOME_PAGE_PRESENTATION_SHOW_SETTINGS_BUTTON_KEY,
  HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY
} from '../../../common/constants/HomePagePresentationStorageKeys';
import {
  HOME_LOGO_SCALE_DEFAULT_RATIO,
  resolveHomeLogoHeightVp
} from '../../../core/settings/HomeLogoSettingsPolicy';

const HOME_SECTION_CONTENT_INSET: number = 10;

@Component
export struct HomeContentSections {
  private homeContentScroller: Scroller = new Scroller();
  private homeShortcutViewModel: HomeShortcutViewModel = new HomeShortcutViewModel();
  @StorageProp(HOME_PAGE_PRESENTATION_SHOW_FAVORITES_TITLE_KEY)
  private storedShowFavoritesTitle: boolean = true;
  @StorageProp(HOME_PAGE_PRESENTATION_SHOW_RECENTLY_CLOSED_TITLE_KEY)
  private storedShowRecentlyClosedTitle: boolean = true;
  @StorageProp(HOME_PAGE_PRESENTATION_SHOW_SETTINGS_BUTTON_KEY)
  private storedShowSettingsButton: boolean = true;
  @StorageProp(HOME_PAGE_PRESENTATION_HOME_LOGO_SCALE_RATIO_KEY)
  private storedLogoScaleRatio: number = HOME_LOGO_SCALE_DEFAULT_RATIO;
  @Prop showShortcuts: boolean = true;
  @Prop centeredStyle: boolean = false;
  /** PC shell keeps the centered last-row growth. Touch shell packs that row left to right. */
  @Prop largeScreenShell: boolean = false;
  /** Centered shows the shortcut grid. Minimal keeps the same header and leaves this off. */
  @Prop centeredFavoritesVisible: boolean = true;
  /** Minimal drops the scan button inside the shared search field. */
  @Prop centeredScanButtonVisible: boolean = true;
  /** Minimal keeps the field, but its border is not the near-black primary text color. */
  @Prop softenCenteredSearchBorder: boolean = false;
  /** Minimal's field uses the same side inset as the search-page pill. */
  @Prop centeredSearchMatchesToolbar: boolean = false;
  /** Centered and minimal open homepage settings from the wordmark above the search field. */
  @Prop centeredWordmarkOpensSettings: boolean = false;
  @Prop centeredSearchPresented: boolean = false;
  /** False when the floating toolbar owns search, so this field does not run a shared-element flight. */
  @Prop centeredSearchGeometryEnabled: boolean = true;
  @Prop inlineSearch: boolean = false;
  @Prop inlineSearchActive: boolean = false;
  @Prop searchSuggestions: SearchSuggestion[] = [];
  @Prop searchDismissVersion: number = 0;
  @Prop centeredViewportHeight: number = 0;
  @Prop centeredTopSafeInset: number = 0;
  @Prop centeredBottomReserve: number = 0;
  @Prop shortcutIconCornerRadiusRatio: number = -1;
  @Prop recentlyClosedExpanded: boolean = true;
  @Prop presentation: HomeContentSectionsPresentationState =
    createDefaultHomeContentSectionsPresentationState();
  @Prop theme: HomeContentThemePresentationState = createDefaultHomeContentThemePresentationState();
  @Link contextMenuShortcutId: string;
  @State
  private shortcutDragActive: boolean = false;
  @State
  private favoritesExpanded: boolean = true;
  @State
  private centeredSurfaceHeight: number = 0;

  onAction: (action: BrowserTabHomeContentAction) => void = (_action: BrowserTabHomeContentAction) => {};
  onOpenSearch: () => void = () => {};
  onScan: () => void = () => {};
  onInlineSearchSession: (active: boolean, query: string) => void =
    (_active: boolean, _query: string) => {};
  onSubmitSearch: (query: string) => void = (_query: string) => {};
  onOpenSearchSuggestion: (suggestion: SearchSuggestion) => void =
    (_suggestion: SearchSuggestion) => {};
  onDeleteSearchSuggestion: (suggestion: SearchSuggestion) => void =
    (_suggestion: SearchSuggestion) => {};
  onClearSearchSuggestions: () => void = () => {};
  onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string) => void =
    (_targetId: ExternalAppSearchTargetId, _query: string) => {};
  onDismissInlineSearch: () => void = () => {};

  build() {
    if (this.centeredStyle) {
      this.buildCenteredHome()
    } else {
      this.buildClassicHome()
    }
  }

  @Builder
  private buildCenteredHome() {
    Column() {
      Column()
        .width('100%')
        .height(this.resolveCenteredFrame().headerTop)

      this.buildCenteredHeader()

      // Scroll defaults to Alignment.Center, which floats a short icon block in the middle.
      // Icons must pack from the top of this region and continue downward.
      Stack() {
        if (this.centeredFavoritesVisible) {
        Scroll(this.homeContentScroller) {
          Column({ space: this.presentation.sectionVerticalGap }) {
            this.buildFavoritesSection()
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Start)
          .padding({
            left: this.presentation.horizontalPadding,
            right: this.presentation.horizontalPadding,
            top: 4,
            bottom: 12
          })
        }
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
        .clip(true)
        .scrollBar(BarState.Off)
        .enableScrollInteraction(!this.shortcutDragActive && !this.inlineSearchActive)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onDidScroll((_scrollDelta: number, _scrollState: ScrollState) => {
          this.reportHomeScroll();
        })
        .onScrollStop(() => {
          this.onAction({ type: 'scroll_stop', scrollSource: 'system' });
        })
        }

        if (this.inlineSearch && this.inlineSearchActive) {
          Column()
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.Default)
            .onClick(() => {
              this.onDismissInlineSearch();
            })
        }
      }
      .layoutWeight(1)
      .width('100%')

      Column()
        .width('100%')
        .height(Math.max(0, this.centeredBottomReserve))
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.updateCenteredSurfaceHeight(newArea);
    })
  }

  @Builder
  private buildClassicHome() {
    Scroll(this.homeContentScroller) {
      Column({ space: this.presentation.sectionVerticalGap }) {
        this.buildFavoritesSection()
        if (this.presentation.showRecentlyClosed) {
          HomeRecentlyClosedSection({
            expanded: this.recentlyClosedExpanded,
            showTitle: this.storedShowRecentlyClosedTitle,
            contentWidth: this.resolveRecentlyClosedContentWidth(),
            minimumWidth: this.resolveSectionRailWidth(),
            alignPartialRowsToStart: this.presentation.useSharedSectionWidth,
            adaptColumnsToContentWidth: this.presentation.useSharedSectionWidth,
            recentlyClosed: this.presentation.recentlyClosed,
            displayLimit: this.presentation.recentlyClosed.limit,
            theme: this.theme,
            onAction: (action: BrowserRecentlyClosedUserAction) => {
              this.onAction({ type: 'recently_closed', recentlyClosedAction: action });
            },
            onRestoreRecord: (recordId: string) => {
              this.onAction({ type: 'restore_recently_closed', recordId: recordId });
            },
            onOpenHomeSettings: () => {
              this.onAction({ type: 'open_home_settings' });
            }
          })
        }
        this.buildSettingsRow()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(this.presentation.centerContentVertically ? FlexAlign.Center : FlexAlign.Start)
      .padding({
        left: this.presentation.horizontalPadding,
        right: this.presentation.horizontalPadding,
        top: this.presentation.contentTopPadding,
        bottom: this.presentation.bottomSpacerHeight
      })
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .scrollBar(BarState.Off)
    .enableScrollInteraction(!this.shortcutDragActive)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onDidScroll((_scrollDelta: number, _scrollState: ScrollState) => {
      this.onAction({
        type: 'scroll',
        scrollSource: 'system',
        scrollOffsetY: this.homeContentScroller.currentOffset().yOffset,
        scrollAtEnd: this.homeContentScroller.isAtEnd()
      });
    })
    .onScrollStop(() => {
      this.onAction({ type: 'scroll_stop', scrollSource: 'system' });
    })
  }

  @Builder
  private buildCenteredHeader() {
    Column() {
      CenteredHomeHeader({
        textColor: this.theme.primaryTextColor,
        secondaryTextColor: this.theme.secondaryTextColor,
        searchPresented: this.centeredSearchPresented,
        searchGeometryEnabled: this.centeredSearchGeometryEnabled,
        inlineSearch: this.inlineSearch,
        searchSuggestions: this.searchSuggestions,
        searchViewportHeight: this.centeredViewportHeight,
        searchPopupReservedTop: this.centeredTopSafeInset,
        searchDismissVersion: this.searchDismissVersion,
        onOpenSearch: () => {
          this.onOpenSearch();
        },
        showScanButton: this.centeredScanButtonVisible,
        softenSearchBorder: this.softenCenteredSearchBorder,
        searchSideInset: this.resolveCenteredSearchSideInset(),
        wordmarkOpensSettings: this.centeredWordmarkOpensSettings,
        onOpenSettings: () => {
          this.onAction({ type: 'open_home_settings' });
        },
        onScan: () => {
          this.onScan();
        },
        onInlineSearchSession: (active: boolean, query: string): void => {
          this.onInlineSearchSession(active, query);
        },
        onSubmitSearch: (query: string): void => {
          this.onSubmitSearch(query);
        },
        onOpenSuggestion: (suggestion: SearchSuggestion): void => {
          this.onOpenSearchSuggestion(suggestion);
        },
        onDeleteSuggestion: (suggestion: SearchSuggestion): void => {
          this.onDeleteSearchSuggestion(suggestion);
        },
        onClearSuggestions: (): void => {
          this.onClearSearchSuggestions();
        },
        onExternalSearch: (targetId: ExternalAppSearchTargetId, query: string): void => {
          this.onExternalSearch(targetId, query);
        }
      })
    }
    .width('100%')
    .zIndex(this.inlineSearch && this.inlineSearchActive ? 2 : 0)
    .clip(false)
    .padding({
      left: this.presentation.horizontalPadding,
      right: this.presentation.horizontalPadding
    })
  }

  @Builder
  private buildFavoritesSection() {
    if (this.showShortcuts && (!this.centeredStyle || this.centeredFavoritesVisible)) {
      HomeFavoritesSection({
        expanded: this.favoritesExpanded,
        showTitle: this.centeredStyle ? false : this.storedShowFavoritesTitle,
        iconCornerRadiusRatio: this.shortcutIconCornerRadiusRatio,
        minimumWidth: this.resolveSectionRailWidth(),
        alignPartialRowsToStart: !this.centeredStyle && this.presentation.useSharedSectionWidth,
        centerPartialRows: this.centeredStyle &&
          shouldCenterCenteredHomePartialRows(this.largeScreenShell),
        showPinnedSettingsEntry: false,
        shortcuts: this.resolveFavoritesShortcuts(),
        theme: this.theme,
        contextMenuShortcutId: $contextMenuShortcutId,
        shortcutDragActive: $shortcutDragActive,
        onToggle: () => {
          animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
            this.favoritesExpanded = !this.favoritesExpanded;
          });
        },
        onShortcutAction: (action: HomeShortcutUserAction) => {
          this.onAction({ type: 'shortcut', shortcutAction: action });
        },
        onOpenAddEntry: () => {
          this.onAction({ type: 'open_shortcut_picker' });
        },
        onOpenHomeSettings: () => {
          this.onAction({ type: 'open_home_settings' });
        }
      })
    }
  }

  @Builder
  private buildSettingsRow() {
    if (this.storedShowSettingsButton) {
      HomeSettingsActionRow({
        contentWidth: this.resolveSettingsRowWidth(),
        onOpenSettings: () => {
          this.onAction({ type: 'open_home_settings' });
        }
      })
    }
  }

  private resolveCenteredSearchSideInset(): number {
    if (!this.centeredSearchMatchesToolbar) {
      return 0;
    }
    return Math.max(0, SPLIT_TOOLBAR_ADDRESS_HORIZONTAL_MARGIN_VP - this.presentation.horizontalPadding);
  }

  private resolveCenteredSurfaceHeight(): number {
    return this.centeredSurfaceHeight > 0 ? this.centeredSurfaceHeight : Math.max(0, this.centeredViewportHeight);
  }

  private resolveCenteredFrame(): CenteredHomeFrame {
    return resolveCenteredHomeFrame({
      viewportHeight: this.resolveCenteredSurfaceHeight(),
      topSafeInset: this.centeredTopSafeInset,
      bottomChromeReserve: Math.max(0, this.centeredBottomReserve),
      // A larger logo grows the header block, and the frame keeps the search field centered.
      logoHeightVp: resolveHomeLogoHeightVp(CENTERED_HOME_WORDMARK_HEIGHT, this.storedLogoScaleRatio)
    });
  }

  private updateCenteredSurfaceHeight(area: Area): void {
    const height = Number(area.height);
    if (Number.isFinite(height) && height > 0 && height !== this.centeredSurfaceHeight) {
      this.centeredSurfaceHeight = height;
    }
  }

  private reportHomeScroll(): void {
    this.onAction({
      type: 'scroll',
      scrollSource: 'system',
      scrollOffsetY: this.homeContentScroller.currentOffset().yOffset,
      scrollAtEnd: this.homeContentScroller.isAtEnd()
    });
  }

  private resolveFavoritesShortcuts(): HomeShortcutPresentationState {
    return this.presentation.shortcuts;
  }

  private resolveFavoritesSectionWidth(): number {
    const shortcuts = this.resolveFavoritesShortcuts();
    const itemCount = shortcuts.shortcuts.length +
      (shortcuts.showAddEntry ? 1 : 0);
    const gridWidth = Math.max(1, shortcuts.gridWidth);
    const occupiedContentWidth = this.homeShortcutViewModel.getOccupiedGridContentWidth(
      itemCount,
      gridWidth,
      HOME_SECTION_CONTENT_INSET,
      shortcuts.metrics
    );
    return Math.min(gridWidth, occupiedContentWidth + HOME_SECTION_CONTENT_INSET * 2);
  }

  private resolveSectionRailWidth(): number {
    const favoritesWidth = this.resolveFavoritesSectionWidth();
    if (!this.presentation.useSharedSectionWidth) {
      return favoritesWidth;
    }
    return Math.max(1, this.presentation.shortcuts.gridWidth);
  }

  private resolveRecentlyClosedContentWidth(): number {
    if (this.presentation.useSharedSectionWidth) {
      return this.resolveSectionRailWidth();
    }
    return Math.max(1, this.presentation.shortcuts.gridWidth);
  }

  private resolveSettingsRowWidth(): number {
    if (this.presentation.useSharedSectionWidth) {
      return this.resolveSectionRailWidth();
    }
    return Math.max(1, this.presentation.shortcuts.gridWidth);
  }
}
