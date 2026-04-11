import { SensorData } from '../models/SensorData';
import { NodeState } from '../models/NodeState';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { LiveStreamInfo, PlaybackItem, KeyframeImageItem } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';
import { MqttClientService } from '../services/MqttClientService';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Component
export struct MonitorView {
  // ───────── 对外 Props（接口不变）─────────
  @Prop nodeId: string = '';
  @Prop nodeStatus: string = 'offline';
  @Prop mqttHeartbeatOffline: boolean = false;
  @ObjectLink sensorData: SensorData;
  @ObjectLink nodeState: NodeState;
  @Prop sensorMeta: SensorMetaItem[] = [];
  @Prop equipmentMeta: EquipmentMetaItem[] = [];
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  // ───────── 内部状态：视频 ─────────
  @State liveInfo: LiveStreamInfo = {
    cameraId: '', cameraName: '加载中...', status: 'offline',
    streamTag: '--', resolution: '--', lastHeartbeat: '--', streamUrl: ''
  };
  @State videoLoading: boolean = false;
  private videoController: VideoController = new VideoController();

  // ───────── 内部状态：回放 + 关键帧（原 VideoDetailPage）─────────
  @State playbackItems: PlaybackItem[] = [];
  @State abnormalFrames: KeyframeImageItem[] = [];
  @State selectedDate: string = '';
  @State playbackLoading: boolean = false;

  // ───────── 内部状态：竖屏 Tab ─────────
  @State currentTab: number = 0;

  // ═══════════════ 工具方法 ═══════════════

  private sf(base: number): number {
    if (this.currentBreakpoint === 'lg') {
      return Math.round(base * 1.25);
    }
    if (this.currentBreakpoint === 'md') {
      return Math.round(base * 1.1);
    }
    return base;
  }

  private isNodeConnected(): boolean {
    return this.nodeStatus === 'online' && !this.mqttHeartbeatOffline;
  }

  private getDisplaySensorMeta(): SensorMetaItem[] {
    let vis: SensorMetaItem[] = [];
    for (let i = 0; i < this.sensorMeta.length; i++) {
      if (this.sensorData.hasValue(this.sensorMeta[i].key)) {
        vis.push(this.sensorMeta[i]);
      }
    }
    return vis;
  }

  private getDisplayEquipmentMeta(): EquipmentMetaItem[] {
    let vis: EquipmentMetaItem[] = [];
    for (let i = 0; i < this.equipmentMeta.length; i++) {
      if (this.nodeState.hasState(this.equipmentMeta[i].key)) {
        vis.push(this.equipmentMeta[i]);
      }
    }
    return vis;
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

  // ═══════════════ 生命周期 ═══════════════

  aboutToAppear(): void {
    void this.loadVideoInfo();
    void this.bootstrapControlState();
    void this.loadPlaybackData();
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
    if (detail && detail.nodeState) {
      const st: Record<string, boolean | undefined> = detail.nodeState;
      const keys = Object.keys(st);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] === 'smartMode') {
          this.nodeState.smartMode = Boolean(st[keys[i]]);
        } else {
          this.nodeState.setState(keys[i], Boolean(st[keys[i]]));
        }
      }
    }
    for (let i = 0; i < this.equipmentMeta.length; i++) {
      if (!this.nodeState.hasState(this.equipmentMeta[i].key)) {
        this.nodeState.setState(this.equipmentMeta[i].key, false);
      }
    }
    this.nodeState.controlStateBootstrapped = true;
  }

  private async loadPlaybackData(): Promise<void> {
    this.playbackLoading = true;
    try {
      const svc = VideoMonitorService.getInstance();
      this.playbackItems = await svc.getDailyPlaybackList(this.nodeId);
      if (this.playbackItems.length > 0) {
        this.selectedDate = this.playbackItems[0].date;
        const frames = await svc.getKeyframesByDate(this.nodeId, this.selectedDate);
        this.abnormalFrames = frames.filter((f: KeyframeImageItem) => f.isAbnormal);
      }
    } catch (e) {
      console.error('[MonitorView] loadPlaybackData failed', e);
    } finally {
      this.playbackLoading = false;
    }
  }

  private async onSelectPlayback(item: PlaybackItem): Promise<void> {
    try {
      this.selectedDate = item.date;
      const frames = await VideoMonitorService.getInstance().getKeyframesByDate(this.nodeId, item.date);
      this.abnormalFrames = frames.filter((f: KeyframeImageItem) => f.isAbnormal);
    } catch (e) {
      promptAction.showToast({ message: '关键帧加载失败', duration: 1800 });
    }
  }

  // ═══════════════ 标题条 Builder ═══════════════

  @Builder
  SectionHeader(title: string, accentColor: string) {
    Row() {
      Text('')
        .width(3).height(this.sf(16)).borderRadius(2)
        .backgroundColor(accentColor)
        .margin({ right: AppSpacing.SM })
      Text(title)
        .fontSize(this.sf(AppFontSize.H3))
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
    }
  }

  // ═══════════════ 视频面板（左上）═══════════════

  @Builder
  VideoPanel() {
    Column() {
      Row() {
        this.SectionHeader('实时监控', AppColors.Primary)
        Blank()
        Row() {
          Circle({ width: AppSize.StatusDotSize, height: AppSize.StatusDotSize })
            .fill(this.liveInfo.status === 'online' ? AppColors.Success : AppColors.AlertCritical)
            .margin({ right: AppSpacing.XS })
          Text(this.liveInfo.status === 'online' ? '在线' : '离线')
            .fontSize(this.sf(AppFontSize.Mini))
            .fontColor(this.liveInfo.status === 'online' ? AppColors.Success : AppColors.AlertCritical)
        }
        .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 3, bottom: 3 })
        .borderRadius(AppRadius.Full)
        .backgroundColor(this.liveInfo.status === 'online' ? AppColors.SuccessBg : AppColors.AlertCriticalBg)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: AppSpacing.SM })

      if (this.liveInfo.status === 'online' && this.liveInfo.streamUrl.length > 0) {
        Video({ src: this.liveInfo.streamUrl, controller: this.videoController })
          .width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM).controls(true)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Row() {
          }.width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM).backgroundColor('#1A2332')
          Column() {
            Text('📡').fontSize(this.sf(28)).margin({ bottom: AppSpacing.XS })
            Text('视频流不可用')
              .fontSize(this.sf(AppFontSize.Caption)).fontColor('rgba(255,255,255,0.6)')
          }
        }
      }

      Row() {
        Text(this.liveInfo.cameraName)
          .fontSize(this.sf(AppFontSize.Caption)).fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        Text(this.liveInfo.streamTag + ' · ' + this.liveInfo.resolution)
          .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
      }
      .width('100%').margin({ top: AppSpacing.SM })
    }
    .width('100%')
    .padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 历史记录面板（左下上）═══════════════

  @Builder
  PlaybackPanel() {
    Column() {
      this.SectionHeader('监控回放', AppColors.Accent)
      if (this.playbackItems.length === 0) {
        Text(this.playbackLoading ? '加载中...' : '暂无回放记录')
          .fontSize(this.sf(AppFontSize.Caption)).fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM })
      } else {
        List({ space: AppSpacing.SM }) {
          ForEach(this.playbackItems, (item: PlaybackItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.date)
                    .fontSize(this.sf(AppFontSize.Caption)).fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary)
                  Text(item.duration + ' · ' + item.quality)
                    .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
                    .margin({ top: 2 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                if (item.abnormalCount > 0) {
                  Text('异常' + item.abnormalCount.toString())
                    .fontSize(this.sf(AppFontSize.Mini))
                    .fontColor(AppColors.AlertCritical)
                    .backgroundColor(AppColors.AlertCriticalBg)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(AppRadius.SM)
                    .margin({ right: AppSpacing.SM })
                }
                Text(item.available ? '查看' : '待生成')
                  .fontSize(this.sf(AppFontSize.Mini))
                  .fontColor(item.available ? AppColors.Primary : AppColors.TextTertiary)
              }
              .width('100%').padding(AppSpacing.SM)
              .backgroundColor(item.date === this.selectedDate ? AppColors.PrimaryBg : AppColors.Background)
              .borderRadius(AppRadius.SM)
              .onClick(() => {
                if (item.available) {
                  void this.onSelectPlayback(item);
                }
              })
            }
          }, (item: PlaybackItem) => item.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 180 })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .margin({ top: AppSpacing.SM })
      }
    }
    .width('100%')
    .padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 关键帧面板（左下下）═══════════════

  @Builder
  KeyframePanel() {
    Column() {
      Row() {
        this.SectionHeader('AI 异常关键帧', AppColors.AlertWarning)
        Blank()
        if (this.selectedDate.length > 0) {
          Text(this.selectedDate)
            .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
        }
      }.width('100%').alignItems(VerticalAlign.Center)

      if (this.abnormalFrames.length === 0) {
        Text('当前日期未检测到异常').fontSize(this.sf(AppFontSize.Caption))
          .fontColor(AppColors.TextTertiary).margin({ top: AppSpacing.SM })
      } else {
        List({ space: AppSpacing.SM }) {
          ForEach(this.abnormalFrames, (item: KeyframeImageItem) => {
            ListItem() {
              Row() {
                Stack({ alignContent: Alignment.Center }) {
                  Row() {
                  }.width(this.sf(60)).height(this.sf(60))
                    .borderRadius(AppRadius.SM)
                    .backgroundColor(item.severity === 'critical'
                      ? AppColors.AlertCriticalBg : AppColors.AlertWarningBg)
                  Text(item.thumbnailHint).fontSize(this.sf(22))
                }.margin({ right: AppSpacing.SM })

                Column() {
                  Row() {
                    Text(item.severity === 'critical' ? '高危' : '一般')
                      .fontSize(this.sf(AppFontSize.Mini))
                      .fontColor(item.severity === 'critical'
                        ? AppColors.AlertCritical : AppColors.AlertWarning)
                      .backgroundColor(item.severity === 'critical'
                        ? AppColors.AlertCriticalBg : AppColors.AlertWarningBg)
                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                      .borderRadius(AppRadius.SM)
                    Text(item.captureTime)
                      .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
                      .margin({ left: AppSpacing.XS })
                  }
                  Text(item.label)
                    .fontSize(this.sf(AppFontSize.Caption)).fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary).margin({ top: 2 })
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.abnormalType + ' · 置信度 ' + item.confidence.toFixed(0) + '%')
                    .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
                    .margin({ top: 2 })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .width('100%').padding(AppSpacing.SM)
              .backgroundColor(item.severity === 'critical' ? '#FFF5F5' : '#FFFDF8')
              .borderRadius(AppRadius.SM)
              .onClick(() => {
                promptAction.showToast({ message: item.label + ' ' + item.captureTime, duration: 1800 });
              })
            }
          }, (item: KeyframeImageItem) => item.id)
        }
        .width('100%')
        .constraintSize({ maxHeight: 260 })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .margin({ top: AppSpacing.SM })
      }
    }
    .width('100%')
    .padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 传感器卡片 ═══════════════

  @Builder
  SensorCard(meta: SensorMetaItem) {
    Row() {
      Row() {
      }.width(4).height('80%').borderRadius(2)
        .backgroundColor(meta.badgeColor || AppColors.Primary)

      Column() {
        Row() {
          Text(meta.icon).fontSize(this.sf(14))
          Text(meta.name)
            .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextSecondary)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: AppSpacing.XS })
        }
        Row() {
          Text(this.formatValue(meta))
            .fontSize(this.sf(AppFontSize.H2)).fontWeight(FontWeight.Bold)
            .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key))
              ? AppColors.AlertCritical : AppColors.TextPrimary)
          if (meta.unit.length > 0) {
            Text(meta.unit)
              .fontSize(this.sf(AppFontSize.Mini))
              .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key))
                ? AppColors.AlertCritical : AppColors.TextTertiary)
              .margin({ left: 2, bottom: 2 })
          }
        }.alignItems(VerticalAlign.Bottom).margin({ top: AppSpacing.XS })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center).padding({ left: AppSpacing.SM })
    }
    .width('100%').height(this.sf(64))
    .padding({ left: AppSpacing.XS, right: AppSpacing.SM, top: AppSpacing.SM, bottom: AppSpacing.SM })
    .backgroundColor(AppColors.Surface).borderRadius(AppRadius.SM)
    .border({
      width: 1,
      color: this.isWarning(meta, this.sensorData.getValue(meta.key))
        ? AppColors.AlertCritical : AppColors.Divider
    })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SensorDetailPage',
        params: {
          nodeId: this.nodeId, type: meta.key, metricKey: meta.key,
          title: meta.name, currentValue: this.sensorData.getValue(meta.key),
          badgeColor: meta.badgeColor, unit: meta.unit,
          warningMin: meta.warningMin ?? -Infinity, warningMax: meta.warningMax ?? Infinity
        }
      });
    })
  }

  // ═══════════════ 传感器面板（右上）═══════════════

  @Builder
  SensorPanel() {
    Column() {
      Row() {
        this.SectionHeader('环境数据', AppColors.Accent)
        Blank()
        if (this.getDisplaySensorMeta().length > 0) {
          Text(this.getDisplaySensorMeta().length.toString() + ' 项')
            .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextTertiary)
        }
      }.width('100%').alignItems(VerticalAlign.Center).margin({ bottom: AppSpacing.SM })

      Text('').visibility(Visibility.None).fontSize(this.sensorData.revision)

      if (this.sensorMeta.length === 0) {
        this.EmptyHint('暂无传感器配置')
      } else if (this.getDisplaySensorMeta().length === 0) {
        this.EmptyHint('等待设备上报传感器数据…')
      } else {
        Column({ space: AppSpacing.SM }) {
          ForEach(this.getDisplaySensorMeta(), (meta: SensorMetaItem) => {
            this.SensorCard(meta)
          }, (meta: SensorMetaItem) => meta.key)
        }
        .width('100%')
      }
    }
    .width('100%').padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface).borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 设备卡片 ═══════════════

  @Builder
  EquipmentCard(meta: EquipmentMetaItem) {
    Row() {
      Row() {
        Text(meta.icon).fontSize(this.sf(18))
      }
      .width(this.sf(36)).height(this.sf(36)).borderRadius(this.sf(18))
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOnBg : AppColors.DeviceOffBg)

      Column() {
        Text(meta.name)
          .fontSize(this.sf(AppFontSize.Caption)).fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Circle({ width: 6, height: 6 })
            .fill(this.nodeState.getState(meta.key) ? AppColors.DeviceOn : AppColors.DeviceOff)
            .margin({ right: 3 })
          Text(this.nodeState.getState(meta.key) ? '运行' : '停止')
            .fontSize(this.sf(AppFontSize.Mini))
            .fontColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOn : AppColors.DeviceOff)
        }.margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).padding({ left: AppSpacing.SM })

      Toggle({ type: ToggleType.Switch, isOn: this.nodeState.getState(meta.key) })
        .selectedColor(AppColors.Primary)
        .onChange((isOn: boolean) => {
          if (this.nodeState.getState(meta.key) === isOn) {
            return;
          }
          this.nodeState.setState(meta.key, isOn);
          MqttClientService.getInstance().enqueueCommand(this.nodeId, meta.key, isOn ? 'turn_on' : 'turn_off');
          promptAction.showToast({ message: (isOn ? '开启' : '关闭') + ' ' + meta.name });
        })
    }
    .width('100%').height(this.sf(56))
    .padding({ left: AppSpacing.SM, right: AppSpacing.SM })
    .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOnBg : AppColors.Surface)
    .borderRadius(AppRadius.SM)
    .border({ width: 1, color: this.nodeState.getState(meta.key) ? AppColors.DeviceOnBorder : AppColors.Divider })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/DeviceDetailPage',
        params: { type: meta.key, title: meta.name, isOn: this.nodeState.getState(meta.key) }
      });
    })
  }

  // ═══════════════ 设备控制面板（右下）═══════════════

  @Builder
  ControlPanel() {
    Column() {
      Row() {
        this.SectionHeader('设备控制', AppColors.PrimaryLight)
        Blank()
        Text('智能')
          .fontSize(this.sf(AppFontSize.Mini)).fontColor(AppColors.TextSecondary)
          .margin({ right: AppSpacing.XS })
        Toggle({ type: ToggleType.Switch, isOn: this.nodeState.smartMode })
          .selectedColor(AppColors.Primary)
          .onChange((isOn: boolean) => {
            if (this.nodeState.smartMode === isOn) {
              return;
            }
            this.nodeState.smartMode = isOn;
            this.nodeState.smartModeCommandAt = Date.now();
            MqttClientService.getInstance().enqueueCommand(this.nodeId, 'mode', isOn ? 'smart' : 'manual');
            promptAction.showToast({ message: '已切换至' + (isOn ? '智能' : '手动') + '模式' });
          })
      }.width('100%').alignItems(VerticalAlign.Center).margin({ bottom: AppSpacing.SM })

      Text('').visibility(Visibility.None).fontSize(this.nodeState.revision)

      if (this.equipmentMeta.length === 0) {
        this.EmptyHint('暂无设备配置')
      } else if (this.getDisplayEquipmentMeta().length === 0) {
        this.EmptyHint('等待设备上报状态…')
      } else {
        Column({ space: AppSpacing.SM }) {
          ForEach(this.getDisplayEquipmentMeta(), (meta: EquipmentMetaItem) => {
            this.EquipmentCard(meta)
          }, (meta: EquipmentMetaItem) => meta.key)
        }
        .width('100%')
      }
    }
    .width('100%').padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface).borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 空数据提示 ═══════════════

  @Builder
  EmptyHint(msg: string) {
    Column() {
      Text(msg).fontSize(this.sf(AppFontSize.Caption))
        .fontColor(AppColors.TextTertiary).textAlign(TextAlign.Center)
    }.width('100%').height(100)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  // ═══════════════ 离线提示 ═══════════════

  @Builder
  OfflineContent() {
    Column() {
      Text('🔌').fontSize(this.sf(40)).margin({ bottom: AppSpacing.SM })
      Text('硬件未连接')
        .fontSize(this.sf(AppFontSize.H3)).fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary).margin({ bottom: AppSpacing.XS })
      Text('无法获取实时数据，请检查设备连接')
        .fontSize(this.sf(AppFontSize.Caption)).fontColor(AppColors.TextSecondary)
        .textAlign(TextAlign.Center)
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.Background)
  }

  // ═══════════════ 竖屏 Tab 栏 ═══════════════

  @Builder
  SmTabBar(icon: string, label: string, idx: number) {
    Column() {
      Text(icon).fontSize(this.sf(18))
      Text(label)
        .fontSize(this.sf(AppFontSize.Mini))
        .fontColor(this.currentTab === idx ? AppColors.Primary : AppColors.TextTertiary)
        .margin({ top: 2 })
    }.justifyContent(FlexAlign.Center).width('100%').height('100%')
  }

  // ═══════════════ 左侧整列（视频+回放+关键帧）═══════════════

  @Builder
  LeftColumn() {
    Column({ space: AppSpacing.SM }) {
      this.VideoPanel()
      this.PlaybackPanel()
      this.KeyframePanel()
    }.width('100%')
  }

  // ═══════════════ 右侧整列（传感器+设备控制）═══════════════

  @Builder
  RightColumn() {
    Column({ space: AppSpacing.SM }) {
      this.SensorPanel()
      this.ControlPanel()
    }.width('100%')
  }

  // ═══════════════ 主布局 ═══════════════

  build() {
    Column() {
      if (!this.isNodeConnected()) {
        this.OfflineContent()
      } else if (this.currentBreakpoint === 'lg') {
        Scroll() {
          Row({ space: AppSpacing.SM }) {
            Column() {
              this.LeftColumn()
            }.width('55%')

            Column() {
              this.RightColumn()
            }.width('45%')
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
      } else if (this.currentBreakpoint === 'md') {
        Scroll() {
          Row({ space: AppSpacing.SM }) {
            Column() {
              this.LeftColumn()
            }.width('50%')

            Column() {
              this.RightColumn()
            }.width('50%')
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%').layoutWeight(1)
        .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
          TabContent() {
            Scroll() {
              this.LeftColumn()
            }.width('100%').height('100%')
              .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
          }.tabBar(this.SmTabBar('📹', '监控', 0))

          TabContent() {
            Scroll() {
              this.SensorPanel()
            }.width('100%').height('100%')
              .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
          }.tabBar(this.SmTabBar('🌡️', '数据', 1))

          TabContent() {
            Scroll() {
              this.ControlPanel()
            }.width('100%').height('100%')
              .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
          }.tabBar(this.SmTabBar('⚙️', '控制', 2))
        }
        .width('100%').layoutWeight(1)
        .barHeight(this.sf(48)).barMode(BarMode.Fixed)
        .animationDuration(200)
        .onChange((idx: number) => {
          this.currentTab = idx;
        })
      }
    }
    .width('100%').height('100%')
    .padding(this.isNodeConnected() ? AppSpacing.SM : 0)
    .backgroundColor(AppColors.Background)
  }
}
