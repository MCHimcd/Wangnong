/**
 * HttpService 单元测试
 *
 * 注意：HttpService 内部通过 @ohos.net.http 发出真实 HTTP 请求。
 * 在本地单元测试中无法访问真实网络。我们仅测试可在本地验证的逻辑：
 * - Singleton 模式
 * - Token / NodeId 设置
 * - Request 数据类的构造与默认值
 *
 * 需要 HTTP mock 的集成测试应放在 ohosTest/ 中通过 Hamock 替换 @ohos.net.http。
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { HttpService,
  LoginRequest, RegisterRequest, ForgotPasswordRequest,
  SendVerificationCodeRequest, ChangePasswordRequest, LogoutRequest,
  TraceabilityScanRequest, ApiQueryPayload, ApiDataPayload, AppApiPayload,
  AdminCreateNodeRequest, AdminUpdateNodeRequest, AdminUpdateRoleRequest,
  HealthStatusData,
  SetUserNodesRequest, CreateTaskRequest, UpdateTaskRequest, ThresholdUpdateItem
} from '../../main/ets/services/HttpService';

export default function httpServiceTest() {
  describe('HttpService', () => {

    // ===== Singleton 验证 =====
    it('getInstance_returns_same_instance', 0, () => {
      let a = HttpService.getInstance();
      let b = HttpService.getInstance();
      expect(a === b).assertTrue();
    });

    // ===== Request 数据类默认值 =====
    it('LoginRequest_defaults', 0, () => {
      let req = new LoginRequest();
      expect(req.username).assertEqual('');
      expect(req.password).assertEqual('');
    });

    it('RegisterRequest_defaults', 0, () => {
      let req = new RegisterRequest();
      expect(req.phone).assertEqual('');
      expect(req.verificationCode).assertEqual('');
      expect(req.password).assertEqual('');
    });

    it('ForgotPasswordRequest_defaults', 0, () => {
      let req = new ForgotPasswordRequest();
      expect(req.phone).assertEqual('');
      expect(req.verificationCode).assertEqual('');
      expect(req.newPassword).assertEqual('');
    });

    it('SendVerificationCodeRequest_defaults', 0, () => {
      let req = new SendVerificationCodeRequest();
      expect(req.phone).assertEqual('');
    });

    it('ChangePasswordRequest_defaults', 0, () => {
      let req = new ChangePasswordRequest();
      expect(req.oldPassword).assertEqual('');
      expect(req.newPassword).assertEqual('');
    });

    it('LogoutRequest_is_empty', 0, () => {
      let req = new LogoutRequest();
      expect(req !== null).assertTrue();
    });

    it('TraceabilityScanRequest_defaults', 0, () => {
      let req = new TraceabilityScanRequest();
      expect(req.code).assertEqual('');
    });

    it('ApiQueryPayload_defaults_are_undefined', 0, () => {
      let payload = new ApiQueryPayload();
      expect(payload.scene === undefined).assertTrue();
      expect(payload.page === undefined).assertTrue();
      expect(payload.size === undefined).assertTrue();
    });

    it('ApiDataPayload_defaults_are_undefined', 0, () => {
      let payload = new ApiDataPayload();
      expect(payload.alert_id === undefined).assertTrue();
      expect(payload.action === undefined).assertTrue();
    });

    it('AppApiPayload_has_app_id', 0, () => {
      let payload = new AppApiPayload();
      expect(payload.app_id.length > 0).assertTrue();
      expect(payload.node_id).assertEqual('');
      expect(payload.timestamp).assertEqual(0);
    });

    it('AdminCreateNodeRequest_defaults', 0, () => {
      let req = new AdminCreateNodeRequest();
      expect(req.nodeId).assertEqual('');
      expect(req.nodeName).assertEqual('');
    });

    it('AdminUpdateNodeRequest_defaults', 0, () => {
      let req = new AdminUpdateNodeRequest();
      expect(req.nodeName).assertEqual('');
    });

    it('AdminUpdateRoleRequest_defaults', 0, () => {
      let req = new AdminUpdateRoleRequest();
      expect(req.role).assertEqual('');
    });

    it('SetUserNodesRequest_defaults', 0, () => {
      let req = new SetUserNodesRequest();
      expect(req.nodeIds.length).assertEqual(0);
    });

    it('CreateTaskRequest_defaults', 0, () => {
      let req = new CreateTaskRequest();
      expect(req.nodeId).assertEqual('');
      expect(req.equipmentKey).assertEqual('');
      expect(req.action).assertEqual('');
      expect(req.taskName).assertEqual('');
      expect(req.hour).assertEqual(0);
      expect(req.minute).assertEqual(0);
      expect(req.repeatDays).assertEqual('');
    });

    it('UpdateTaskRequest_defaults', 0, () => {
      let req = new UpdateTaskRequest();
      expect(req.nodeId).assertEqual('');
      expect(req.equipmentKey).assertEqual('');
    });

    it('ThresholdUpdateItem_defaults', 0, () => {
      let item = new ThresholdUpdateItem();
      expect(item.sensorKey).assertEqual('');
      expect(item.warningMin).assertNull();
      expect(item.warningMax).assertNull();
    });

    it('HealthStatusData_defaults', 0, () => {
      let data = new HealthStatusData();
      expect(data.available).assertFalse();
      expect(data.mqttConnected).assertFalse();
      expect(data.application).assertEqual('');
      expect(data.mode).assertEqual('');
      expect(data.dataSimulated).assertFalse();
      expect(data.time).assertEqual('');
    });

    // ===== Token / NodeId 设置 =====
    it('setToken_does_not_throw', 0, () => {
      let svc = HttpService.getInstance();
      svc.setToken('test_token_123');
      // 无异常即通过
      expect(true).assertTrue();
    });

    it('setNodeId_does_not_throw', 0, () => {
      let svc = HttpService.getInstance();
      svc.setNodeId('A03_Node_02');
      expect(true).assertTrue();
    });

    it('checkServerHealth_method_exists', 0, () => {
      let svc = HttpService.getInstance();
      expect(svc.checkServerHealth !== undefined).assertTrue();
    });

    // ===== Request 数据类可赋值 =====
    it('LoginRequest_assignment', 0, () => {
      let req = new LoginRequest();
      req.username = 'admin';
      req.password = 'pass123';
      expect(req.username).assertEqual('admin');
      expect(req.password).assertEqual('pass123');
    });

    it('CreateTaskRequest_assignment', 0, () => {
      let req = new CreateTaskRequest();
      req.nodeId = 'A03_Node_01';
      req.equipmentKey = 'water_pump';
      req.action = 'turn_on';
      req.taskName = '每日灌溉';
      req.hour = 8;
      req.minute = 30;
      req.repeatDays = '1,2,3,4,5';

      expect(req.nodeId).assertEqual('A03_Node_01');
      expect(req.action).assertEqual('turn_on');
      expect(req.hour).assertEqual(8);
    });
  });
}
