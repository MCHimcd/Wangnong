/**
 * Purpose: 保存节点传感器实时读数和硬件摄像头图片帧。
 * Responsibilities: 管理动态指标值、Base64 图片字符串，并通过 revision 通知 UI 刷新。
 * Flow: Index 和详情页把遥测中的 environment/image_base64 写入该对象，MonitorView 和图表页按 key 读取展示。
 * Dependencies: 作为 Node 的子状态对象被监控视图、详情页和图表组件共享。
 * Input: 后端遥测中的指标键值和图片帧。
 * Output: 可被 UI 直接绑定的 @Observed 传感器状态。
 * Invariant: Record 更新后必须同步增加 revision，才能触发依赖该对象的组件刷新。
 */
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

  // Boundary: 某些硬件会上报 data URI 前缀，页面层统一保存纯 Base64，避免后续重复判定格式。
  setImageBase64(val: string): void {
    const marker = ';base64,';
    const idx = val.indexOf(marker);
    this.imageBase64 = idx >= 0 ? val.substring(idx + marker.length) : val;
    this.revision++;
  }
}
