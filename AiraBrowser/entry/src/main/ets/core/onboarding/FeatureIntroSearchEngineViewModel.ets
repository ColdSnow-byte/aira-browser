export type FeatureIntroSearchEngineChoiceId =
  'bing' |
  'baidu' |
  'google' |
  'sogou' |
  'qihoo' |
  'shenma';

export interface FeatureIntroSearchEngineChoice {
  id: FeatureIntroSearchEngineChoiceId;
  label: string;
}

const FEATURE_INTRO_SEARCH_ENGINE_TITLE: string = '选择默认搜索引擎';
const FEATURE_INTRO_SEARCH_ENGINE_SUBTITLE: string = '在地址栏搜索时会用它。之后也可以在设置里更改。';
const FEATURE_INTRO_SEARCH_ENGINE_CONTINUE_LABEL: string = '下一步';
const FEATURE_INTRO_SEARCH_ENGINE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_SEARCH_ENGINE_DEFAULT_ID: FeatureIntroSearchEngineChoiceId = 'bing';
const FEATURE_INTRO_SEARCH_ENGINE_CHOICES: FeatureIntroSearchEngineChoice[] = [
  { id: 'bing', label: '必应' },
  { id: 'baidu', label: '百度' },
  { id: 'google', label: '谷歌' },
  { id: 'sogou', label: '搜狗' },
  { id: 'qihoo', label: '360搜索' },
  { id: 'shenma', label: '神马' }
];

export function resolveFeatureIntroSearchEngineChoice(value: string): FeatureIntroSearchEngineChoiceId {
  if (value === 'baidu') {
    return 'baidu';
  }
  if (value === 'google') {
    return 'google';
  }
  if (value === 'sogou') {
    return 'sogou';
  }
  if (value === 'qihoo') {
    return 'qihoo';
  }
  if (value === 'shenma') {
    return 'shenma';
  }
  return 'bing';
}

export class FeatureIntroSearchEngineViewModel {
  title(): string {
    return FEATURE_INTRO_SEARCH_ENGINE_TITLE;
  }

  subtitle(): string {
    return FEATURE_INTRO_SEARCH_ENGINE_SUBTITLE;
  }

  continueLabel(): string {
    return FEATURE_INTRO_SEARCH_ENGINE_CONTINUE_LABEL;
  }

  skipLabel(): string {
    return FEATURE_INTRO_SEARCH_ENGINE_SKIP_LABEL;
  }

  defaultChoiceId(): FeatureIntroSearchEngineChoiceId {
    return FEATURE_INTRO_SEARCH_ENGINE_DEFAULT_ID;
  }

  choices(): FeatureIntroSearchEngineChoice[] {
    return FEATURE_INTRO_SEARCH_ENGINE_CHOICES;
  }
}
