import { BrowserHomePageStyle } from '../../common/models/HomePagePresentationSettingsModels';
import {
  CustomHomepageCarouselCard,
  CustomHomepageSystemChoiceViewState
} from '../customhome/CustomHomepageSettingsViewModel';
import { SYSTEM_HOMEPAGE_STYLE_CATALOG } from '../customhome/SystemHomepageStyleCatalog';

const FEATURE_INTRO_HOMEPAGE_TITLE: string = '选择主页样式';
const FEATURE_INTRO_HOMEPAGE_SUBTITLE: string = '这是打开新标签时看到的主页。之后也可以在设置里更改。';
const FEATURE_INTRO_HOMEPAGE_CONTINUE_LABEL: string = '下一步';
const FEATURE_INTRO_HOMEPAGE_PREVIOUS_LABEL: string = '上一步';
const FEATURE_INTRO_HOMEPAGE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_HOMEPAGE_DEFAULT_STYLE: BrowserHomePageStyle = 'classic';
export function resolveFeatureIntroHomepageStyle(value: string): BrowserHomePageStyle {
  return value === 'centered' ? 'centered' : 'classic';
}

export class FeatureIntroHomepageViewModel {
  title(): string {
    return FEATURE_INTRO_HOMEPAGE_TITLE;
  }

  subtitle(): string {
    return FEATURE_INTRO_HOMEPAGE_SUBTITLE;
  }

  continueLabel(): string {
    return FEATURE_INTRO_HOMEPAGE_CONTINUE_LABEL;
  }

  previousLabel(): string {
    return FEATURE_INTRO_HOMEPAGE_PREVIOUS_LABEL;
  }

  skipLabel(): string {
    return FEATURE_INTRO_HOMEPAGE_SKIP_LABEL;
  }

  defaultStyle(): BrowserHomePageStyle {
    return FEATURE_INTRO_HOMEPAGE_DEFAULT_STYLE;
  }

  choices(selectedStyle: BrowserHomePageStyle): CustomHomepageSystemChoiceViewState[] {
    const selected = resolveFeatureIntroHomepageStyle(selectedStyle);
    return SYSTEM_HOMEPAGE_STYLE_CATALOG.map((entry): CustomHomepageSystemChoiceViewState => {
      return {
        style: entry.style,
        title: entry.title,
        isActive: entry.style === selected
      };
    });
  }

  cards(selectedStyle: BrowserHomePageStyle): CustomHomepageCarouselCard[] {
    return this.choices(selectedStyle).map((choice: CustomHomepageSystemChoiceViewState): CustomHomepageCarouselCard => {
      return {
        key: `system:${choice.style}`,
        kind: 'system',
        title: choice.title,
        systemStyle: choice.style,
        choiceId: '',
        isCurrent: choice.isActive
      };
    });
  }
}
