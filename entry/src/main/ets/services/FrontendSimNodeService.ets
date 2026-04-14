import { AlertData } from '../models/AlertData';
import { Node } from '../models/Node';
import { SensorMetaItem } from '../models/SensorMeta';
import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';
import { AlertSyncService } from './AlertSyncService';
import { MqttClientService } from './MqttClientService';

/**
 * Purpose: 在前端本地生成 SIM_Node_01 的环境遥测、设备快照、视频回退数据与阈值告警。
 * Responsibilities: 以 1 秒节奏驱动固定演示场景，向 MqttClientService 注入本地 telemetry，并在阈值越界时推送本地告警。
 * Flow: Index 调用 start(node) 后启动定时器；每轮先生成环境数据，再读取当前 NodeState 组装 telemetry，最后依据 sensorMeta 判定是否产生本地告警。
 * Dependencies: Node、AlertSyncService、MqttClientService、VideoMonitorData。
 * Input: 当前 SIM 节点的 Node 状态、阈值元数据和设备状态。
 * Output: 本地 telemetry JSON、本地告警和视频回退数据。
 * Boundary: 仅服务于 SIM_Node_01；不替代后端阈值持久化，只负责前端展示与本地演示数据生成。
 */

class SimTelemetryData {
  environment: Record<string, number> = {};
  equipment: Record<string, number | boolean> = {};
  mode: boolean = false;
}

class SimTelemetryPayload {
  msg_type: string = 'telemetry';
  node_id: string = '';
  timestamp: number = 0;
  source: string = 'frontend_sim';
  data: SimTelemetryData = new SimTelemetryData();
}

export class FrontendSimNodeService {
  private static instance: FrontendSimNodeService;
  private static readonly DEMO_NODE_ID: string = 'SIM_Node_01';
  private timerId: number = -1;
  private telemetryTick: number = 0;
  private node: Node | null = null;
  private activeViolations: Record<string, boolean> = {};

  private constructor() {}

  public static getInstance(): FrontendSimNodeService {
    if (!FrontendSimNodeService.instance) {
      FrontendSimNodeService.instance = new FrontendSimNodeService();
    }
    return FrontendSimNodeService.instance;
  }

  public isManagedNode(nodeId: string): boolean {
    return nodeId === FrontendSimNodeService.DEMO_NODE_ID;
  }

  public start(node: Node): void {
    if (!this.isManagedNode(node.id)) {
      return;
    }

    this.node = node;
    this.activeViolations = {};
    this.telemetryTick = 0;
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }

    this.emitTelemetry();
    this.timerId = setInterval(() => {
      this.emitTelemetry();
    }, 1000);
  }

  public stop(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.node = null;
    this.activeViolations = {};
  }

  public previewEnvironmentAtTick(tick: number): Record<string, number> {
    let phase = tick % 20;
    let env: Record<string, number> = {};

    if (phase >= 4 && phase <= 6) {
      env['temperature'] = this.round1(33.2 + (phase - 4) * 0.4);
      env['humidity'] = this.round1(55.0 - (phase - 4) * 1.5);
      env['light'] = this.round1(1050.0 + (phase - 4) * 80.0);
      env['co2'] = this.round1(520.0 + (phase - 4) * 20.0);
      env['soilTemp'] = this.round1(23.0 + (phase - 4) * 0.5);
      env['soilHumidity'] = this.round1(63.0 - (phase - 4) * 1.5);
      env['soilPh'] = 6.6;
      env['soilN'] = 158.0;
      env['soilP'] = 162.0;
      env['soilK'] = 166.0;
      return env;
    }

    if (phase >= 7 && phase <= 9) {
      env['temperature'] = this.round1(24.5 + (phase - 7) * 0.4);
      env['humidity'] = this.round1(43.0 - (phase - 7) * 1.5);
      env['light'] = this.round1(180.0 - (phase - 7) * 25.0);
      env['co2'] = this.round1(430.0 - (phase - 7) * 5.0);
      env['soilTemp'] = this.round1(20.0 + (phase - 7) * 0.2);
      env['soilHumidity'] = this.round1(53.0 - (phase - 7) * 2.0);
      env['soilPh'] = 6.5;
      env['soilN'] = 156.0;
      env['soilP'] = 160.0;
      env['soilK'] = 164.0;
      return env;
    }

    if (phase >= 10 && phase <= 12) {
      env['temperature'] = this.round1(27.0 + (phase - 10) * 0.5);
      env['humidity'] = this.round1(57.0 - (phase - 10) * 1.5);
      env['light'] = this.round1(1680.0 + (phase - 10) * 70.0);
      env['co2'] = this.round1(435.0 + (phase - 10) * 4.0);
      env['soilTemp'] = this.round1(22.0 + (phase - 10) * 0.4);
      env['soilHumidity'] = this.round1(64.0 - (phase - 10) * 1.0);
      env['soilPh'] = 6.6;
      env['soilN'] = 159.0;
      env['soilP'] = 163.0;
      env['soilK'] = 167.0;
      return env;
    }

    if (phase >= 13 && phase <= 15) {
      env['temperature'] = this.round1(17.2 - (phase - 13) * 0.5);
      env['humidity'] = this.round1(66.0 - (phase - 13) * 1.2);
      env['light'] = this.round1(620.0 - (phase - 13) * 90.0);
      env['co2'] = this.round1(440.0 - (phase - 13) * 8.0);
      env['soilTemp'] = this.round1(17.5 - (phase - 13) * 0.6);
      env['soilHumidity'] = this.round1(69.0 - (phase - 13) * 1.5);
      env['soilPh'] = 6.7;
      env['soilN'] = 161.0;
      env['soilP'] = 165.0;
      env['soilK'] = 169.0;
      return env;
    }

    env['temperature'] = this.round1(24.8 + (phase % 4) * 0.4);
    env['humidity'] = this.round1(60.0 + (phase % 4) * 1.0);
    env['light'] = this.round1(900.0 + (phase % 4) * 60.0);
    env['co2'] = this.round1(425.0 + (phase % 4) * 7.0);
    env['soilTemp'] = this.round1(20.0 + (phase % 4) * 0.3);
    env['soilHumidity'] = this.round1(66.0 + (phase % 4) * 1.2);
    env['soilPh'] = 6.6;
    env['soilN'] = 160.0;
    env['soilP'] = 164.0;
    env['soilK'] = 168.0;
    return env;
  }

  public buildLiveStreamInfo(): LiveStreamInfo {
    let time = new Date();
    return {
      cameraId: 'sim-frontend-camera',
      cameraName: 'SIM 前端模拟摄像头',
      status: 'online',
      streamTag: '前端模拟',
      resolution: '1280x720',
      lastHeartbeat: `${time.getHours().toString().padStart(2, '0')}:${time.getMinutes().toString().padStart(2, '0')}:${time.getSeconds().toString().padStart(2, '0')}`,
      streamUrl: ''
    };
  }

  public buildPlaybackItems(): PlaybackItem[] {
    return [
      { id: 'sim_playback_01', date: '2026-03-16', duration: '00:30:00', quality: '1080p', available: true, abnormalCount: 1 },
      { id: 'sim_playback_02', date: '2026-03-16', duration: '00:20:00', quality: '720p', available: true, abnormalCount: 0 }
    ];
  }

  public buildKeyframesByDate(date: string): KeyframeImageItem[] {
    let items: KeyframeImageItem[] = [];
    items.push({
      id: `${date}_leaf_disease`,
      captureTime: `${date}T09:30:00`,
      label: '叶片病害',
      confidence: 95,
      thumbnailHint: 'sim_video_placeholder',
      isAbnormal: true,
      abnormalType: '叶片病害',
      severity: 'critical'
    });
    items.push({
      id: `${date}_pest_detection`,
      captureTime: `${date}T14:20:00`,
      label: '虫害检测',
      confidence: 92,
      thumbnailHint: 'sim_video_placeholder',
      isAbnormal: true,
      abnormalType: '虫害检测',
      severity: 'critical'
    });
    return items;
  }

  private emitTelemetry(): void {
    if (this.node === null) {
      return;
    }

    this.telemetryTick++;
    let payload = new SimTelemetryPayload();
    payload.node_id = this.node.id;
    payload.timestamp = Date.now();
    payload.data.environment = this.previewEnvironmentAtTick(this.telemetryTick);
    payload.data.equipment = this.collectEquipmentSnapshot(this.node);
    payload.data.mode = this.node.nodeState.smartMode;

    MqttClientService.getInstance().emitLocalTelemetry(this.node.id, JSON.stringify(payload));
    this.emitLocalAlerts(payload.data.environment, payload.timestamp);
  }

  private collectEquipmentSnapshot(node: Node): Record<string, number | boolean> {
    let snapshot: Record<string, number | boolean> = {};
    for (let i = 0; i < node.equipmentMeta.length; i++) {
      let key = node.equipmentMeta[i].key;
      if (node.equipmentMeta[i].controlType === 'slider' || key === 'led_light') {
        snapshot[key] = node.nodeState.getValue(key);
      } else {
        snapshot[key] = node.nodeState.getState(key);
      }
    }
    return snapshot;
  }

  private emitLocalAlerts(environment: Record<string, number>, timestamp: number): void {
    if (this.node === null) {
      return;
    }

    for (let i = 0; i < this.node.sensorMeta.length; i++) {
      let meta = this.node.sensorMeta[i];
      if (environment[meta.key] === undefined) {
        continue;
      }
      let violating = this.isViolating(meta, environment[meta.key]);
      let stateKey = `${this.node.id}_${meta.key}`;
      let previous = this.activeViolations[stateKey] ?? false;
      if (violating && !previous) {
        this.activeViolations[stateKey] = true;
        AlertSyncService.getInstance().upsertLocalAlert(this.createAlert(meta, environment[meta.key], timestamp));
      } else if (!violating) {
        this.activeViolations[stateKey] = false;
      }
    }
  }

  private isViolating(meta: SensorMetaItem, value: number): boolean {
    if (typeof meta.warningMax === 'number' && value > meta.warningMax) {
      return true;
    }
    if (typeof meta.warningMin === 'number' && value < meta.warningMin) {
      return true;
    }
    return false;
  }

  private createAlert(meta: SensorMetaItem, value: number, timestamp: number): AlertData {
    let alert = new AlertData();
    alert.alert_id = `SIM_LOCAL_${meta.key}_${timestamp}`;
    alert.type = `${meta.key}_alert`;
    alert.type_name = `${meta.name}异常`;
    alert.level = this.resolveAlertLevel(meta, value);
    alert.timestamp = timestamp;
    alert.message = this.buildAlertMessage(meta, value);
    alert.source = meta.key;
    alert.source_name = meta.name;
    return alert;
  }

  private resolveAlertLevel(meta: SensorMetaItem, value: number): string {
    if (typeof meta.warningMax === 'number' && value > meta.warningMax) {
      if (meta.key === 'temperature' || meta.key === 'co2') {
        return 'critical';
      }
    }
    if (typeof meta.warningMin === 'number' && value < meta.warningMin) {
      if (meta.key === 'temperature' || meta.key === 'soilHumidity') {
        return 'critical';
      }
    }
    return 'warning';
  }

  private buildAlertMessage(meta: SensorMetaItem, value: number): string {
    if (typeof meta.warningMax === 'number' && value > meta.warningMax) {
      return `${meta.name} ${value.toFixed(1)}${meta.unit} 超过阈值 ${meta.warningMax.toFixed(1)}${meta.unit}`;
    }
    if (typeof meta.warningMin === 'number' && value < meta.warningMin) {
      return `${meta.name} ${value.toFixed(1)}${meta.unit} 低于阈值 ${meta.warningMin.toFixed(1)}${meta.unit}`;
    }
    return `${meta.name} 当前值 ${value.toFixed(1)}${meta.unit}`;
  }

  private round1(value: number): number {
    return Math.round(value * 10) / 10;
  }
}