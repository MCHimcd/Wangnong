import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN = 0x0000;

/**
 * Purpose: 提供应用备份与恢复扩展入口，承接系统级数据迁移生命周期。
 * Responsibilities: 响应 onBackup() 和 onRestore()，记录执行日志并为后续扩展留出挂点。
 * Flow: 系统在备份或恢复阶段调用对应方法；当前实现仅确认流程可达。
 * Dependencies: 依赖 CoreFileKit 的 BackupExtensionAbility 和 BundleVersion。
 * Input: 系统触发的备份/恢复事件及恢复目标版本信息。
 * Output: 无业务数据返回，当前仅产生日志副作用。
 * Boundary: 该文件尚未实现实际数据打包与恢复逻辑。
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, 'testTag', 'onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'testTag', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}