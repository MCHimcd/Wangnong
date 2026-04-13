import { SensorData } from './SensorData';
import { NodeState } from './NodeState';
import { SensorMetaItem } from './SensorMeta';
import { EquipmentMetaItem } from './EquipmentMeta';

/**
 * Purpose: 聚合单个温室节点在前端运行所需的实时状态、元数据和显示名称。
 * Responsibilities: 绑定节点标识、在线状态、传感器数据、控制状态及对应元数据。
 * Flow: Index 创建 Node 实例后，HTTP 补充元数据，MQTT 持续更新 sensorData 与 nodeState。
 * Dependencies: 依赖 SensorData、NodeState、SensorMetaItem 和 EquipmentMetaItem。
 * Input: 节点基础信息和运行中的实时更新。
 * Output: 可被首页、监控视图和详情页直接绑定的 @Observed 节点对象。
 */
@Observed
export class Node {
  id: string;
  name: string;
  status: string = 'offline';
  sensorData: SensorData;
  nodeState: NodeState;
  sensorMeta: SensorMetaItem[] = [];
  equipmentMeta: EquipmentMetaItem[] = [];

  constructor(id: string, name: string, status: string = 'offline') {
    this.id = id;
    this.name = name;
    this.status = status;
    this.sensorData = new SensorData();
    this.nodeState = new NodeState();
  }
}
