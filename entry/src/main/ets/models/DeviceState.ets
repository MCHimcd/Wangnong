@Observed
export class DeviceState {
  waterValveOn: boolean = false; // 水阀状态
  waterPumpOn: boolean = false; // 水泵状态
  ledOn: boolean = false; // LED状态
  fanOn: boolean = false; // 排风扇状态
  extensionOn: boolean = false; // 扩展设备
  smartMode: boolean = false; // 智能控制模式状态
  controlStateBootstrapped: boolean = false; // 控制页首次进入时是否已完成主动状态拉取
}
