import { Node } from '../models/Node';
import { SensorMetaItem } from '../models/SensorMeta';
import { FrontendSimNodeService } from './FrontendSimNodeService';
import { MqttClientService } from './MqttClientService';

/**
 * Purpose: 为 SIM_Node_01 提供固定演示规则的智能模式控制，让设备行为直接由当前阈值和实时遥测驱动。
 * Responsibilities: 读取共享 Node 状态、根据传感器阈值计算设备目标状态，并在状态翻转时下发 MQTT 控制命令。
 * Flow: Index 在处理完 telemetry 或阈值同步后调用 applyNode()；服务先 collectActions() 计算动作，再做本地乐观更新和命令入队。
 * Dependencies: Node、SensorMeta、MqttClientService。
 * Input: Demo 节点的 sensorData、sensorMeta、equipmentMeta 和 smartMode。
 * Output: 智能模式下的设备命令队列与本地 NodeState 更新。
 * Boundary: 仅对 SIM_Node_01 生效，且规则映射固定为演示用途，不提供运行时配置 UI。
 */

class SmartThresholdRule {
  sensorKey: string = '';
  equipmentKey: string = '';
  direction: string = 'high';
  controlType: string = 'toggle';
  onBrightness: number = 100;

  constructor(sensorKey: string, equipmentKey: string,
    direction: string, controlType: string = 'toggle') {
    this.sensorKey = sensorKey;
    this.equipmentKey = equipmentKey;
    this.direction = direction;
    this.controlType = controlType;
  }
}

export class SmartControlAction {
  sensorKey: string = '';
  equipmentKey: string = '';
  desiredOn: boolean = false;
  command: string = '';
  brightness: number = -1;
}

export class SmartControlService {
  private static instance: SmartControlService;
  private static readonly DEMO_NODE_ID: string = 'SIM_Node_01';
  private readonly rules: SmartThresholdRule[] = [
    new SmartThresholdRule('temperature', 'fan', 'high'),
    new SmartThresholdRule('temperature', 'heater', 'low'),
    new SmartThresholdRule('humidity', 'mist_sprayer', 'low'),
    new SmartThresholdRule('light', 'shade', 'high'),
    new SmartThresholdRule('light', 'led_light', 'low', 'slider'),
    new SmartThresholdRule('soilHumidity', 'water_pump', 'low'),
    new SmartThresholdRule('soilHumidity', 'water_valve', 'low'),
    new SmartThresholdRule('co2', 'ventilation', 'high')
  ];

  private constructor() {}

  public static getInstance(): SmartControlService {
    if (!SmartControlService.instance) {
      SmartControlService.instance = new SmartControlService();
    }
    return SmartControlService.instance;
  }

  public collectActions(node: Node): SmartControlAction[] {
    let actions: SmartControlAction[] = [];
    if (node.id !== SmartControlService.DEMO_NODE_ID || !node.nodeState.smartMode) {
      return actions;
    }

    for (let i = 0; i < this.rules.length; i++) {
      let rule = this.rules[i];
      if (!this.hasEquipment(node, rule.equipmentKey) || !node.sensorData.hasValue(rule.sensorKey)) {
        continue;
      }

      let meta = this.findSensorMeta(node, rule.sensorKey);
      if (meta === undefined) {
        continue;
      }

      let desiredOn = this.resolveDesiredOn(rule, meta, node.sensorData.getValue(rule.sensorKey));
      if (desiredOn === undefined || this.isStateAligned(node, rule, desiredOn)) {
        continue;
      }

      let action = new SmartControlAction();
      action.sensorKey = rule.sensorKey;
      action.equipmentKey = rule.equipmentKey;
      action.desiredOn = desiredOn;
      if (rule.controlType === 'slider') {
        action.command = 'set_brightness';
        action.brightness = desiredOn ? rule.onBrightness : 0;
      } else {
        action.command = desiredOn ? 'turn_on' : 'turn_off';
      }
      actions.push(action);
    }

    return actions;
  }

  public applyNode(node: Node): void {
    let actions = this.collectActions(node);
    for (let i = 0; i < actions.length; i++) {
      this.dispatchAction(node, actions[i]);
    }
  }

  private hasEquipment(node: Node, equipmentKey: string): boolean {
    for (let i = 0; i < node.equipmentMeta.length; i++) {
      if (node.equipmentMeta[i].key === equipmentKey) {
        return true;
      }
    }
    return false;
  }

  private findSensorMeta(node: Node, sensorKey: string): SensorMetaItem | undefined {
    for (let i = 0; i < node.sensorMeta.length; i++) {
      if (node.sensorMeta[i].key === sensorKey) {
        return node.sensorMeta[i];
      }
    }
    return undefined;
  }

  private resolveDesiredOn(rule: SmartThresholdRule, meta: SensorMetaItem,
    currentValue: number): boolean | undefined {
    if (rule.direction === 'high') {
      if (typeof meta.warningMax !== 'number') {
        return undefined;
      }
      return currentValue > meta.warningMax;
    }
    if (typeof meta.warningMin !== 'number') {
      return undefined;
    }
    return currentValue < meta.warningMin;
  }

  private isStateAligned(node: Node, rule: SmartThresholdRule, desiredOn: boolean): boolean {
    if (rule.controlType === 'slider') {
      let currentBrightness = node.nodeState.getValue(rule.equipmentKey);
      return desiredOn ? currentBrightness > 0 : currentBrightness === 0;
    }
    return node.nodeState.getState(rule.equipmentKey) === desiredOn;
  }

  private dispatchAction(node: Node, action: SmartControlAction): void {
    if (action.command === 'set_brightness') {
      let params: Record<string, number> = {};
      params['brightness'] = action.brightness;
      node.nodeState.setValue(action.equipmentKey, action.brightness);
      node.nodeState.markCommandSent(action.equipmentKey);
      if (FrontendSimNodeService.getInstance().isManagedNode(node.id)) {
        return;
      }
      MqttClientService.getInstance().enqueueCommand(
        node.id,
        action.equipmentKey,
        action.command,
        params,
        'smart'
      );
      return;
    }

    node.nodeState.setState(action.equipmentKey, action.desiredOn);
    node.nodeState.markCommandSent(action.equipmentKey);
    if (FrontendSimNodeService.getInstance().isManagedNode(node.id)) {
      return;
    }
    MqttClientService.getInstance().enqueueCommand(
      node.id,
      action.equipmentKey,
      action.command,
      undefined,
      'smart'
    );
  }
}