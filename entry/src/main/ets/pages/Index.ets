import { Device } from '../models/Device';
import { HomeView } from '../views/HomeView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';
import { MqttClientService } from '../services/MqttClientService';
import { AlertSyncService } from '../services/AlertSyncService';

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
  @Provide autoIrrigation: boolean = false;
  @Provide autoCooling: boolean = false;
  
  @Provide @Watch('onConnectionStatusChange') connectionStatus: 'connected' | 'mock' | 'disconnected' = 'mock';
  
  private lastAlertTime: number = 0;
  private mockTimer: number = -1;

  onConnectionStatusChange() {
    if (this.connectionStatus === 'mock') {
      if (this.mockTimer === -1) {
        this.mockTimer = setInterval(() => {
          this.devices.forEach(device => {
            device.sensorData.temperature = 22 + Math.random() * 10;
            device.sensorData.humidity = 40 + Math.random() * 40;
            device.sensorData.light = 1000 + Math.random() * 2000;
            device.sensorData.co2 = 380 + Math.random() * 100;
            device.sensorData.soilTemp = 16 + Math.random() * 12;
            device.sensorData.soilHumidity = 30 + Math.random() * 45;
            device.sensorData.soilPh = 5.5 + Math.random() * 1.5;

            let currentTime = new Date().getTime();
            if (currentTime - this.lastAlertTime > 10000 &&
              this.currentDeviceIndex === this.devices.indexOf(device)) {
              if (device.sensorData.humidity < this.humidThreshold && !device.deviceState.waterPumpOn) {
                promptAction.showToast({ message: '模拟：湿度过低！', duration: 2000 });
                AlertSyncService.getInstance().addRuntimeAlert({
                  alert_id: `RT_HUM_${device.id}_${currentTime}`,
                  type: 'humidity_low_runtime',
                  type_name: '空气湿度过低（实时）',
                  level: 'warning',
                  timestamp: currentTime,
                  message: `设备 ${device.name} 空气湿度降至 ${device.sensorData.humidity.toFixed(1)}%，建议及时补水。`,
                  source: 'environment',
                  source_name: '环境监测',
                  is_handled: false,
                  handle_time: null
                });
                if (this.autoIrrigation) {
                  device.deviceState.waterPumpOn = true;
                  promptAction.showToast({ message: '模拟：已自动开启水泵', duration: 2000 });
                }
                this.lastAlertTime = currentTime;
              } else if (device.sensorData.temperature > this.tempThreshold) {
                AlertSyncService.getInstance().addRuntimeAlert({
                  alert_id: `RT_TMP_${device.id}_${currentTime}`,
                  type: 'temp_high_runtime',
                  type_name: '高温异常（实时）',
                  level: 'critical',
                  timestamp: currentTime,
                  message: `设备 ${device.name} 温度达到 ${device.sensorData.temperature.toFixed(1)}°C，请及时降温。`,
                  source: 'environment',
                  source_name: '环境监测',
                  is_handled: false,
                  handle_time: null
                });
                if (this.autoCooling && !device.deviceState.fanOn) {
                  device.deviceState.fanOn = true;
                  promptAction.showToast({ message: '模拟：高温！已自动开启排风', duration: 2000 });
                }
                this.lastAlertTime = currentTime;
              }
            }
          });
        }, 3000);

        this.devices.forEach(device => {
          device.sensorData.temperature = 25;
          device.sensorData.humidity = 50;
          device.sensorData.light = 1500;
          device.sensorData.co2 = 400;
          device.sensorData.soilTemp = 22;
          device.sensorData.soilHumidity = 55;
          device.sensorData.soilPh = 6.5;
        });
      }
    } else {
      if (this.mockTimer !== -1) {
        clearInterval(this.mockTimer);
        this.mockTimer = -1;
      }
    }
  }

  aboutToAppear() {
    HttpService.getInstance().setDeviceId(this.devices[0].id);
    this.onConnectionStatusChange();
  }

  aboutToDisappear() {
    if (this.mockTimer !== -1) {
      clearInterval(this.mockTimer);
    }
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          HomeView({ 
            device: this.devices[this.currentDeviceIndex],
            devicesList: this.devices.map(d => d.name),
            currentDeviceIndex: this.currentDeviceIndex,
            onSwitchDevice: (idx: number) => {
              this.currentDeviceIndex = idx;
              HttpService.getInstance().setDeviceId(this.devices[idx].id);
            },
            onAddDevice: (name: string) => {
              this.devices.push(new Device('mock_id_' + Date.now(), name));
            }
          })
        }
        .tabBar(SubTabBarStyle.of('首页').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))

        TabContent() {
          AlertView()
        }
        .tabBar(SubTabBarStyle.of('消息').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))

        TabContent() {
          ProfileView()
        }
        .tabBar(SubTabBarStyle.of('我的').labelStyle({ selectedColor: '#4CAF50', unselectedColor: '#90A4AE' }))
      }
      .animationDuration(300)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
