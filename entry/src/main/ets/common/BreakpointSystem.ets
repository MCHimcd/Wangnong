/**
 * Purpose: 在应用级维护统一的响应式断点状态，供页面和视图通过 AppStorage 读取。
 * Responsibilities: 监听屏幕宽度区间，写入 sm/md/lg 断点，并提供断点到列数的基础映射。
 * Flow: 入口页调用 register() 建立监听；各组件通过 @StorageLink('currentBreakpoint') 响应布局变化。
 * Dependencies: 依赖 @kit.ArkUI.mediaquery 和 AppStorage。
 * Input: 系统窗口宽度变化事件。
 * Output: 全局存储键 currentBreakpoint，以及 columnsForBreakpoint() 的列数结果。
 * Boundary: 这里只定义宽度断点，不负责页面级的复杂布局策略。
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

  // Reason: 先 setOrCreate 默认值，再注册三个区间监听，可保证页面首次渲染时已有稳定断点值。
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

/**
 * Purpose: 为简单网格布局提供默认列数映射。
 * Boundary: 更复杂的断点布局仍应在页面内部显式处理。
 */
export function columnsForBreakpoint(bp: string): number {
  if (bp === 'lg') {
    return 4;
  }
  if (bp === 'md') {
    return 3;
  }
  return 2;
}
