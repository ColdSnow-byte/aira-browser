export interface FeatureIntroSlide {
  id: string;
  title: string;
  body: string;
}

const FEATURE_INTRO_SLIDES: FeatureIntroSlide[] = [
  {
    id: 'ad_block',
    title: '少一点广告打扰',
    body: '按你启用的规则过滤网页广告，也可以手动隐藏看不顺眼的元素。'
  },
  {
    id: 'video_takeover',
    title: '接管网页视频',
    body: '用 Aira 播放器控制网页里的真实视频，调倍速、切画面，也能下载。'
  },
  {
    id: 'user_scripts',
    title: '支持用户脚本',
    body: '导入脚本后，只在匹配的网站里改页面，也可以单独开关。'
  },
  {
    id: 'sync',
    title: '换一台，接着用',
    body: '书签和常用设置可以同步。配对电脑后，也能看到那边的标签页，把当前网页推过去。'
  }
];

const FEATURE_INTRO_NEXT_LABEL: string = '下一步';
const FEATURE_INTRO_DONE_LABEL: string = '下一步';
const FEATURE_INTRO_GATE_LABEL: string = '向右滑动开始使用';
const FEATURE_INTRO_GATE_SKIP_LABEL: string = '跳过';
const FEATURE_INTRO_SKIP_CONFIRM_TITLE: string = '跳过介绍';
const FEATURE_INTRO_SKIP_CONFIRM_MESSAGE: string = '跳过后将直接进入主页，不再显示这些介绍。';
const FEATURE_INTRO_SKIP_CONFIRM_CANCEL_LABEL: string = '取消';
const FEATURE_INTRO_SKIP_CONFIRM_ENTER_LABEL: string = '进入主页';

export class FeatureIntroViewModel {
  slides(): FeatureIntroSlide[] {
    return FEATURE_INTRO_SLIDES;
  }

  actionLabel(index: number): string {
    return this.isLast(index) ? FEATURE_INTRO_DONE_LABEL : FEATURE_INTRO_NEXT_LABEL;
  }

  gateActionLabel(): string {
    return FEATURE_INTRO_GATE_LABEL;
  }

  gateSkipLabel(): string {
    return FEATURE_INTRO_GATE_SKIP_LABEL;
  }

  skipConfirmTitle(): string {
    return FEATURE_INTRO_SKIP_CONFIRM_TITLE;
  }

  skipConfirmMessage(): string {
    return FEATURE_INTRO_SKIP_CONFIRM_MESSAGE;
  }

  skipConfirmCancelLabel(): string {
    return FEATURE_INTRO_SKIP_CONFIRM_CANCEL_LABEL;
  }

  skipConfirmEnterLabel(): string {
    return FEATURE_INTRO_SKIP_CONFIRM_ENTER_LABEL;
  }

  isLast(index: number): boolean {
    return index >= FEATURE_INTRO_SLIDES.length - 1;
  }
}
