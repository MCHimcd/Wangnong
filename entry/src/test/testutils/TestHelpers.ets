/**
 * 测试数据工厂 & 通用断言辅助
 * ArkTS 禁止无类型对象字面量，所有测试数据必须通过工厂方法创建 class 实例。
 */
import { AlertData } from '../../main/ets/models/AlertData';
import { SensorData } from '../../main/ets/models/SensorData';
import { NodeState } from '../../main/ets/models/NodeState';
import { Node } from '../../main/ets/models/Node';
import { CachedTrendPoint } from '../../main/ets/services/MqttClientService';

// ========== Alert 工厂 ==========

export function createMockAlert(id: string, level: string = 'warning', timestamp: number = 1711900000): AlertData {
  let alert = new AlertData();
  alert.alert_id = id;
  alert.type = 'temp_high';
  alert.type_name = '温度过高';
  alert.level = level;
  alert.timestamp = timestamp;
  alert.message = `测试告警 ${id}`;
  alert.source = 'environment';
  alert.source_name = '环境监测';
  alert.is_handled = false;
  alert.handle_time = null;
  return alert;
}

export function createHandledAlert(id: string, timestamp: number = 1711900000): AlertData {
  let alert = createMockAlert(id, 'warning', timestamp);
  alert.is_handled = true;
  alert.handle_time = timestamp + 60000;
  return alert;
}

// ========== Telemetry JSON 工厂 ==========

export function createTelemetryJson(nodeId: string, temperature: number = 25.3, humidity: number = 68): string {
  return `{"msg_type":"telemetry","node_id":"${nodeId}","timestamp":${Date.now()},"data":{"environment":{"temperature":${temperature},"humidity":${humidity}},"equipment":{"water_pump":true,"fan":false,"led_light":75},"mode":true}}`;
}

export function createAlertJson(nodeId: string, alertId: string, level: string = 'critical'): string {
  return `{"msg_type":"alert","node_id":"${nodeId}","timestamp":${Date.now()},"data":{"alert_id":"${alertId}","type":"temp_high","type_name":"温度过高","level":"${level}","timestamp":${Date.now()},"message":"测试告警","source":"environment","source_name":"环境监测","is_handled":false,"handle_time":null}}`;
}

// ========== SensorData 工厂 ==========

export function createMockSensorData(): SensorData {
  let sd = new SensorData();
  sd.setValue('temperature', 25.3);
  sd.setValue('humidity', 68);
  return sd;
}

// ========== NodeState 工厂 ==========

export function createMockNodeState(): NodeState {
  let ns = new NodeState();
  ns.setState('water_pump', true);
  ns.setState('fan', false);
  return ns;
}

// ========== Node 工厂 ==========

export function createMockNode(id: string = 'A03_Node_01', name: string = '测试节点'): Node {
  return new Node(id, name);
}

// ========== CachedTrendPoint 工厂 ==========

export function createMockTrendPoints(count: number, baseValue: number = 25.0): CachedTrendPoint[] {
  let points: CachedTrendPoint[] = [];
  for (let i = 0; i < count; i++) {
    let time = `${String(Math.floor(i / 60)).padStart(2, '0')}:${String(i % 60).padStart(2, '0')}:00`;
    points.push(new CachedTrendPoint(time, baseValue + i * 0.1));
  }
  return points;
}
