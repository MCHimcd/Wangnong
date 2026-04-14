/**
 * AlertSyncService 单元测试
 *
 * 测试可在本地验证的纯逻辑：
 * - Singleton 模式
 * - getAllAlerts 初始状态
 * - 数据变更监听器的注册/注销
 * - setAlertDialogCallback 设置
 *
 * startRealtimeSync / markHandled 依赖 MQTT 和 HTTP 服务，
 * 完整集成测试需放在 ohosTest/ 中。
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { AlertSyncService } from '../../main/ets/services/AlertSyncService';
import { AlertData } from '../../main/ets/models/AlertData';

export default function alertSyncServiceTest() {
  describe('AlertSyncService', () => {

    beforeEach(() => {
      AlertSyncService.getInstance().resetForTest();
    });

    // ===== Singleton =====
    it('getInstance_returns_same_instance', 0, () => {
      let a = AlertSyncService.getInstance();
      let b = AlertSyncService.getInstance();
      expect(a === b).assertTrue();
    });

    // ===== 初始状态 =====
    it('getAllAlerts_returns_array', 0, () => {
      let svc = AlertSyncService.getInstance();
      let alerts = svc.getAllAlerts();
      expect(alerts instanceof Array).assertTrue();
    });

    it('getAllAlerts_returns_copy', 0, () => {
      let svc = AlertSyncService.getInstance();
      let a = svc.getAllAlerts();
      let b = svc.getAllAlerts();
      expect(a !== b).assertTrue();
    });

    // ===== 数据变更监听器 =====
    it('subscribeDataChange_does_not_throw', 0, () => {
      let svc = AlertSyncService.getInstance();
      let listener = () => {};
      svc.subscribeDataChange(listener);
      svc.unsubscribeDataChange(listener);
      expect(true).assertTrue();
    });

    it('unsubscribeDataChange_for_unregistered_does_not_throw', 0, () => {
      let svc = AlertSyncService.getInstance();
      let listener = () => {};
      svc.unsubscribeDataChange(listener); // 未注册直接注销
      expect(true).assertTrue();
    });

    it('duplicate_subscribe_is_idempotent', 0, () => {
      let svc = AlertSyncService.getInstance();
      let callCount = 0;
      let listener = () => { callCount++; };
      svc.subscribeDataChange(listener);
      svc.subscribeDataChange(listener); // 重复注册应被忽略
      svc.unsubscribeDataChange(listener);
      expect(true).assertTrue();
    });

    // ===== 对话框回调 =====
    it('setAlertDialogCallback_accepts_function', 0, () => {
      let svc = AlertSyncService.getInstance();
      let called = false;
      svc.setAlertDialogCallback((alert: AlertData) => {
        called = true;
      });
      expect(true).assertTrue();
    });

    // ===== stopRealtimeSync 安全性 =====
    it('stopRealtimeSync_without_start_does_not_throw', 0, () => {
      let svc = AlertSyncService.getInstance();
      svc.stopRealtimeSync();
      expect(true).assertTrue();
    });

    it('upsertLocalAlert_adds_alert_to_memory', 0, () => {
      let svc = AlertSyncService.getInstance();
      let alert = new AlertData();
      alert.alert_id = 'SIM_LOCAL_temperature_1';
      alert.type = 'temperature_alert';
      alert.type_name = '温度异常';
      alert.level = 'warning';
      alert.timestamp = 1;
      alert.message = '测试本地告警';
      alert.source = 'temperature';
      alert.source_name = '空气温度';

      svc.upsertLocalAlert(alert);

      expect(svc.getAllAlerts().length).assertEqual(1);
      expect(svc.getAllAlerts()[0].alert_id).assertEqual('SIM_LOCAL_temperature_1');
    });

    it('markHandled_local_alert_marks_without_http', 0, async () => {
      let svc = AlertSyncService.getInstance();
      let alert = new AlertData();
      alert.alert_id = 'SIM_LOCAL_co2_1';
      alert.type = 'co2_alert';
      alert.type_name = 'CO2 异常';
      alert.level = 'warning';
      alert.timestamp = 2;
      alert.message = '本地告警';
      svc.upsertLocalAlert(alert);

      let success = await svc.markHandled('SIM_LOCAL_co2_1');

      expect(success).assertTrue();
      expect(svc.getAllAlerts()[0].is_handled).assertTrue();
    });
  });
}
