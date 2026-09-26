import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { loginComponentManager } from '@kit.AccountKit';
import { DEFAULT_THEME_PALETTE } from '../../features/theme/palettes/DefaultThemePalette';
import {
  StartupWelcomeIntroActionState,
  StartupWelcomeIntroViewState
} from '../../core/onboarding/StartupWelcomeIntroViewModel';
import {
  StartupWelcomeIntroCoordinator,
  StartupWelcomeIntroHost,
  StartupWelcomeIntroLoginCredential
} from '../../core/onboarding/StartupWelcomeIntroCoordinator';
import {
  BROWSER_THEME_STORAGE_ACCENT_KEY,
  BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY,
  BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY,
  BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY,
  BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY
} from '../../core/theme/BrowserThemeStorageKeys';
import { BrowserBoundaryRouteState } from '../../common/utils/RouteParamUtils';
import { SyncFirstActivationItemsCoordinator, SyncFirstActivationItemId, SyncFirstActivationItemsState } from '../../core/sync/SyncFirstActivationItemsCoordinator';
import { SyncFirstActivationItemsSheet } from '../components/sync/SyncFirstActivationItemsSheet';
import { HuaweiLoginSheetContent } from '../components/account/HuaweiLoginSheetContent';
import { SettingsActionButton } from '../components/settings/SettingsRows';
import { FeatureIntroSkipControl } from '../components/onboarding/FeatureIntroSkipControl';
import { SettingsNavigationCoordinator } from '../router/SettingsNavigationCoordinator';
import { BrowserStatusBarStyleService } from '../../services/browser/BrowserStatusBarStyleService';
import { SettingsTopSafeInsetService } from '../../services/settings/SettingsTopSafeInsetService';
import { finishOnboardingToBrowser, returnToPreviousOnboardingStep } from '../router/OnboardingNavigation';

const STARTUP_WELCOME_HORIZONTAL_PADDING: number = 24;
const STARTUP_WELCOME_BOTTOM_PADDING: number = 24;
const STARTUP_WELCOME_CONTENT_MAX_WIDTH: number = 430;
const STARTUP_WELCOME_ICON_SIZE: number = 88;
const STARTUP_WELCOME_ICON_RADIUS: number = 20;
const STARTUP_WELCOME_ACTION_HEIGHT: number = 44;
const STARTUP_WELCOME_ACTION_GAP: number = 10;

const STARTUP_WELCOME_EMPTY_BOUNDARY: BrowserBoundaryRouteState = {
  dataScope: '',
  privacyMode: '',
  boundarySource: ''
};

@Entry
@Component
struct StartupWelcomeIntroPage {
  @StorageProp(BROWSER_THEME_STORAGE_ACCENT_KEY) private storedAccentColor: string = '#0A59F7';
  @StorageProp(BROWSER_THEME_STORAGE_PAGE_BACKGROUND_KEY) private storedPageBackgroundColor: string =
    DEFAULT_THEME_PALETTE.light.pageBackground;
  @StorageProp(BROWSER_THEME_STORAGE_PRESSED_BACKGROUND_KEY) private storedPressedBackgroundColor: string = '#DDE4EC';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_PRIMARY_KEY) private storedPrimaryTextColor: string = '#111318';
  @StorageProp(BROWSER_THEME_STORAGE_TEXT_SECONDARY_KEY) private storedSecondaryTextColor: string = '#5F6875';
  @StorageProp(BROWSER_THEME_STORAGE_RESOLVED_MODE_KEY) @Watch('syncStatusBarContentStyle')
  private storedResolvedThemeMode: string = 'light';
  @State private busy: boolean = false;
  @State private topInset: number = 0;
  @State private syncChoicesVisible: boolean = false;
  @State private syncChoicesHandled: boolean = false;
  @State private syncChoices: SyncFirstActivationItemsState = new SyncFirstActivationItemsCoordinator()
    .buildDefaultState('aira_cloud');
  private readonly syncChoicesCoordinator: SyncFirstActivationItemsCoordinator =
    new SyncFirstActivationItemsCoordinator();
  private readonly navigationCoordinator: SettingsNavigationCoordinator = new SettingsNavigationCoordinator();
  private readonly topSafeInsetService: SettingsTopSafeInsetService = new SettingsTopSafeInsetService();
  private readonly statusBarStyleService: BrowserStatusBarStyleService = new BrowserStatusBarStyleService();
  private readonly host: StartupWelcomeIntroHost = {
    setBusy: (busy: boolean): void => {
      this.busy = busy;
    },
    showMessage: (message: string): void => {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    },
    navigateToPersonalServer: (): void => {
      this.navigationCoordinator.openSyncPersonalServerConfig(STARTUP_WELCOME_EMPTY_BOUNDARY, true);
    },
    navigateToWebdavConfig: (): void => {
      // The WebDAV config page owns the provider picker; entering it directly keeps
      // the flow self-contained so a saved config resumes straight into the shell.
      this.navigationCoordinator.openSyncWebdavConfig(STARTUP_WELCOME_EMPTY_BOUNDARY, 'active', true);
    },
    openUserAgreement: (): void => {
      this.navigationCoordinator.openLegalWebDocument('user_service_agreement', STARTUP_WELCOME_EMPTY_BOUNDARY);
    },
    openPrivacyPolicy: (): void => {
      this.navigationCoordinator.openPrivacyStatement(STARTUP_WELCOME_EMPTY_BOUNDARY);
    },
    presentSyncContentChoices: (): void => {
      this.syncChoices = this.syncChoicesCoordinator.buildDefaultState('aira_cloud');
      this.syncChoicesHandled = false;
      this.syncChoicesVisible = true;
    },
    leaveIntro: (): void => {
      finishOnboardingToBrowser();
    }
  };
  private readonly coordinator: StartupWelcomeIntroCoordinator =
    new StartupWelcomeIntroCoordinator(this.host);
  private readonly huaweiLoginButtonController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
      .onClickLoginWithHuaweiIDButton((
        error: BusinessError | undefined,
        response: loginComponentManager.HuaweiIDCredential | undefined
      ) => {
        this.coordinator.handleLoginCredential(this.toCredential(error, response));
      });

  aboutToAppear(): void {
    this.syncStatusBarContentStyle();
  }

  onBackPress(): boolean {
    this.returnToPreviousStep();
    return true;
  }

  onPageShow(): void {
    this.readTopInset();
    this.syncStatusBarContentStyle();
    this.coordinator.finishIfConfiguredOnResume();
  }

  build() {
    Column() {
      FeatureIntroSkipControl({
        label: this.resolveState().skipActionLabel,
        leadingLabel: this.resolveState().previousActionLabel,
        topInsetVp: this.topInset,
        skipEnabled: !this.busy,
        onConfirm: (): void => {
          this.coordinator.skipIntro();
        },
        onLeading: (): void => {
          this.returnToPreviousStep();
        }
      })

      Scroll() {
        Column() {
          this.buildAppIcon()

          Text(this.resolveState().hero.title)
            .width('100%')
            .fontSize(26)
            .lineHeight(34)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.storedPrimaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 24 })

          Text(this.resolveState().hero.subtitle)
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(this.storedSecondaryTextColor)
            .textAlign(TextAlign.Center)
            .margin({ top: 10 })
        }
        .width('100%')
        .constraintSize({ maxWidth: STARTUP_WELCOME_CONTENT_MAX_WIDTH })
        .padding({ left: STARTUP_WELCOME_HORIZONTAL_PADDING, right: STARTUP_WELCOME_HORIZONTAL_PADDING })
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .align(Alignment.Center)

      this.buildBottomActions()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.storedPageBackgroundColor)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .bindSheet($$this.syncChoicesVisible, this.buildSyncChoicesSheet(), {
      height: SheetSize.LARGE,
      dragBar: false,
      showClose: false,
      onDisappear: (): void => {
        this.finishSyncChoices(false);
      }
    })
  }

  @Builder
  private buildSyncChoicesSheet() {
    SyncFirstActivationItemsSheet({
      state: $syncChoices,
      isBusy: this.busy,
      layoutMode: 'phone',
      submitLabel: '立即同步',
      onToggle: (id: SyncFirstActivationItemId, enabled: boolean): void => {
        this.syncChoices = this.syncChoicesCoordinator.updateItemEnabled(this.syncChoices, id, enabled);
      },
      onSubmit: (): void => {
        this.finishSyncChoices(true);
      },
      onClose: (): void => {
        this.finishSyncChoices(false);
      }
    })
  }

  @Builder
  private buildAppIcon() {
    Image($r('app.media.aira_default_app_icon'))
      .width(STARTUP_WELCOME_ICON_SIZE)
      .height(STARTUP_WELCOME_ICON_SIZE)
      .borderRadius(STARTUP_WELCOME_ICON_RADIUS)
      .clip(true)
      .objectFit(ImageFit.Cover)
      .interpolation(ImageInterpolation.High)
  }

  @Builder
  private buildBottomActions() {
    Column({ space: STARTUP_WELCOME_ACTION_GAP }) {
      if (this.resolveState().showHuaweiLogin) {
        HuaweiLoginSheetContent({
          contentMode: 'inline',
          buttonHeight: STARTUP_WELCOME_ACTION_HEIGHT,
          controller: this.huaweiLoginButtonController,
          onOpenUserAgreement: () => {
            this.coordinator.openUserAgreement();
          },
          onOpenPrivacyPolicy: () => {
            this.coordinator.openPrivacyPolicy();
          }
        })
      }

      ForEach(this.resolveState().actions, (action: StartupWelcomeIntroActionState) => {
        SettingsActionButton({
          title: action.label,
          variant: 'tonal',
          isEnabled: !this.busy,
          accentColor: this.storedAccentColor,
          pressedBackgroundColor: this.storedPressedBackgroundColor,
          onAction: () => {
            this.coordinator.handleAction(action.id);
          }
        })
      }, (action: StartupWelcomeIntroActionState) => action.id)
    }
    .width('100%')
    .constraintSize({ maxWidth: STARTUP_WELCOME_CONTENT_MAX_WIDTH })
    .padding({
      left: STARTUP_WELCOME_HORIZONTAL_PADDING,
      right: STARTUP_WELCOME_HORIZONTAL_PADDING,
      bottom: STARTUP_WELCOME_BOTTOM_PADDING
    })
    .enabled(!this.busy)
    .opacity(this.busy ? 0.58 : 1)
  }

  private finishSyncChoices(confirm: boolean): void {
    if (this.syncChoicesHandled) {
      return;
    }
    this.syncChoicesHandled = true;
    this.syncChoicesVisible = false;
    if (confirm) {
      this.coordinator.confirmHuaweiSyncChoices(this.syncChoices);
      return;
    }
    this.coordinator.dismissHuaweiSyncChoices();
  }

  private returnToPreviousStep(): void {
    if (this.busy) {
      return;
    }
    returnToPreviousOnboardingStep('account');
  }

  private syncStatusBarContentStyle(): void {
    this.statusBarStyleService.applyLightContentStyle(
      this.getUIContext().getHostContext() as common.UIAbilityContext,
      this.storedResolvedThemeMode === 'dark'
    );
  }

  private readTopInset(): void {
    this.topSafeInsetService.resolve(this.getUIContext().getHostContext() as common.UIAbilityContext)
      .then((inset: number) => {
        this.topInset = inset;
      });
  }

  private toCredential(
    error: BusinessError | undefined,
    response: loginComponentManager.HuaweiIDCredential | undefined
  ): StartupWelcomeIntroLoginCredential {
    return {
      errorCode: error === undefined ? 0 : error.code,
      errorMessage: error === undefined ? '' : error.message,
      authorizationCode: response === undefined ? '' : response.authorizationCode.trim(),
      openId: response === undefined ? '' : response.openID.trim()
    };
  }

  private resolveState(): StartupWelcomeIntroViewState {
    return this.coordinator.buildState();
  }
}
