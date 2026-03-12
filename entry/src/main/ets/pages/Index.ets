import { MqttClientService } from '../services/MqttClientService';
import { SensorData } from '../models/SensorData';
import { DeviceState } from '../models/DeviceState';
import { Device } from '../models/Device';
import { DashboardView } from '../views/DashboardView';
import { ControlView } from '../views/ControlView';
import { SettingsView } from '../views/SettingsView';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';

class ReceiveEnv {
  air_temp?: number;
  air_humidity?: number;
  soil_moisture?: number;
  light_intensity?: number;
  co2_ppm?: number;
  // fallback for old properties
  temperature?: number;
  humidity?: number;
  light?: number;
  co2?: number;
}

class ReceiveStatus {
  water_pump?: boolean;
  led_light?: boolean;
  led_brightness?: number;
  fan?: boolean;
  camera?: boolean;
}

class ReceivePayloadData {
  environment?: ReceiveEnv;
  equipment?: ReceiveStatus;
  equipment_status?: ReceiveStatus;
}

class ReceivePayload {
  msg_type?: string;
  device_id?: string;
  timestamp?: number;
  data?: ReceivePayloadData;
}

class AppOptionItem implements SelectOption {
  value: ResourceStr;

  constructor(value: string) {
    this.value = value;
  }
}

@Entry
@Component
struct Index {
  @State devices: Device[] = [
    new Device('A03_Node_01', '温室节点 1'),
    new Device('A03_Node_02', '温室节点 2')
  ];
  @State currentDeviceIndex: number = 0;
  @Provide tempThreshold: number = 30;
  @Provide humidThreshold: number = 40;
  @Provide autoIrrigation: boolean = false; // 新增全局状态：允许自动灌溉
  @Provide autoCooling: boolean = false; // 新增全局状态：允许自动降温排风
  @State connectionStatus: 'connected' | 'mock' | 'disconnected' = 'disconnected';
  @State mqttDebugMsg: string = '';
  private lastAlertTime: number = 0;

  aboutToAppear() {
    HttpService.getInstance().setDeviceId(this.devices[0].id);
    MqttClientService.getInstance()
      .connect('tcp://broker.emqx.io:1883', 'AppClient_' + new Date().getTime(), (deviceId: string, msgStr: string) => {
        let payload = JSON.parse(msgStr) as ReceivePayload;
        if (payload.msg_type === 'telemetry' && payload.data) {
          let actualDeviceId = payload.device_id || deviceId;
          let devList = this.devices.filter(d => d.id === actualDeviceId);
          if (devList.length > 0) {
            let device = devList[0];

            let env = payload.data.environment;
            if (env) {
              device.sensorData.temperature = env.air_temp !== undefined ? env.air_temp : (env.temperature || 0);
              // 这里用土壤湿度来更新界面的湿度展示，因为通常大棚更关注土壤湿度，也可以用 air_humidity
              device.sensorData.humidity = env.soil_moisture !== undefined ? env.soil_moisture : (env.humidity || 0);
              device.sensorData.light = env.light_intensity !== undefined ? env.light_intensity : (env.light || 0);
              device.sensorData.co2 = env.co2_ppm !== undefined ? env.co2_ppm : (env.co2 || 0);

              let currentTime = new Date().getTime();
              if (currentTime - this.lastAlertTime > 10000 &&
                this.currentDeviceIndex === this.devices.indexOf(device)) {
                if (device.sensorData.humidity < this.humidThreshold && !device.deviceState.waterPumpOn) {
                  promptAction.showToast({
                    message: ` 警告：当前设备(${device.name})土壤湿度(${(device.sensorData.humidity).toFixed(0)}%)低于最低灌溉阈值！`,
                    duration: 3000
                  });

                  // 自动控制逻辑：触发水泵并同时更新自身UI状态
                  if (this.autoIrrigation) {
                    let param: Record<string, number> = { "duration_seconds": 15 };
                    MqttClientService.getInstance().publishCommand(device.id, 'water_pump', 'turn_on', param);
                    device.deviceState.waterPumpOn = true;
                    promptAction.showToast({ message: ' 已为您自动开启灌溉水泵', duration: 2000 });
                  }

                  this.lastAlertTime = currentTime;
                } else if (device.sensorData.temperature > this.tempThreshold) {
                  promptAction.showToast({
                    message: ` 高温提示：当前设备(${device.name})环境温度(${(device.sensorData.temperature).toFixed(1)}C)超出警戒线！`,
                    duration: 3000
                  });

                  // 自动控制逻辑：触发风扇并同时更新自身UI状态
                  if (this.autoCooling && !device.deviceState.extensionOn) {
                    MqttClientService.getInstance().publishCommand(device.id, 'fan', 'turn_on');
                    device.deviceState.extensionOn = true;
                    promptAction.showToast({ message: ' 已为您自动开启排风降温', duration: 2000 });
                  }

                  this.lastAlertTime = currentTime;
                }
              }
            }

            let status = payload.data.equipment_status || payload.data.equipment;
            if (status) {
              if (status.water_pump !== undefined) {
                device.deviceState.waterPumpOn = !!status.water_pump;
              }
              if (status.led_light !== undefined) {
                device.deviceState.ledOn = !!status.led_light;
              }
              if (status.led_brightness !== undefined) {
                device.deviceState.ledBrightness = status.led_brightness;
              }
              if (status.fan !== undefined) {
                device.deviceState.extensionOn = !!status.fan;
              }
              if (status.camera !== undefined) {
                device.deviceState.extensionOn =
                  !!status.camera;
              } // assuming ai_camera is tracked by extensionOn or similar wait YOLO is camera
            }
          }
        }
      }, (status, debugInfo) => {
        this.connectionStatus = status;
        if (debugInfo) {
          this.mqttDebugMsg = debugInfo;
        }
      });
  }

  aboutToDisappear() {
    MqttClientService.getInstance().disconnect();
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.startIcon')).width(24).height(24).fillColor('#4CAF50')
        Text('当前节点:').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2C3E50').margin({ left: 8 })
        Select(this.devices.map((v) => new AppOptionItem(v.name)))
          .selected(this.currentDeviceIndex)
          .value(this.devices[this.currentDeviceIndex].name)
          .font({ size: 16, weight: FontWeight.Medium })
          .fontColor('#4CAF50')
          .selectedOptionFont({ size: 16, weight: FontWeight.Bold })
          .selectedOptionFontColor('#4CAF50')
          .backgroundColor('transparent')
          .onSelect((index: number) => {
            this.currentDeviceIndex = index;
            HttpService.getInstance().setDeviceId(this.devices[this.currentDeviceIndex].id);
          })
          .margin({ left: 10 })
        Blank()
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.connectionStatus === 'connected' ? '#4CAF50' :
              (this.connectionStatus === 'mock' ? '#FF9800' : '#F44336'))
            .margin({ right: 4 })
          Text(this.connectionStatus === 'connected' ? '云端在线' :
            (this.connectionStatus === 'mock' ? '模拟模式' : '离线'))
            .fontSize(12)
            .fontColor(this.connectionStatus === 'connected' ? '#4CAF50' :
              (this.connectionStatus === 'mock' ? '#FF9800' : '#F44336'))
        }
        .padding({
          left: 8,
          right: 8,
          top: 4,
          bottom: 4
        })
        .backgroundColor(this.connectionStatus === 'connected' ? '#E8F5E9' :
          (this.connectionStatus === 'mock' ? '#FFF3E0' : '#FFEBEE'))
        .borderRadius(12)
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 15,
        bottom: 15
      })
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 10, color: 'rgba(76, 175, 80, 0.05)', offsetY: 4 })

      if (this.mqttDebugMsg) {
        Text(`DEBUG: ${this.mqttDebugMsg}`)
          .fontSize(10)
          .fontColor('#FF0000')
          .padding({ left: 20, right: 20, bottom: 5 })
          .width('100%')
      }

      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          DashboardView({ sensorData: this.devices[this.currentDeviceIndex].sensorData })
        }
        .tabBar(SubTabBarStyle.of('监控').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))

        TabContent() {
          ControlView({
            deviceId: this.devices[this.currentDeviceIndex].id,
            deviceState: this.devices[this.currentDeviceIndex].deviceState
          })
        }
        .tabBar(SubTabBarStyle.of('控制').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))

        TabContent() {
          SettingsView()
        }
        .tabBar(SubTabBarStyle.of('设置').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))
      }
      .animationDuration(300)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
