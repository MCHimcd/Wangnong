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
}

export interface KeyframeImageItem {
  id: string;
  captureTime: string;
  label: string;
  confidence: number;
  thumbnailHint: string;
  isAbnormal: boolean;
  abnormalType: string;
  severity: AbnormalSeverity;
}
