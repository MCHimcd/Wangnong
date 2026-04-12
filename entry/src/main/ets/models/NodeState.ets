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

  /** 记录设备命令发送时间，并在防抖结束后自动刷新 UI */
  markCommandSent(key: string): void {
    this.commandTimestamps[key] = Date.now();
    setTimeout(() => {
      this.revision++;
    }, NodeState.DEBOUNCE_MS);
  }

  /** 检查设备是否在防抖冷却期内 */
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
