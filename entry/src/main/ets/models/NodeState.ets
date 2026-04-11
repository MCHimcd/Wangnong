@Observed
export class NodeState {
  smartMode: boolean = false;
  /** 用户最后一次切换模式的时间戳，用于防止遥测覆盖 */
  smartModeCommandAt: number = 0;
  controlStateBootstrapped: boolean = false;
  // 动态键值存储，key 来自后端 equipment-meta
  equipmentStates: Record<string, boolean> = {};
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
}
