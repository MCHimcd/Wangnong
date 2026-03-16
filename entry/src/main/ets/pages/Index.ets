import { Device } from '../models/Device';
import { HomeView } from '../views/HomeView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';
import { DeviceListItem, HttpService } from '../services/HttpService';
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
  
  @Provide connectionStatus: 'connected' | 'disconnected' = 'disconnected';

  private async loadDevicesFromServer() {
    const remoteDevices = await HttpService.getInstance().getDevices();
    if (!remoteDevices || remoteDevices.length === 0) {
      return;
    }

    this.devices = remoteDevices.map((item: DeviceListItem) => {
      return new Device(item.id, item.name);
    });

    if (this.currentDeviceIndex >= this.devices.length) {
      this.currentDeviceIndex = 0;
    }
  }

  async aboutToAppear() {
    await this.loadDevicesFromServer();
    HttpService.getInstance().setDeviceId(this.devices[this.currentDeviceIndex].id);

    MqttClientService.getInstance().connect(
      'tcp://broker.emqx.io:1883',
      'app_client_' + new Date().getTime(),
      (deviceId, msgStr) => {
        try {
          const payload = JSON.parse(msgStr) as Record<string, Object | string | number | boolean>;
          if (payload['data']) {
            const data = payload['data'] as Record<string, Object | string | number | boolean>;
            this.devices.forEach(device => {
              if (device.id === deviceId) {
                if (data['environment']) {
                  const env = data['environment'] as Record<string, number>;
                  if (env['temperature'] !== undefined) device.sensorData.temperature = env['temperature'];
                  if (env['humidity'] !== undefined) device.sensorData.humidity = env['humidity'];
                  if (env['light'] !== undefined) device.sensorData.light = env['light'];
                  if (env['co2'] !== undefined) device.sensorData.co2 = env['co2'];
                  if (env['soilTemp'] !== undefined) device.sensorData.soilTemp = env['soilTemp'];
                  if (env['soilHumidity'] !== undefined) device.sensorData.soilHumidity = env['soilHumidity'];
                  if (env['soilPh'] !== undefined) device.sensorData.soilPh = env['soilPh'];
                }
                if (data['equipment']) {
                  const equip = data['equipment'] as Record<string, boolean | number>;
                  if (equip['water_pump'] !== undefined) device.deviceState.waterPumpOn = Boolean(equip['water_pump']);
                  if (equip['led_light'] !== undefined) device.deviceState.ledOn = Boolean(equip['led_light']);
                  if (equip['fan'] !== undefined) device.deviceState.fanOn = Boolean(equip['fan']);
                }
                if (data['mode'] !== undefined) {
                  const mode = data['mode'];
                  if (typeof mode === 'string') {
                    device.deviceState.smartMode = mode.toLowerCase() === 'smart';
                  } else if (typeof mode === 'boolean') {
                    device.deviceState.smartMode = mode;
                  }
                }
              }
            });
          }
        } catch (e) {
          console.error('[Index] Failed to parse MQTT message', e);
        }
      },
      (status, debugInfo) => {
        this.connectionStatus = status;
        console.info(`[Index] MQTT status changed: ${status}, info: ${debugInfo || ''}`);
      }
    );
    AlertSyncService.getInstance().startRealtimeSync();
  }

  aboutToDisappear() {
    AlertSyncService.getInstance().stopRealtimeSync();
    MqttClientService.getInstance().disconnect();
  }

  @StorageLink('currentTabIndex') currentTabIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex, controller: this.tabsController }) {
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
              this.devices.push(new Device('dev_' + Date.now(), name));
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
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
