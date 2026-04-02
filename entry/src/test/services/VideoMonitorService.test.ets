/**
 * VideoMonitorService 单元测试
 *
 * VideoMonitorService 是 HttpService 的薄封装层 (facade)。
 * 本地测试仅验证 Singleton。
 * 完整集成测试（mock HTTP 响应）应放在 ohosTest/ 中。
 */
import { describe, it, expect } from '@ohos/hypium';
import { VideoMonitorService } from '../../main/ets/services/VideoMonitorService';

export default function videoMonitorServiceTest() {
  describe('VideoMonitorService', () => {

    it('getInstance_returns_same_instance', 0, () => {
      let a = VideoMonitorService.getInstance();
      let b = VideoMonitorService.getInstance();
      expect(a === b).assertTrue();
    });

    it('getInstance_returns_non_null', 0, () => {
      let svc = VideoMonitorService.getInstance();
      expect(svc !== null).assertTrue();
      expect(svc !== undefined).assertTrue();
    });
  });
}
