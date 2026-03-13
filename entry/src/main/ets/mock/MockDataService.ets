import { SensorData } from '../models/SensorData';
import { DeviceState } from '../models/DeviceState';

export class MockDataService {
  private static instance: MockDataService;
  public sensorData: SensorData = new SensorData();
  public deviceState: DeviceState = new DeviceState();
  private timer: number = -1;

  private constructor() {
    this.sensorData.temperature = 25;
    this.sensorData.humidity = 60;
    this.sensorData.light = 5000;
    this.sensorData.co2 = 400;
    this.sensorData.soilTemp = 21;
    this.sensorData.soilHumidity = 52;
    this.sensorData.soilPh = 6.6;
  }

  public static getInstance(): MockDataService {
    if (!MockDataService.instance) {
      MockDataService.instance = new MockDataService();
    }
    return MockDataService.instance;
  }

  // 启动模拟数据，每秒更新
  public startMock(callback: (data: SensorData) => void) {
    this.timer = setInterval(() => {
      // 随机波动
      this.sensorData.temperature += (Math.random() - 0.5) * 0.5;
      this.sensorData.humidity += (Math.random() - 0.5) * 2;
      this.sensorData.light += (Math.random() - 0.5) * 100;
      this.sensorData.co2 += (Math.random() - 0.5) * 5;
      this.sensorData.soilTemp += (Math.random() - 0.5) * 0.4;
      this.sensorData.soilHumidity += (Math.random() - 0.5) * 1.8;
      this.sensorData.soilPh += (Math.random() - 0.5) * 0.06;

      if (this.sensorData.soilPh < 5.0) {
        this.sensorData.soilPh = 5.0;
      }
      if (this.sensorData.soilPh > 7.8) {
        this.sensorData.soilPh = 7.8;
      }

      callback(this.sensorData);
    }, 2000);
  }

  public stopMock() {
    if (this.timer !== -1) {
      clearInterval(this.timer);
    }
  }
}
