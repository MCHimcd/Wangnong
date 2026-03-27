/**
 * 响应式断点系统
 * 使用 @ohos.mediaquery 监听屏幕宽度变化
 * 通过 AppStorage 广播当前断点给所有页面
 *
 * 断点:
 *   'sm'  — <600vp   手机竖屏
 *   'md'  — 600-840vp 手机横屏 / 小平板
 *   'lg'  — >840vp   平板横屏 / 电脑
 */
import { mediaquery } from '@kit.ArkUI';

export type BreakpointName = 'sm' | 'md' | 'lg';

const STORAGE_KEY = 'currentBreakpoint';

export class BreakpointSystem {
  private static instance: BreakpointSystem | null = null;
  private smListener: mediaquery.MediaQueryListener | null = null;
  private mdListener: mediaquery.MediaQueryListener | null = null;
  private lgListener: mediaquery.MediaQueryListener | null = null;

  private constructor() {}

  static getInstance(): BreakpointSystem {
    if (!BreakpointSystem.instance) {
      BreakpointSystem.instance = new BreakpointSystem();
    }
    return BreakpointSystem.instance;
  }

  register(): void {
    AppStorage.setOrCreate<string>(STORAGE_KEY, 'sm');

    this.smListener = mediaquery.matchMediaSync('(width<600vp)');
    this.smListener.on('change', (result: mediaquery.MediaQueryResult) => {
      if (result.matches) {
        AppStorage.set<string>(STORAGE_KEY, 'sm');
      }
    });

    this.mdListener = mediaquery.matchMediaSync('(600vp<=width<840vp)');
    this.mdListener.on('change', (result: mediaquery.MediaQueryResult) => {
      if (result.matches) {
        AppStorage.set<string>(STORAGE_KEY, 'md');
      }
    });

    this.lgListener = mediaquery.matchMediaSync('(840vp<=width)');
    this.lgListener.on('change', (result: mediaquery.MediaQueryResult) => {
      if (result.matches) {
        AppStorage.set<string>(STORAGE_KEY, 'lg');
      }
    });

    // 初始检测
    if (this.lgListener.matches) {
      AppStorage.set<string>(STORAGE_KEY, 'lg');
    } else if (this.mdListener.matches) {
      AppStorage.set<string>(STORAGE_KEY, 'md');
    } else {
      AppStorage.set<string>(STORAGE_KEY, 'sm');
    }
  }

  unregister(): void {
    if (this.smListener) {
      this.smListener.off('change');
    }
    if (this.mdListener) {
      this.mdListener.off('change');
    }
    if (this.lgListener) {
      this.lgListener.off('change');
    }
  }
}

/** 根据断点返回对应列数 */
export function columnsForBreakpoint(bp: string): number {
  if (bp === 'lg') {
    return 4;
  }
  if (bp === 'md') {
    return 3;
  }
  return 2;
}
