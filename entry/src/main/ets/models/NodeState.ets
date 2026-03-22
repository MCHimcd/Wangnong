@Observed
export class NodeState {
  smartMode: boolean = false;
  controlStateBootstrapped: boolean = false;
  // 动态键值存储，key 来自后端 equipment-meta
  equipmentStates: Record<string, boolean> = {};
  revision: number = 0;

  getState(key: string): boolean {
    return this.equipmentStates[key] ?? false;
  }

  setState(key: string, val: boolean): void {
    this.equipmentStates[key] = val;
    this.revision++;
  }
}
