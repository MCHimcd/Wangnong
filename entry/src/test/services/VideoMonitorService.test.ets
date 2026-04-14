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

    it('getLiveStreamInfo_sim_node_returns_frontend_fallback', 0, async () => {
      let info = await VideoMonitorService.getInstance().getLiveStreamInfo('SIM_Node_01');
      expect(info.cameraId).assertEqual('sim-frontend-camera');
      expect(info.streamTag).assertEqual('前端模拟');
    });

    it('getDailyPlaybackList_sim_node_returns_frontend_fallback', 0, async () => {
      let items = await VideoMonitorService.getInstance().getDailyPlaybackList('SIM_Node_01');
      expect(items.length > 0).assertTrue();
      expect(items[0].available).assertTrue();
      expect(items[0].date).assertEqual('2026-03-16');
      expect(items[0].duration).assertEqual('00:30:00');
      expect(items[0].quality).assertEqual('1080p');
    });

    it('getKeyframesByDate_sim_node_returns_demo_keyframes', 0, async () => {
      let items = await VideoMonitorService.getInstance().getKeyframesByDate('SIM_Node_01', '2026-03-16');
      expect(items.length).assertEqual(2);
      expect(items[0].thumbnailHint).assertEqual('sim_video_placeholder');
      expect(items[0].label).assertEqual('叶片病害');
      expect(items[1].label).assertEqual('虫害检测');
    });
  });
}
