@Observed
export class DeviceState {
  waterValveOn: boolean = false; // 水阀状态
  waterPumpOn: boolean = false; // 水泵状态
  ledOn: boolean = false; // LED状态
  ledBrightness: number = 0; // LED亮度 (0-100)
  extensionOn: boolean = false; // 扩展设备
}
