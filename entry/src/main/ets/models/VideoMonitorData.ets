/**
 * Purpose: 描述视频监控模块使用的直播、回放和关键帧数据结构。
 * Responsibilities: 统一直播状态、回放列表、异常关键帧的字段形态，降低页面与服务之间的耦合。
 * Flow: VideoMonitorService 拉取后端数据后按这些接口返回，MonitorView 和相关页面直接渲染。
 * Dependencies: 被 VideoMonitorService、MonitorView 和视频相关页面共享。
 * Input: 后端视频接口返回的 JSON 数据。
 * Output: 受类型约束的直播/回放/关键帧对象。
 */
export type CameraOnlineStatus = 'online' | 'offline';
export type AbnormalSeverity = 'warning' | 'critical';

export interface LiveStreamInfo {
  cameraId: string;
  cameraName: string;
  status: CameraOnlineStatus;
  streamTag: string;
  resolution: string;
  lastHeartbeat: string;
  streamUrl: string;
}

export interface PlaybackItem {
  id: string;
  date: string;
  duration: string;
  quality: string;
  available: boolean;
  abnormalCount: number;
  videoUrl?: string;
}

export interface KeyframeImageItem {
  id: string;
  captureTime: string;
  label: string;
  confidence: number;
  thumbnailHint: string;
  imageUrl?: string;
  isAbnormal: boolean;
  abnormalType: string;
  severity: AbnormalSeverity;
}
