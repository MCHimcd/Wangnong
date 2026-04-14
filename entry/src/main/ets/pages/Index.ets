import { Node } from '../models/Node';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { HomeView } from '../views/HomeView';
import { AlertView } from '../views/AlertView';
import { ProfileView } from '../views/ProfileView';
import { NodeListItem, HttpService } from '../services/HttpService';
import { MqttClientService } from '../services/MqttClientService';
import { AlertSyncService } from '../services/AlertSyncService';
import { FrontendSimNodeService } from '../services/FrontendSimNodeService';
import { ServerAvailabilityService } from '../services/ServerAvailabilityService';
import { SmartControlService } from '../services/SmartControlService';
import { ThresholdSyncEvent, ThresholdSyncService } from '../services/ThresholdSyncService';
import { AlertData } from '../models/AlertData';
import { AppConfig } from '../common/AppConfig';
import { AppColors, AppFontSize, AppSpacing, AppRadius } from '../common/DesignToken';
import { BreakpointSystem } from '../common/BreakpointSystem';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

/**
 * Purpose: 作为登录后的主页面容器，负责初始化节点数据、建立 MQTT 与告警同步，并承载底部三 Tab 导航。
 * Responsibilities: 加载节点与元数据、启动会话探活、分发实时遥测到 Node、处理服务器断线与告警弹窗。
 * Flow: aboutToAppear() 先启动可用性监控和断点系统，再拉取节点/元数据，随后建立 MQTT 连接并启动 AlertSyncService。
 * Dependencies: 依赖 HttpService、MqttClientService、AlertSyncService、ServerAvailabilityService、BreakpointSystem 和三个 Tab 视图。
 * Input: 登录态下的节点列表、MQTT 遥测/告警、服务器可用性变化。
 * Output: 首页 Tab UI、全局连接状态、节点实时数据和可能触发的重新登录跳转。
 * Side Effects: 注册全局监听器、修改 AppStorage、建立/断开 MQTT 连接、弹出全局告警对话框。
 */
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
  @State mqttHeartbeatOffline: boolean = false;
  private isForceLogoutHandling: boolean = false;
  private readonly availabilityService: ServerAvailabilityService = ServerAvailabilityService.getInstance();
  private readonly smartControlService: SmartControlService = SmartControlService.getInstance();
  private readonly frontendSimNodeService: FrontendSimNodeService = FrontendSimNodeService.getInstance();
  private readonly onForceLogout = () => {
    void this.handleServerDisconnect();
  };
  private readonly onThresholdUpdated = (event: ThresholdSyncEvent) => {
    this.applyThresholdUpdate(event);
  };

  private applyThresholdUpdate(event: ThresholdSyncEvent): void {
    for (let i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].id !== event.nodeId) {
        continue;
      }

      let updatedMeta: SensorMetaItem[] = [];
      let found = false;
      for (let j = 0; j < this.nodes[i].sensorMeta.length; j++) {
        let meta = this.nodes[i].sensorMeta[j];
        if (meta.key === event.sensorKey) {
          meta.warningMin = event.warningMin === null ? undefined : event.warningMin;
          meta.warningMax = event.warningMax === null ? undefined : event.warningMax;
          found = true;
        }
        updatedMeta.push(meta);
      }
      if (found) {
        this.nodes[i].sensorMeta = updatedMeta;
        this.smartControlService.applyNode(this.nodes[i]);
      }
      return;
    }
  }

  private async loadNodesFromServer() {
    const remoteNodes = await HttpService.getInstance().getNodes();
    if (!remoteNodes || remoteNodes.length === 0) {
      return;
    }

    this.nodes = remoteNodes.map((item: NodeListItem) => {
      return new Node(item.id, item.name, item.status);
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
    // Flow: 初始化顺序必须是“会话探活 -> 断点注册 -> 节点与元数据加载 -> MQTT/告警同步”，否则页面会在依赖未准备好时提前消费状态。
    this.isForceLogoutHandling = false;
    this.availabilityService.addForceLogoutListener(this.onForceLogout);
    await this.availabilityService.startSessionMonitoring();
    ThresholdSyncService.getInstance().addListener(this.onThresholdUpdated);

    BreakpointSystem.getInstance().register();
    await this.loadNodesFromServer();
    HttpService.getInstance().setNodeId(this.nodes[this.currentNodeIndex].id);
    await this.loadMetaForAllNodes();

    MqttClientService.getInstance().connect(
      AppConfig.MQTT_BROKER_URL,
      AppConfig.MQTT_CLIENT_PREFIX + new Date().getTime(),
      (nodeId, msgStr) => {
        try {
          const payload = JSON.parse(msgStr) as Record<string, Object | string | number | boolean>;
          if (this.frontendSimNodeService.isManagedNode(nodeId) && payload['source'] !== 'frontend_sim') {
            return;
          }
          if (payload['data']) {
            const data = payload['data'] as Record<string, Object | string | number | boolean>;
            this.nodes.forEach(node => {
              if (node.id === nodeId) {
                node.status = 'online';
                this.mqttHeartbeatOffline = false;
                // Flow: 遥测回调同时负责环境指标、设备状态、智能模式和硬件图片四类更新，统一收口到当前 Node 上。
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
                    if (node.nodeState.isDebouncing(equipKeys[i])) {
                      continue; // 用户刚操作过，跳过遥测覆盖
                    }
                    const val = equip[equipKeys[i]];
                    if (typeof val === 'number') {
                      node.nodeState.setValue(equipKeys[i], val);
                    } else {
                      node.nodeState.setState(equipKeys[i], Boolean(val));
                    }
                  }
                }
                if (data['mode'] !== undefined) {
                  // Boundary: 模式切换后的短冷却窗优先相信用户本地操作，避免服务器回显把 Toggle 立即改回去。
                  const MODE_COOLDOWN_MS = 5000;
                  if (Date.now() - node.nodeState.smartModeCommandAt < MODE_COOLDOWN_MS) {
                    console.info('[Index] Skipping telemetry mode update during cooldown');
                  } else {
                    const mode = data['mode'];
                    if (typeof mode === 'string') {
                      node.nodeState.smartMode = mode.toLowerCase() === 'smart';
                    } else if (typeof mode === 'boolean') {
                      node.nodeState.smartMode = mode;
                    }
                  }
                }
                if (typeof data['image_base64'] === 'string' && (data['image_base64'] as string).length > 0) {
                  node.sensorData.setImageBase64(data['image_base64'] as string);
                }
                this.smartControlService.applyNode(node);
              }
            });
          }
        } catch (e) {
          console.error('[Index] Failed to parse MQTT message', e);
        }
      },
      (status, debugInfo) => {
        this.connectionStatus = status;
        if (status === 'disconnected') {
          this.mqttHeartbeatOffline = true;
        }
        console.info(`[Index] MQTT status changed: ${status}, info: ${debugInfo || ''}`);
      }
    );
    MqttClientService.getInstance().setOnOfflineCallback(() => {
      this.mqttHeartbeatOffline = true;
      if (this.currentNodeIndex >= 0 && this.currentNodeIndex < this.nodes.length) {
        this.nodes[this.currentNodeIndex].status = 'offline';
      }
    });
    AlertSyncService.getInstance().setAlertDialogCallback((alert: AlertData) => {
      // Boundary: 告警详情跳转不直接 push 页面，而是切到消息 Tab，让列表页和详情页共享统一的告警缓存入口。
      promptAction.showDialog({
        title: '新告警提示',
        message: `检测到新告警（最新：${alert.type_name}），是否立即查看？`,
        buttons: [
          { text: '稍后处理', color: AppColors.TextTertiary },
          { text: '立即查看', color: AppColors.AlertCritical }
        ]
      }).then((res) => {
        AlertSyncService.getInstance().markDialogClosed();
        if (res.index === 1) {
          this.currentTabIndex = 1;
        }
      }).catch(() => {
        AlertSyncService.getInstance().markDialogClosed();
      });
    });
    AlertSyncService.getInstance().startRealtimeSync();

    for (let i = 0; i < this.nodes.length; i++) {
      if (this.frontendSimNodeService.isManagedNode(this.nodes[i].id)) {
        this.frontendSimNodeService.start(this.nodes[i]);
      }
    }
  }

  aboutToDisappear() {
    // Reason: 这里必须按“取消监听 -> 停轮询 -> 注销断点 -> 停告警 -> 断 MQTT”的顺序清理，避免页面消失后仍有回调写状态。
    this.availabilityService.removeForceLogoutListener(this.onForceLogout);
    ThresholdSyncService.getInstance().removeListener(this.onThresholdUpdated);
    this.frontendSimNodeService.stop();
    this.availabilityService.stopPolling();
    BreakpointSystem.getInstance().unregister();
    AlertSyncService.getInstance().stopRealtimeSync();
    MqttClientService.getInstance().setOnOfflineCallback(() => {});
    MqttClientService.getInstance().disconnect();
  }

  private async handleServerDisconnect(): Promise<void> {
    if (this.isForceLogoutHandling) {
      return;
    }

    // Invariant: 强制登出只能执行一次；否则多个失败回调会重复清理状态并产生多次跳转。
    this.isForceLogoutHandling = true;
    this.availabilityService.stopPolling();
    AlertSyncService.getInstance().stopRealtimeSync();
    MqttClientService.getInstance().disconnect();

    HttpService.getInstance().setToken('');
    AppStorage.setOrCreate('isLoggedIn', false);

    promptAction.showToast({ message: '服务器连接已断开，请重新登录' });
    router.replaceUrl({ url: 'pages/LoginPage' });
  }

  @StorageLink('currentTabIndex') currentTabIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  @Builder
  TabLabel(title: string, icon: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(22)
        .margin({ bottom: 2 })
      Text(title)
        .fontSize(AppFontSize.Mini)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === index ? AppColors.Primary : AppColors.TextTertiary)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex, controller: this.tabsController }) {
        TabContent() {
          HomeView({ 
            node: this.nodes[this.currentNodeIndex],
            connectionStatus: this.connectionStatus,
            mqttHeartbeatOffline: this.mqttHeartbeatOffline,
            nodesList: this.nodes.map(d => d.name),
            currentNodeIndex: this.currentNodeIndex,
            onSwitchNode: (idx: number) => {
              // Flow: 节点切换由父页面统一更新 currentNodeIndex 和 HttpService 上下文，避免子视图自行持有不一致的 nodeId。
              this.currentNodeIndex = idx;
              HttpService.getInstance().setNodeId(this.nodes[idx].id);
            },
            onAddNode: (name: string) => {
              this.nodes.push(new Node('node_' + Date.now(), name));
            }
          })
        }
        .tabBar(this.TabLabel('首页', '🏠', 0))

        TabContent() {
          AlertView()
        }
        .tabBar(this.TabLabel('消息', '🔔', 1))

        TabContent() {
          ProfileView()
        }
        .tabBar(this.TabLabel('我的', '👤', 2))
      }
      .animationDuration(250)
      .layoutWeight(1)
      .barHeight(56)
      .onChange((index: number) => {
        this.currentTabIndex = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
}
