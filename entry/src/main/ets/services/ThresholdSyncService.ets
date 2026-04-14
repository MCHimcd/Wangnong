/**
 * Purpose: 在阈值保存成功后向仍驻留的页面广播同步事件，避免必须整页重载才能看到新阈值生效。
 * Responsibilities: 维护监听器列表，并把 nodeId/sensorKey/阈值变化封装成统一事件发给消费方。
 * Flow: SensorDetailPage 保存阈值成功后调用 notifyThresholdUpdated()；Index 监听后更新内存中的 sensorMeta 并触发智能控制重判。
 * Dependencies: 仅依赖 ArkTS 运行时集合能力，被 SensorDetailPage 与 Index 共享。
 * Input: 节点 ID、传感器 key、最新 warningMin/warningMax。
 * Output: 同步给监听器的 ThresholdSyncEvent。
 * Boundary: 该服务只处理前端内存同步，不替代后端阈值持久化。
 */
export class ThresholdSyncEvent {
  nodeId: string = '';
  sensorKey: string = '';
  warningMin: number | null = null;
  warningMax: number | null = null;
}

export class ThresholdSyncService {
  private static instance: ThresholdSyncService;
  private listeners: Array<(event: ThresholdSyncEvent) => void> = [];

  private constructor() {}

  public static getInstance(): ThresholdSyncService {
    if (!ThresholdSyncService.instance) {
      ThresholdSyncService.instance = new ThresholdSyncService();
    }
    return ThresholdSyncService.instance;
  }

  public addListener(listener: (event: ThresholdSyncEvent) => void): void {
    if (this.listeners.indexOf(listener) === -1) {
      this.listeners.push(listener);
    }
  }

  public removeListener(listener: (event: ThresholdSyncEvent) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  public notifyThresholdUpdated(nodeId: string, sensorKey: string,
    warningMin: number | null, warningMax: number | null): void {
    let event = new ThresholdSyncEvent();
    event.nodeId = nodeId;
    event.sensorKey = sensorKey;
    event.warningMin = warningMin;
    event.warningMax = warningMax;

    this.listeners.forEach((listener: (event: ThresholdSyncEvent) => void) => {
      listener(event);
    });
  }
}