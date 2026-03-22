import { Node } from '../models/Node';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { HomeView } from '../views/HomeView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';
import { NodeListItem, HttpService } from '../services/HttpService';
import { MqttClientService } from '../services/MqttClientService';
import { AlertSyncService } from '../services/AlertSyncService';
import { AlertData } from '../models/AlertData';
import { AppConfig } from '../common/AppConfig';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State nodes: Node[] = [
    new Node('A03_Node_01', '温室节点 1'),
    new Node('A03_Node_02', '温室节点 2')
  ];
  @State currentNodeIndex: number = 0;
  @Provide tempThreshold: number = 30;
  @Provide humidThreshold: number = 40;
  @Provide autoIrrigation: boolean = false;
  @Provide autoCooling: boolean = false;
  
  @Provide connectionStatus: 'connected' | 'disconnected' = 'disconnected';

  private async loadNodesFromServer() {
    const remoteNodes = await HttpService.getInstance().getNodes();
    if (!remoteNodes || remoteNodes.length === 0) {
      return;
    }

    this.nodes = remoteNodes.map((item: NodeListItem) => {
      return new Node(item.id, item.name);
    });

    if (this.currentNodeIndex >= this.nodes.length) {
      this.currentNodeIndex = 0;
    }
  }

  private async loadMetaForAllNodes(): Promise<void> {
    const httpService = HttpService.getInstance();
    for (let i = 0; i < this.nodes.length; i++) {
      const node = this.nodes[i];
      const sMeta = await httpService.getSensorMeta(node.id);
      if (sMeta) {
        node.sensorMeta = sMeta;
      }
      const eMeta = await httpService.getEquipmentMeta(node.id);
      if (eMeta) {
        node.equipmentMeta = eMeta;
      }
    }
  }

  async aboutToAppear() {
    await this.loadNodesFromServer();
    HttpService.getInstance().setNodeId(this.nodes[this.currentNodeIndex].id);
    await this.loadMetaForAllNodes();

    MqttClientService.getInstance().connect(
      AppConfig.MQTT_BROKER_URL,
      AppConfig.MQTT_CLIENT_PREFIX + new Date().getTime(),
      (nodeId, msgStr) => {
        try {
          const payload = JSON.parse(msgStr) as Record<string, Object | string | number | boolean>;
          if (payload['data']) {
            const data = payload['data'] as Record<string, Object | string | number | boolean>;
            this.nodes.forEach(node => {
              if (node.id === nodeId) {
                if (data['environment']) {
                  const env = data['environment'] as Record<string, number>;
                  const envKeys = Object.keys(env);
                  for (let i = 0; i < envKeys.length; i++) {
                    node.sensorData.setValue(envKeys[i], env[envKeys[i]]);
                  }
                }
                if (data['equipment']) {
                  const equip = data['equipment'] as Record<string, boolean | number>;
                  const equipKeys = Object.keys(equip);
                  for (let i = 0; i < equipKeys.length; i++) {
                    node.nodeState.setState(equipKeys[i], Boolean(equip[equipKeys[i]]));
                  }
                }
                if (data['mode'] !== undefined) {
                  const mode = data['mode'];
                  if (typeof mode === 'string') {
                    node.nodeState.smartMode = mode.toLowerCase() === 'smart';
                  } else if (typeof mode === 'boolean') {
                    node.nodeState.smartMode = mode;
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
            node: this.nodes[this.currentNodeIndex],
            nodesList: this.nodes.map(d => d.name),
            currentNodeIndex: this.currentNodeIndex,
            onSwitchNode: (idx: number) => {
              this.currentNodeIndex = idx;
              HttpService.getInstance().setNodeId(this.nodes[idx].id);
            },
            onAddNode: (name: string) => {
              this.nodes.push(new Node('node_' + Date.now(), name));
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
