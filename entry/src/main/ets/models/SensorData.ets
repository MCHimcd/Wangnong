@Observed
export class SensorData {
  // 动态键值存储，key 来自后端 sensor-meta
  values: Record<string, number> = {};
  // 硬件摄像头当前帧 Base64 编码（JPEG）
  imageBase64: string = '';
  // 触发 UI 刷新的计数器（@Observed 不深度监听 Record）
  revision: number = 0;

  getValue(key: string): number {
    return this.values[key] ?? 0;
  }

  hasValue(key: string): boolean {
    return this.values[key] !== undefined;
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

  setImageBase64(val: string): void {
    // Strip data-URI prefix (e.g. "data:image/jpeg;base64,") if hardware sends it
    const marker = ';base64,';
    const idx = val.indexOf(marker);
    this.imageBase64 = idx >= 0 ? val.substring(idx + marker.length) : val;
    this.revision++;
  }
}
