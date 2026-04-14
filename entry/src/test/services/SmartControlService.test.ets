/**
 * Purpose: 约束 SIM_Node_01 智能模式的固定演示规则，确保自动控制严格依赖当前阈值与实时遥测。
 * Responsibilities: 验证智能模式开关、演示节点过滤、不同传感器到设备的规则映射，以及阈值变更后的即时判定。
 * Flow: 通过构造 Node + sensorMeta + equipmentMeta + sensorData，调用 SmartControlService 收集动作并断言结果。
 * Dependencies: Node、SensorMetaItem、EquipmentMetaItem、MqttClientService、SmartControlService。
 * Boundary: 这里只验证前端规则引擎，不验证真实 MQTT 发布成功与后端响应。
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { Node } from '../../main/ets/models/Node';
import { SensorMetaItem } from '../../main/ets/models/SensorMeta';
import { EquipmentMetaItem } from '../../main/ets/models/EquipmentMeta';
import { SmartControlService } from '../../main/ets/services/SmartControlService';
import { MqttClientService } from '../../main/ets/services/MqttClientService';

class TestSensorMetaItem implements SensorMetaItem {
  key: string;
  name: string;
  unit: string;
  icon: string;
  badgeColor: string;
  bgColor: string;
  warningMin?: number;
  warningMax?: number;

  constructor(key: string, name: string, unit: string, warningMin?: number, warningMax?: number) {
    this.key = key;
    this.name = name;
    this.unit = unit;
    this.icon = '';
    this.badgeColor = '#4CAF50';
    this.bgColor = '#E8F5E9';
    this.warningMin = warningMin;
    this.warningMax = warningMax;
  }
}

class TestEquipmentMetaItem implements EquipmentMetaItem {
  key: string;
  name: string;
  icon: string;
  controllable: boolean;
  controlType: string;

  constructor(key: string, name: string, controlType: string = 'toggle') {
    this.key = key;
    this.name = name;
    this.icon = '';
    this.controllable = true;
    this.controlType = controlType;
  }
}

function createDemoNode(): Node {
  let node = new Node('SIM_Node_01', '温室节点 3', 'online');
  node.sensorMeta = [
    new TestSensorMetaItem('temperature', '空气温度', '℃', 18, 32),
    new TestSensorMetaItem('humidity', '空气湿度', '%', 45, 75),
    new TestSensorMetaItem('light', '光照强度', 'Lux', 200, 1600),
    new TestSensorMetaItem('soilHumidity', '土壤湿度', '%', 55, 85),
    new TestSensorMetaItem('co2', 'CO2 浓度', 'ppm', 350, 500)
  ];
  node.equipmentMeta = [
    new TestEquipmentMetaItem('fan', '排风扇'),
    new TestEquipmentMetaItem('heater', '加热器'),
    new TestEquipmentMetaItem('mist_sprayer', '喷雾器'),
    new TestEquipmentMetaItem('shade', '遮阳帘'),
    new TestEquipmentMetaItem('led_light', '补光灯', 'slider'),
    new TestEquipmentMetaItem('water_pump', '水泵'),
    new TestEquipmentMetaItem('water_valve', '水阀'),
    new TestEquipmentMetaItem('ventilation', '通风窗')
  ];
  node.nodeState.smartMode = true;
  node.nodeState.setState('fan', false);
  node.nodeState.setState('heater', false);
  node.nodeState.setState('mist_sprayer', false);
  node.nodeState.setState('shade', false);
  node.nodeState.setValue('led_light', 0);
  node.nodeState.setState('water_pump', false);
  node.nodeState.setState('water_valve', false);
  node.nodeState.setState('ventilation', false);
  return node;
}

export default function smartControlServiceTest() {
  describe('SmartControlService', () => {
    let service: SmartControlService;

    beforeEach(() => {
      service = SmartControlService.getInstance();
      MqttClientService.getInstance().clearCommandQueue();
    });

    it('collectActions_manual_mode_returns_empty', 0, () => {
      let node = createDemoNode();
      node.nodeState.smartMode = false;
      node.sensorData.setValue('temperature', 35);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(0);
    });

    it('collectActions_non_demo_node_returns_empty', 0, () => {
      let node = createDemoNode();
      node.id = 'A03_Node_01';
      node.sensorData.setValue('temperature', 35);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(0);
    });

    it('collectActions_temperature_above_max_turns_on_fan', 0, () => {
      let node = createDemoNode();
      node.sensorData.setValue('temperature', 33.5);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(1);
      expect(actions[0].equipmentKey).assertEqual('fan');
      expect(actions[0].command).assertEqual('turn_on');
    });

    it('collectActions_temperature_back_to_safe_turns_off_fan', 0, () => {
      let node = createDemoNode();
      node.nodeState.setState('fan', true);
      node.sensorData.setValue('temperature', 30);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(1);
      expect(actions[0].equipmentKey).assertEqual('fan');
      expect(actions[0].command).assertEqual('turn_off');
    });

    it('collectActions_soil_humidity_below_min_turns_on_irrigation_pair', 0, () => {
      let node = createDemoNode();
      node.sensorData.setValue('soilHumidity', 48);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(2);
      expect(actions[0].equipmentKey).assertEqual('water_pump');
      expect(actions[0].command).assertEqual('turn_on');
      expect(actions[1].equipmentKey).assertEqual('water_valve');
      expect(actions[1].command).assertEqual('turn_on');
    });

    it('collectActions_low_light_turns_on_led_with_brightness', 0, () => {
      let node = createDemoNode();
      node.sensorData.setValue('light', 160);

      let actions = service.collectActions(node);

      expect(actions.length).assertEqual(1);
      expect(actions[0].equipmentKey).assertEqual('led_light');
      expect(actions[0].command).assertEqual('set_brightness');
      expect(actions[0].brightness).assertEqual(100);
    });

    it('collectActions_threshold_change_updates_decision_immediately', 0, () => {
      let node = createDemoNode();
      node.sensorData.setValue('co2', 480);

      let safeActions = service.collectActions(node);
      expect(safeActions.length).assertEqual(0);

      node.sensorMeta = [
        new TestSensorMetaItem('temperature', '空气温度', '℃', 18, 32),
        new TestSensorMetaItem('humidity', '空气湿度', '%', 45, 75),
        new TestSensorMetaItem('light', '光照强度', 'Lux', 200, 1600),
        new TestSensorMetaItem('soilHumidity', '土壤湿度', '%', 55, 85),
        new TestSensorMetaItem('co2', 'CO2 浓度', 'ppm', 350, 450)
      ];

      let thresholdChangedActions = service.collectActions(node);

      expect(thresholdChangedActions.length).assertEqual(1);
      expect(thresholdChangedActions[0].equipmentKey).assertEqual('ventilation');
      expect(thresholdChangedActions[0].command).assertEqual('turn_on');
    });

    it('applyNode_frontend_managed_updates_local_state_without_backend_queue', 0, () => {
      let node = createDemoNode();
      node.sensorData.setValue('humidity', 40);

      service.applyNode(node);

      expect(node.nodeState.getState('mist_sprayer')).assertTrue();
      expect(MqttClientService.getInstance().getCommandQueueLength()).assertEqual(0);
      MqttClientService.getInstance().clearCommandQueue();
    });
  });
}