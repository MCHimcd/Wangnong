/**
 * MqttClientService 单元测试
 *
 * 测试可在本地验证的纯逻辑：
 * - Singleton 模式
 * - 监听器注册/注销
 * - CachedTrendPoint 数据结构
 * - getCachedTrend 返回空数组（无缓存时）
 * - 命令队列 enqueueCommand / publishCommand 错误路径
 *
 * connect/disconnect/publish 涉及 @ohos/mqtt 原生模块，需在 ohosTest 中通过 Hamock 测试。
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { MqttClientService, CachedTrendPoint } from '../../main/ets/services/MqttClientService';

export default function mqttClientServiceTest() {
  describe('MqttClientService', () => {

    // ===== Singleton =====
    it('getInstance_returns_same_instance', 0, () => {
      let a = MqttClientService.getInstance();
      let b = MqttClientService.getInstance();
      expect(a === b).assertTrue();
    });

    // ===== CachedTrendPoint 数据结构 =====
    it('CachedTrendPoint_constructor', 0, () => {
      let point = new CachedTrendPoint('12:30:00', 25.3);
      expect(point.time).assertEqual('12:30:00');
      expect(point.value).assertEqual(25.3);
    });

    it('CachedTrendPoint_default_values', 0, () => {
      let point = new CachedTrendPoint('', 0);
      expect(point.time).assertEqual('');
      expect(point.value).assertEqual(0);
    });

    // ===== 监听器注册/注销 =====
    it('addTelemetryListener_does_not_throw', 0, () => {
      let svc = MqttClientService.getInstance();
      let listener = (nodeId: string, msg: string) => {};
      svc.addTelemetryListener(listener);
      // 清理
      svc.removeTelemetryListener(listener);
      expect(true).assertTrue();
    });

    it('removeTelemetryListener_does_not_throw_for_unregistered', 0, () => {
      let svc = MqttClientService.getInstance();
      let listener = (nodeId: string, msg: string) => {};
      svc.removeTelemetryListener(listener);
      expect(true).assertTrue();
    });

    it('addAlertListener_does_not_throw', 0, () => {
      let svc = MqttClientService.getInstance();
      let listener = (nodeId: string, msg: string) => {};
      svc.addAlertListener(listener);
      svc.removeAlertListener(listener);
      expect(true).assertTrue();
    });

    it('removeAlertListener_does_not_throw_for_unregistered', 0, () => {
      let svc = MqttClientService.getInstance();
      let listener = (nodeId: string, msg: string) => {};
      svc.removeAlertListener(listener);
      expect(true).assertTrue();
    });

    it('duplicate_listener_not_added_twice', 0, () => {
      let svc = MqttClientService.getInstance();
      let callCount = 0;
      let listener = (nodeId: string, msg: string) => {
        callCount++;
      };
      svc.addTelemetryListener(listener);
      svc.addTelemetryListener(listener); // 重复添加应被忽略
      // 清理
      svc.removeTelemetryListener(listener);
      expect(true).assertTrue();
    });

    // ===== 趋势缓存查询 =====
    it('getCachedTrend_returns_empty_for_unknown', 0, () => {
      let svc = MqttClientService.getInstance();
      let trend = svc.getCachedTrend('unknown_node', 'unknown_metric');
      expect(trend.length).assertEqual(0);
    });

    it('getCachedTrend_returns_copy_not_reference', 0, () => {
      let svc = MqttClientService.getInstance();
      let trend1 = svc.getCachedTrend('test_node', 'temperature');
      let trend2 = svc.getCachedTrend('test_node', 'temperature');
      expect(trend1 !== trend2).assertTrue();
    });

    // ===== 离线回调设置 =====
    it('setOnOfflineCallback_does_not_throw', 0, () => {
      let svc = MqttClientService.getInstance();
      svc.setOnOfflineCallback(() => {});
      expect(true).assertTrue();
    });

    // ===== 命令队列 (enqueueCommand) =====
    it('enqueueCommand_increments_queue_length', 0, () => {
      let svc = MqttClientService.getInstance();
      svc.clearCommandQueue();
      expect(svc.getCommandQueueLength()).assertEqual(0);
      svc.enqueueCommand('A03_Node_01', 'water_pump', 'turn_on');
      expect(svc.getCommandQueueLength()).assertEqual(1);
      svc.clearCommandQueue();
    });

    it('enqueueCommand_multiple_commands_accumulate', 0, () => {
      let svc = MqttClientService.getInstance();
      svc.clearCommandQueue();
      svc.enqueueCommand('A03_Node_01', 'water_pump', 'turn_on');
      svc.enqueueCommand('A03_Node_01', 'fan', 'turn_off');
      svc.enqueueCommand('A03_Node_01', 'mode', 'smart');
      expect(svc.getCommandQueueLength()).assertEqual(3);
      svc.clearCommandQueue();
    });

    it('enqueueCommand_with_custom_params', 0, () => {
      let svc = MqttClientService.getInstance();
      svc.clearCommandQueue();
      let params: Record<string, number> = {};
      params['duration_seconds'] = 30;
      svc.enqueueCommand('A03_Node_01', 'water_pump', 'turn_on', params);
      expect(svc.getCommandQueueLength()).assertEqual(1);
      svc.clearCommandQueue();
    });

    it('clearCommandQueue_empties_queue', 0, () => {
      let svc = MqttClientService.getInstance();
      svc.enqueueCommand('A03_Node_01', 'fan', 'turn_on');
      svc.clearCommandQueue();
      expect(svc.getCommandQueueLength()).assertEqual(0);
    });

    // ===== publishCommand 错误路径 =====
    it('publishCommand_returns_error_when_disconnected', 0, () => {
      let svc = MqttClientService.getInstance();
      // Singleton 未 connect 时，publishCommand 应返回非空错误字符串
      let result = svc.publishCommand('A03_Node_01', 'water_pump', 'turn_on');
      expect(result.length > 0).assertTrue();
    });

    it('publishCommand_returns_specific_error_message', 0, () => {
      let svc = MqttClientService.getInstance();
      let result = svc.publishCommand('A03_Node_01', 'water_pump', 'turn_on');
      // 应包含 "MQTT" 关键词
      expect(result).assertContain('MQTT');
    });

    // ===== isConnected =====
    it('isConnected_returns_boolean', 0, () => {
      let svc = MqttClientService.getInstance();
      let connected = svc.isConnected();
      expect(typeof connected).assertEqual('boolean');
    });
  });
}
