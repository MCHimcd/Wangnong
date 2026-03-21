import { Device } from '../models/Device';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { HomeView } from '../views/HomeView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';
import { DeviceListItem, HttpService } from '../services/HttpService';
import { MqttClientService } from '../services/MqttClientService';
import { AlertSyncService } from '../services/AlertSyncService';
import { AlertData } from '../models/AlertData';
import { AppConfig } from '../common/AppConfig';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

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

  private async loadMetaForAllDevices(): Promise<void> {
    const httpService = HttpService.getInstance();
    for (let i = 0; i < this.devices.length; i++) {
      const device = this.devices[i];
      const sMeta = await httpService.getSensorMeta(device.id);
      if (sMeta) {
        device.sensorMeta = sMeta;
      }
      const eMeta = await httpService.getEquipmentMeta(device.id);
      if (eMeta) {
        device.equipmentMeta = eMeta;
      }
    }
  }

  async aboutToAppear() {
    await this.loadDevicesFromServer();
    HttpService.getInstance().setDeviceId(this.devices[this.currentDeviceIndex].id);
    await this.loadMetaForAllDevices();

    MqttClientService.getInstance().connect(
      AppConfig.MQTT_BROKER_URL,
      AppConfig.MQTT_CLIENT_PREFIX + new Date().getTime(),
      (deviceId, msgStr) => {
        try {
          const payload = JSON.parse(msgStr) as Record<string, Object | string | number | boolean>;
          if (payload['data']) {
            const data = payload['data'] as Record<string, Object | string | number | boolean>;
            this.devices.forEach(device => {
              if (device.id === deviceId) {
                if (data['environment']) {
                  const env = data['environment'] as Record<string, number>;
                  const envKeys = Object.keys(env);
                  for (let i = 0; i < envKeys.length; i++) {
                    device.sensorData.setValue(envKeys[i], env[envKeys[i]]);
                  }
                }
                if (data['equipment']) {
                  const equip = data['equipment'] as Record<string, boolean | number>;
                  const equipKeys = Object.keys(equip);
                  for (let i = 0; i < equipKeys.length; i++) {
                    device.deviceState.setState(equipKeys[i], Boolean(equip[equipKeys[i]]));
                  }
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
    AlertSyncService.getInstance().setAlertDialogCallback((alert: AlertData) => {
      promptAction.showDialog({
        title: '新告警提示',
        message: `检测到新告警（最新：${alert.type_name}），是否立即查看？`,
        buttons: [
          { text: '稍后处理', color: '#90A4AE' },
          { text: '立即查看', color: '#D84315' }
        ]
      }).then((res) => {
        if (res.index === 1) {
          this.currentTabIndex = 1;
        }
      }).catch(() => {});
    });
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
