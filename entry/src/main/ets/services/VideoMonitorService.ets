import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';
import { HttpService } from './HttpService';

/**
 * Purpose: 封装视频监控相关的 HTTP 调用，为页面提供直播、回放和关键帧数据。
 * Responsibilities: 维持单例入口、把 HttpService 的相机接口转换为更聚焦的视频领域方法，并在失败时抛出统一错误。
 * Flow: MonitorView 调用 getLiveStreamInfo()、getDailyPlaybackList() 和 getKeyframesByDate() 获取展示数据。
 * Dependencies: 依赖 HttpService 的相机接口和 VideoMonitorData 模型。
 * Input: 节点 ID，以及查询关键帧时的日期。
 * Output: 直播信息、每日回放列表和关键帧数组。
 * Boundary: 该文件只负责数据获取，不管理播放器状态与 UI 缓存。
 */
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
    // Boundary: 当前仍使用固定日期占位，后续若接入真实筛选条件，应从页面或服务层显式传入日期。
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
