@Observed
export class SensorData {
  // 动态键值存储，key 来自后端 sensor-meta
  values: Record<string, number> = {};
  // 触发 UI 刷新的计数器（@Observed 不深度监听 Record）
  revision: number = 0;

  getValue(key: string): number {
    return this.values[key] ?? 0;
  }

  setValue(key: string, val: number): void {
    this.values[key] = val;
    this.revision++;
  }

  /** 批量写入后统一触发一次 revision */
  setValues(kvs: Record<string, number>): void {
    const keys = Object.keys(kvs);
    for (let i = 0; i < keys.length; i++) {
      this.values[keys[i]] = kvs[keys[i]];
    }
    this.revision++;
  }
}
