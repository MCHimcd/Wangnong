import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';
import { HttpService } from './HttpService';

export class VideoMonitorService {
  private static instance: VideoMonitorService;

  public static getInstance(): VideoMonitorService {
    if (!VideoMonitorService.instance) {
      VideoMonitorService.instance = new VideoMonitorService();
    }
    return VideoMonitorService.instance;
  }

  async getLiveStreamInfo(nodeId: string): Promise<LiveStreamInfo> {
    let res = await HttpService.getInstance().getCameraLive(nodeId);
    if (res && res.data) {
      return res.data;
    }
    throw new Error('直播流信息获取失败，请检查后端连接');
  }

  async getDailyPlaybackList(nodeId: string): Promise<PlaybackItem[]> {
    let res = await HttpService.getInstance().getCameraPlayback(nodeId, '2026-03-16');
    if (res && res.data) {
      return res.data;
    }
    throw new Error('回放列表获取失败，请检查后端连接');
  }

  async getKeyframesByDate(nodeId: string, date: string): Promise<KeyframeImageItem[]> {
    let res = await HttpService.getInstance().getCameraKeyframes(nodeId, date);
    if (res && res.data) {
      return res.data;
    }
    throw new Error('关键帧获取失败，请检查后端连接');
  }
}
