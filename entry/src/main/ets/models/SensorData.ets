@Observed
export class SensorData {
  temperature: number = 0; // 空气温度
  humidity: number = 0; // 空气湿度
  light: number = 0; // 光照 (Lux)
  co2: number = 0; // 二氧化碳 (ppm)
  soilTemp: number = 0; // 土壤温度
  soilHumidity: number = 0; // 土壤湿度
  soilPh: number = 0; // 土壤 pH
}
