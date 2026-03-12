@Observed
export class SensorData {
  temperature: number = 0; // 温度
  humidity: number = 0; // 湿度 (土壤/空气)
  light: number = 0; // 光照 (Lux)
  co2: number = 0; // 二氧化碳 (ppm)
}
