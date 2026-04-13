/**
 * Purpose: 管理单个节点的设备控制状态、数值状态和命令冷却信息。
 * Responsibilities: 保存智能模式、设备开关、设备数值以及去抖时间戳，并通过 revision 驱动 UI 刷新。
 * Flow: MonitorView 和 Index 在收到用户操作或遥测回显后调用 setState()/setValue()/markCommandSent() 更新状态。
 * Dependencies: 作为 Node 的子状态对象被多个页面共享。
 * Input: 设备键名、布尔/数值状态以及命令发送时刻。
 * Output: 供 UI 读取的实时控制状态。
 * Invariant: 修改 equipmentStates 或 equipmentValues 后必须推进 revision，否则 @Observed 无法感知 Record 内部变化。
 */
@Observed
export class NodeState {
  smartMode: boolean = false;
  /** 用户最后一次切换模式的时间戳，用于防止遥测覆盖 */
  smartModeCommandAt: number = 0;
  controlStateBootstrapped: boolean = false;
  // 动态键值存储，key 来自后端 equipment-meta
  equipmentStates: Record<string, boolean> = {};
  /** 设备数值状态（如 LED 亮度 0-100） */
  equipmentValues: Record<string, number> = {};
  /** 每个设备最后一次发送命令的时间戳，用于防抖 */
  commandTimestamps: Record<string, number> = {};
  /** 防抖间隔（毫秒） */
  static readonly DEBOUNCE_MS: number = 3000;
  revision: number = 0;

  getState(key: string): boolean {
    return this.equipmentStates[key] ?? false;
  }

  hasState(key: string): boolean {
    return this.equipmentStates[key] !== undefined;
  }

  setState(key: string, val: boolean): void {
    this.equipmentStates[key] = val;
    this.revision++;
  }

  /** 获取设备数值（如亮度），默认 0 */
  getValue(key: string): number {
    return this.equipmentValues[key] ?? 0;
  }

  /** 设置设备数值并联动布尔状态 */
  setValue(key: string, val: number): void {
    this.equipmentValues[key] = val;
    this.equipmentStates[key] = val > 0;
    this.revision++;
  }

  /**
   * Reason: 命令发送后短时间内会先看到用户本地态，随后才收到 MQTT 回显；这里保留冷却窗，避免 UI 被旧回显立即覆盖。
   */
  markCommandSent(key: string): void {
    this.commandTimestamps[key] = Date.now();
    setTimeout(() => {
      this.revision++;
    }, NodeState.DEBOUNCE_MS);
  }

  /** Precondition: 调用方应确保 key 对应的是可控设备键。 */
  isDebouncing(key: string): boolean {
    const lastCmd = this.commandTimestamps[key];
    if (lastCmd === undefined) {
      return false;
    }
    return (Date.now() - lastCmd) < NodeState.DEBOUNCE_MS;
  }

  /** 检查智能模式切换是否在防抖冷却期内 */
  isSmartModeDebouncing(): boolean {
    if (this.smartModeCommandAt === 0) {
      return false;
    }
    return (Date.now() - this.smartModeCommandAt) < NodeState.DEBOUNCE_MS;
  }
}
