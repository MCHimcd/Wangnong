import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

/**
 * Purpose: 应用主 Ability 入口，负责 ArkUI 主窗口生命周期与首屏页面装载。
 * Responsibilities: 响应系统生命周期、创建窗口并加载登录页、输出基础运行日志。
 * Flow: 系统拉起 Ability 后触发 onCreate() 和 onWindowStageCreate()；主窗口加载 pages/LoginPage 作为应用入口。
 * Dependencies: 依赖 AbilityKit、ArkUI window 和 hilog。
 * Input: 系统传入的 Want、LaunchParam 与 WindowStage 生命周期事件。
 * Output: 主窗口内容被挂载到 LoginPage，并记录生命周期日志。
 * Side Effects: 会向系统日志写入前后台和窗口阶段状态。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/LoginPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
