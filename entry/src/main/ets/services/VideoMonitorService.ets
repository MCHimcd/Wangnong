import { MockVideoProvider } from '../mock/MockVideoProvider';
import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';

export class VideoMonitorService {
  private static instance: VideoMonitorService;

  public static getInstance(): VideoMonitorService {
    if (!VideoMonitorService.instance) {
      VideoMonitorService.instance = new VideoMonitorService();
    }
    return VideoMonitorService.instance;
  }

  async getLiveStreamInfo(deviceId: string): Promise<LiveStreamInfo> {
    // 预留：后续替换为真实接口调用
    return MockVideoProvider.getLiveStreamInfo(deviceId);
  }

  async getDailyPlaybackList(_deviceId: string): Promise<PlaybackItem[]> {
    // 预留：后续按设备和日期过滤
    return MockVideoProvider.getDailyPlaybackList();
  }

  async getKeyframesByDate(_deviceId: string, date: string): Promise<KeyframeImageItem[]> {
    // 预留：后续按设备和日期查询关键帧
    return MockVideoProvider.getKeyframesByDate(date);
  }
}
