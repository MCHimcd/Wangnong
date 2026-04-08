import { SensorData } from '../models/SensorData';
import { NodeState } from '../models/NodeState';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { LiveStreamInfo } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';
import { MqttClientService } from '../services/MqttClientService';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Component
export struct MonitorView {
  @Prop nodeId: string = '';
  @Prop nodeStatus: string = 'offline';
  @Prop mqttHeartbeatOffline: boolean = false;
  @ObjectLink sensorData: SensorData;
  @ObjectLink nodeState: NodeState;
  @Prop sensorMeta: SensorMetaItem[] = [];
  @Prop equipmentMeta: EquipmentMetaItem[] = [];
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  @State liveInfo: LiveStreamInfo = {
    cameraId: '',
    cameraName: '加载中...',
    status: 'offline',
    streamTag: '--',
    resolution: '--',
    lastHeartbeat: '--',
    streamUrl: ''
  };
  @State videoLoading: boolean = false;
  private videoController: VideoController = new VideoController();

  private isNodeConnected(): boolean {
    return this.nodeStatus === 'online' && !this.mqttHeartbeatOffline;
  }

  private getDisplaySensorMeta(): SensorMetaItem[] {
    let visibleMeta: SensorMetaItem[] = [];
    for (let i = 0; i < this.sensorMeta.length; i++) {
      if (this.sensorData.hasValue(this.sensorMeta[i].key)) {
        visibleMeta.push(this.sensorMeta[i]);
      }
    }
    return visibleMeta;
  }

  private getDisplayEquipmentMeta(): EquipmentMetaItem[] {
    let visibleMeta: EquipmentMetaItem[] = [];
    for (let i = 0; i < this.equipmentMeta.length; i++) {
      if (this.nodeState.hasState(this.equipmentMeta[i].key)) {
        visibleMeta.push(this.equipmentMeta[i]);
      }
    }
    return visibleMeta;
  }

  aboutToAppear(): void {
    void this.loadVideoInfo();
    void this.bootstrapControlState();
  }

  private async loadVideoInfo(): Promise<void> {
    this.videoLoading = true;
    try {
      this.liveInfo = await VideoMonitorService.getInstance().getLiveStreamInfo(this.nodeId);
    } catch (e) {
      console.error('[MonitorView] loadVideoInfo failed', e);
    } finally {
      this.videoLoading = false;
    }
  }

  private async bootstrapControlState(): Promise<void> {
    if (this.nodeState.controlStateBootstrapped) {
      return;
    }
    const detail = await HttpService.getInstance().getNodeDetail(this.nodeId);
    if (!detail || !detail.nodeState) {
      return;
    }
    const st: Record<string, boolean | undefined> = detail.nodeState;
    const keys = Object.keys(st);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] === 'smartMode') {
        this.nodeState.smartMode = Boolean(st[keys[i]]);
      } else {
        this.nodeState.setState(keys[i], Boolean(st[keys[i]]));
      }
    }
    this.nodeState.controlStateBootstrapped = true;
  }

  private isWarning(meta: SensorMetaItem, value: number): boolean {
    if (meta.warningMax !== undefined && value > meta.warningMax) {
      return true;
    }
    if (meta.warningMin !== undefined && value < meta.warningMin) {
      return true;
    }
    return false;
  }

  @Builder
  SectionTitle(title: string, icon: string) {
    Row() {
      Text(icon).fontSize(18).margin({ right: AppSpacing.SM })
      Text(title)
        .fontSize(AppFontSize.H2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
    }
    .width('100%')
    .margin({ bottom: AppSpacing.MD })
  }

  @Builder
  SensorSection() {
    Column() {
      this.SectionTitle('环境数据', '🌡️')

      // 触发依赖
      Text('').visibility(Visibility.None).fontSize(this.sensorData.revision)

      if (this.sensorMeta.length === 0) {
        Text('暂无传感器配置')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else if (this.getDisplaySensorMeta().length === 0) {
        Text('暂无有效传感器数据，请等待设备上报')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else {
        if (this.currentBreakpoint === 'lg') {
          // 大屏: Grid 铺满
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getDisplaySensorMeta(), (meta: SensorMetaItem) => {
              Column() {
                this.SensorCard(meta)
              }
              .width('25%')
              .padding(AppSpacing.XS)
            }, (meta: SensorMetaItem) => meta.key)
          }
          .width('100%')
        } else if (this.currentBreakpoint === 'md') {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getDisplaySensorMeta(), (meta: SensorMetaItem) => {
              Column() {
                this.SensorCard(meta)
              }
              .width('33.33%')
              .padding(AppSpacing.XS)
            }, (meta: SensorMetaItem) => meta.key)
          }
          .width('100%')
        } else {
          // 小屏: 横向滚动
          List({ space: AppSpacing.MD }) {
            ForEach(this.getDisplaySensorMeta(), (meta: SensorMetaItem) => {
              ListItem() {
                this.SensorCard(meta)
              }
            }, (meta: SensorMetaItem) => meta.key)
          }
          .listDirection(Axis.Horizontal)
          .width('100%')
          .height(130)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.XL)
    .padding(AppSpacing.CardPadding)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  SensorCard(meta: SensorMetaItem) {
    Column() {
      // 图标圆形底色
      Row() {
        Text(meta.icon).fontSize(20)
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(meta.bgColor || AppColors.PrimaryBg)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: AppSpacing.SM })

      Text(meta.name)
        .fontSize(AppFontSize.Caption)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: AppSpacing.SM })

      Row() {
        Text(this.formatValue(meta))
          .fontSize(AppFontSize.H1)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key)) ?
            AppColors.AlertCritical : AppColors.TextPrimary)
        if (meta.unit.length > 0) {
          Text(meta.unit)
            .fontSize(AppFontSize.Mini)
            .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key)) ?
              AppColors.AlertCritical : AppColors.TextTertiary)
            .margin({ left: 2, bottom: 3 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width(this.currentBreakpoint === 'sm' ? 130 : '100%')
    .height(this.currentBreakpoint === 'sm' ? 120 : undefined)
    .constraintSize({ minHeight: 110 })
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .padding(AppSpacing.MD)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .border({ width: 1, color: AppColors.Divider })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SensorDetailPage',
        params: {
          nodeId: this.nodeId,
          type: meta.key,
          metricKey: meta.key,
          title: meta.name,
          currentValue: this.sensorData.getValue(meta.key),
          badgeColor: meta.badgeColor,
          unit: meta.unit,
          warningMin: meta.warningMin ?? -Infinity,
          warningMax: meta.warningMax ?? Infinity
        }
      });
    })
  }

  private formatValue(meta: SensorMetaItem): string {
    const v = this.sensorData.getValue(meta.key);
    if (meta.key === 'light' || meta.key === 'co2') {
      return v.toFixed(0);
    }
    if (meta.key === 'soilPh') {
      return v.toFixed(2);
    }
    return v.toFixed(1);
  }

  @Builder
  VideoSection() {
    Column() {
      Row() {
        this.SectionTitle('实时监控', '📹')
        Blank()
        Text(this.liveInfo.status === 'online' ? '● 在线' : '● 离线')
          .fontSize(AppFontSize.Caption)
          .fontColor(this.liveInfo.status === 'online' ? AppColors.Success : AppColors.AlertCritical)
          .backgroundColor(this.liveInfo.status === 'online' ? AppColors.SuccessBg : AppColors.AlertCriticalBg)
          .padding({ left: AppSpacing.SM, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.liveInfo.status === 'online' && this.liveInfo.streamUrl.length > 0) {
        Video({ src: this.liveInfo.streamUrl, controller: this.videoController })
          .width('100%')
          .aspectRatio(16 / 9)
          .borderRadius(AppRadius.MD)
          .controls(true)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Row() {}
            .width('100%')
            .aspectRatio(16 / 9)
            .borderRadius(AppRadius.MD)
            .backgroundColor('#1A2332')
          Column() {
            Text('📡').fontSize(32).margin({ bottom: AppSpacing.SM })
            Text('视频流不可用')
              .fontSize(AppFontSize.Body)
              .fontColor('rgba(255,255,255,0.6)')
          }
        }
      }

      Row() {
        Column() {
          Text(this.liveInfo.cameraName)
            .fontSize(AppFontSize.Body)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
          Text(`${this.liveInfo.streamTag} · ${this.liveInfo.resolution}`)
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.TextTertiary)
            .margin({ top: AppSpacing.XS })
        }
        Blank()
        Button('查看回放', { type: ButtonType.Capsule })
          .height(AppSize.ButtonHeightSM)
          .fontSize(AppFontSize.Caption)
          .backgroundColor(AppColors.Primary)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/VideoDetailPage',
              params: { nodeId: this.nodeId }
            });
          })
      }
      .width('100%')
      .margin({ top: AppSpacing.MD })
    }
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.XL)
    .padding(AppSpacing.CardPadding)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  ControlSection() {
    Column() {
      Row() {
        Text('⚙️').fontSize(18).margin({ right: AppSpacing.SM })
        Text('设备控制')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
        Blank()
        Text('智能模式')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextSecondary)
          .margin({ right: AppSpacing.SM })
        Toggle({ type: ToggleType.Switch, isOn: this.nodeState.smartMode })
          .selectedColor(AppColors.Primary)
          .onChange((isOn: boolean) => {
            this.nodeState.smartMode = isOn;
            MqttClientService.getInstance().publishCommand(this.nodeId, 'mode', isOn ? 'smart' : 'manual');
            promptAction.showToast({ message: `已切换至${isOn ? '智能' : '手动'}模式` });
          })
      }
      .width('100%')
      .margin({ bottom: AppSpacing.MD })

      // 触发依赖
      Text('').visibility(Visibility.None).fontSize(this.nodeState.revision)

      if (this.equipmentMeta.length === 0) {
        Text('暂无设备配置')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else if (this.getDisplayEquipmentMeta().length === 0) {
        Text('暂无有效设备状态数据，请等待设备上报')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else {
        if (this.currentBreakpoint === 'lg' || this.currentBreakpoint === 'md') {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.getDisplayEquipmentMeta(), (meta: EquipmentMetaItem) => {
              Column() {
                this.EquipmentCard(meta)
              }
              .width(this.currentBreakpoint === 'lg' ? '25%' : '33.33%')
              .padding(AppSpacing.XS)
            }, (meta: EquipmentMetaItem) => meta.key)
          }
          .width('100%')
        } else {
          List({ space: AppSpacing.MD }) {
            ForEach(this.getDisplayEquipmentMeta(), (meta: EquipmentMetaItem) => {
              ListItem() {
                this.EquipmentCard(meta)
              }
            }, (meta: EquipmentMetaItem) => meta.key)
          }
          .listDirection(Axis.Horizontal)
          .width('100%')
          .height(150)
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.XL)
    .padding(AppSpacing.CardPadding)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  EquipmentCard(meta: EquipmentMetaItem) {
    Row() {
      // 左侧状态竖条
      Row() {}
        .width(3)
        .height(48)
        .borderRadius(2)
        .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOn : 'transparent')

      Column() {
        Text(meta.icon)
          .fontSize(28)
          .margin({ bottom: AppSpacing.SM })

        Text(meta.name)
          .fontSize(AppFontSize.Body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: AppSpacing.SM })

        Button({ type: ButtonType.Capsule }) {
          Row() {
            Circle({ width: AppSize.StatusDotSize, height: AppSize.StatusDotSize })
              .fill(this.nodeState.getState(meta.key) ? AppColors.DeviceOn : AppColors.DeviceOff)
              .margin({ right: AppSpacing.XS })
            Text(this.nodeState.getState(meta.key) ? '运行中' : '已停止')
              .fontSize(AppFontSize.Caption)
              .fontColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOn : AppColors.DeviceOff)
          }
        }
        .height(28)
        .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOnBg : AppColors.DeviceOffBg)
        .border({ width: 1, color: this.nodeState.getState(meta.key) ? AppColors.DeviceOnBorder : AppColors.DeviceOffBorder })
        .opacity(this.nodeState.smartMode ? 0.5 : 1.0)
        .onClick(() => {
          if (this.nodeState.smartMode) {
            return;
          }
          const newState = !this.nodeState.getState(meta.key);
          MqttClientService.getInstance().publishCommand(
            this.nodeId, meta.key, newState ? 'turn_on' : 'turn_off'
          );
          promptAction.showToast({ message: `已发送${newState ? '开启' : '关闭'}指令` });
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width(this.currentBreakpoint === 'sm' ? 140 : '100%')
    .height(this.currentBreakpoint === 'sm' ? 140 : undefined)
    .constraintSize({ minHeight: 130 })
    .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOnBg : AppColors.Surface)
    .border({ width: 1, color: this.nodeState.getState(meta.key) ? AppColors.DeviceOnBorder : AppColors.Divider })
    .borderRadius(AppRadius.LG)
    .padding({ left: 0, right: AppSpacing.SM, top: AppSpacing.MD, bottom: AppSpacing.MD })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/DeviceDetailPage',
        params: { type: meta.key, title: meta.name, isOn: this.nodeState.getState(meta.key) }
      });
    })
  }

  @Builder
  OfflineSection() {
    Column() {
      Text('🔌')
        .fontSize(44)
        .margin({ bottom: AppSpacing.MD })

      Text('硬件未连接')
        .fontSize(AppFontSize.H2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.SM })

      Text('当前无法获取实时传感器与设备状态，请检查设备连接后重试')
        .fontSize(AppFontSize.Body)
        .fontColor(AppColors.TextSecondary)
        .textAlign(TextAlign.Center)
        .lineHeight(22)
    }
    .width('100%')
    .height(300)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding(AppSpacing.CardPadding)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.XL)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  build() {
    Column({ space: AppSpacing.SectionGap }) {
      if (this.isNodeConnected()) {
        this.VideoSection()
        this.SensorSection()
        this.ControlSection()
      } else {
        this.OfflineSection()
      }
    }
    .width('100%')
    .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding,
      top: AppSpacing.SectionGap, bottom: AppSpacing.XXL })
    .backgroundColor(AppColors.Background)
  }
}
