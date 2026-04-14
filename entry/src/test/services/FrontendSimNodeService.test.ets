/**
 * Purpose: 约束 SIM_Node_01 的前端本地仿真数据窗口，确保环境值区间与异常场景都符合温室常识。
 * Responsibilities: 验证节点匹配、不同 tick 下的环境范围，以及本地视频数据回退入口。
 * Flow: 直接调用 FrontendSimNodeService 的预览方法，断言正常窗口与异常窗口落在预期区间内。
 * Dependencies: FrontendSimNodeService。
 * Boundary: 这里只验证本地仿真规则，不验证定时器调度本身。
 */
import { describe, it, expect } from '@ohos/hypium';
import { FrontendSimNodeService } from '../../main/ets/services/FrontendSimNodeService';

export default function frontendSimNodeServiceTest() {
  describe('FrontendSimNodeService', () => {
    it('isManagedNode_only_matches_sim_node', 0, () => {
      let svc = FrontendSimNodeService.getInstance();
      expect(svc.isManagedNode('SIM_Node_01')).assertTrue();
      expect(svc.isManagedNode('A03_Node_01')).assertFalse();
    });

    it('previewEnvironmentAtTick_normal_window_stays_in_reasonable_range', 0, () => {
      let env = FrontendSimNodeService.getInstance().previewEnvironmentAtTick(1);
      expect(env['temperature'] >= 24 && env['temperature'] <= 27).assertTrue();
      expect(env['humidity'] >= 58 && env['humidity'] <= 64).assertTrue();
      expect(env['co2'] >= 420 && env['co2'] <= 460).assertTrue();
      expect(env['soilHumidity'] >= 62 && env['soilHumidity'] <= 72).assertTrue();
    });

    it('previewEnvironmentAtTick_hot_window_exceeds_temp_and_co2_thresholds', 0, () => {
      let env = FrontendSimNodeService.getInstance().previewEnvironmentAtTick(5);
      expect(env['temperature'] > 32).assertTrue();
      expect(env['co2'] > 500).assertTrue();
    });

    it('previewEnvironmentAtTick_dry_window_drops_humidity_light_and_soil_humidity', 0, () => {
      let env = FrontendSimNodeService.getInstance().previewEnvironmentAtTick(8);
      expect(env['humidity'] < 45).assertTrue();
      expect(env['light'] < 200).assertTrue();
      expect(env['soilHumidity'] < 55).assertTrue();
    });

    it('previewEnvironmentAtTick_cold_window_drops_below_min_temperature', 0, () => {
      let env = FrontendSimNodeService.getInstance().previewEnvironmentAtTick(14);
      expect(env['temperature'] < 18).assertTrue();
      expect(env['soilTemp'] >= 15 && env['soilTemp'] <= 18).assertTrue();
    });

    it('buildLiveStreamInfo_returns_frontend_simulated_camera', 0, () => {
      let info = FrontendSimNodeService.getInstance().buildLiveStreamInfo();
      expect(info.cameraId).assertEqual('sim-frontend-camera');
      expect(info.status).assertEqual('online');
      expect(info.streamTag).assertEqual('前端模拟');
    });

    it('buildPlaybackItems_matches_demo_screen_data', 0, () => {
      let items = FrontendSimNodeService.getInstance().buildPlaybackItems();
      expect(items.length).assertEqual(2);
      expect(items[0].date).assertEqual('2026-03-16');
      expect(items[0].duration).assertEqual('00:30:00');
      expect(items[0].quality).assertEqual('1080p');
      expect(items[0].abnormalCount).assertEqual(1);
      expect(items[1].duration).assertEqual('00:20:00');
      expect(items[1].quality).assertEqual('720p');
    });

    it('buildKeyframesByDate_matches_demo_screen_data', 0, () => {
      let items = FrontendSimNodeService.getInstance().buildKeyframesByDate('2026-03-16');
      expect(items.length).assertEqual(2);
      expect(items[0].label).assertEqual('叶片病害');
      expect(items[0].abnormalType).assertEqual('叶片病害');
      expect(items[0].confidence).assertEqual(95);
      expect(items[0].thumbnailHint).assertEqual('sim_video_placeholder');
      expect(items[1].label).assertEqual('虫害检测');
      expect(items[1].severity).assertEqual('critical');
      expect(items[1].captureTime).assertEqual('2026-03-16T14:20:00');
    });
  });
}