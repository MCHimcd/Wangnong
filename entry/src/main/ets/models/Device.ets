import { SensorData } from './SensorData';
import { DeviceState } from './DeviceState';
import { SensorMetaItem } from './SensorMeta';
import { EquipmentMetaItem } from './EquipmentMeta';

@Observed
export class Device {
  id: string;
  name: string;
  sensorData: SensorData;
  deviceState: DeviceState;
  sensorMeta: SensorMetaItem[] = [];
  equipmentMeta: EquipmentMetaItem[] = [];

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
    this.sensorData = new SensorData();
    this.deviceState = new DeviceState();
  }
}
