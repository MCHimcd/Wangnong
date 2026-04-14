/**
 * Purpose: 约束阈值同步服务的单播/广播行为，确保阈值保存后可即时通知 Index 刷新内存元数据。
 * Responsibilities: 验证单例、监听器注册去重、事件广播与移除监听后的静默行为。
 * Flow: 测试通过 addListener/removeListener/notifyThresholdUpdated 驱动完整通知链。
 * Dependencies: ThresholdSyncService。
 * Boundary: 这里只验证内存通知，不验证具体页面是否消费事件。
 */
import { describe, it, expect } from '@ohos/hypium';
import { ThresholdSyncEvent, ThresholdSyncService } from '../../main/ets/services/ThresholdSyncService';

export default function thresholdSyncServiceTest() {
  describe('ThresholdSyncService', () => {
    it('getInstance_returns_same_instance', 0, () => {
      let a = ThresholdSyncService.getInstance();
      let b = ThresholdSyncService.getInstance();
      expect(a === b).assertTrue();
    });

    it('notifyThresholdUpdated_notifies_listener_once', 0, () => {
      let service = ThresholdSyncService.getInstance();
      let callCount = 0;
      let lastNodeId = '';
      let lastSensorKey = '';
      let lastWarningMax = 0;
      const listener = (event: ThresholdSyncEvent) => {
        callCount++;
        lastNodeId = event.nodeId;
        lastSensorKey = event.sensorKey;
        lastWarningMax = event.warningMax ?? 0;
      };

      service.addListener(listener);
      service.addListener(listener);
      service.notifyThresholdUpdated('SIM_Node_01', 'temperature', 18, 30);
      service.removeListener(listener);

      expect(callCount).assertEqual(1);
      expect(lastNodeId).assertEqual('SIM_Node_01');
      expect(lastSensorKey).assertEqual('temperature');
      expect(lastWarningMax).assertEqual(30);
    });

    it('removeListener_stops_future_notifications', 0, () => {
      let service = ThresholdSyncService.getInstance();
      let callCount = 0;
      const listener = (_event: ThresholdSyncEvent) => {
        callCount++;
      };

      service.addListener(listener);
      service.removeListener(listener);
      service.notifyThresholdUpdated('SIM_Node_01', 'co2', 350, 450);

      expect(callCount).assertEqual(0);
    });
  });
}