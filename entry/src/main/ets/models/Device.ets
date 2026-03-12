import { SensorData } from './SensorData';
import { DeviceState } from './DeviceState';

@Observed
export class Device {
  id: string;
  name: string;
  sensorData: SensorData;
  deviceState: DeviceState;

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
    this.sensorData = new SensorData();
    this.deviceState = new DeviceState();
  }
}
