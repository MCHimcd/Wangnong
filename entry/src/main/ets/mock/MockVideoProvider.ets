import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';

export class MockVideoProvider {
  static getLiveStreamInfo(deviceId: string): LiveStreamInfo {
    return {
      cameraId: `${deviceId}_CAM_01`,
      cameraName: '温室主摄像头',
      status: 'online',
      streamTag: '主码流 1080P',
      resolution: '1920x1080',
      lastHeartbeat: '刚刚'
    };
  }

  static getDailyPlaybackList(): PlaybackItem[] {
    return [
      { id: 'play_2026_03_13', date: '2026-03-13', duration: '22:10', quality: '高清', available: true, abnormalCount: 4 },
      { id: 'play_2026_03_12', date: '2026-03-12', duration: '21:45', quality: '高清', available: true, abnormalCount: 3 },
      { id: 'play_2026_03_11', date: '2026-03-11', duration: '18:30', quality: '标清', available: true, abnormalCount: 1 },
      { id: 'play_2026_03_10', date: '2026-03-10', duration: '00:00', quality: '待生成', available: false, abnormalCount: 0 }
    ];
  }

  static getKeyframesByDate(date: string): KeyframeImageItem[] {
    if (date.length === 0) {
      return [];
    }

    return [
      {
        id: `${date}_kf_01`,
        captureTime: '08:15',
        label: '疑似叶片病斑',
        confidence: 92.3,
        thumbnailHint: '🧫',
        isAbnormal: true,
        abnormalType: '叶片病斑',
        severity: 'warning'
      },
      {
        id: `${date}_kf_02`,
        captureTime: '10:40',
        label: '灌溉管路渗漏',
        confidence: 88.4,
        thumbnailHint: '💧',
        isAbnormal: true,
        abnormalType: '设备渗漏',
        severity: 'warning'
      },
      {
        id: `${date}_kf_03`,
        captureTime: '13:05',
        label: '人员闯入告警',
        confidence: 95.1,
        thumbnailHint: '🚨',
        isAbnormal: true,
        abnormalType: '入侵事件',
        severity: 'critical'
      },
      {
        id: `${date}_kf_04`,
        captureTime: '16:20',
        label: '果实霉斑疑似',
        confidence: 90.6,
        thumbnailHint: '🍅',
        isAbnormal: true,
        abnormalType: '果实异常',
        severity: 'warning'
      }
    ];
  }
}
