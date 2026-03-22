import { SensorData } from './SensorData';
import { NodeState } from './NodeState';
import { SensorMetaItem } from './SensorMeta';
import { EquipmentMetaItem } from './EquipmentMeta';

@Observed
export class Node {
  id: string;
  name: string;
  sensorData: SensorData;
  nodeState: NodeState;
  sensorMeta: SensorMetaItem[] = [];
  equipmentMeta: EquipmentMetaItem[] = [];

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
    this.sensorData = new SensorData();
    this.nodeState = new NodeState();
  }
}
