import { SensorData } from '../models/SensorData';
import { NodeState } from '../models/NodeState';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { LiveStreamInfo, PlaybackItem, KeyframeImageItem } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';
import { MqttClientService } from '../services/MqttClientService';
import { FrontendSimNodeService } from '../services/FrontendSimNodeService';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';
import { AppConfig } from '../common/AppConfig';
import { promptAction } from '@kit.ArkUI';
import image from '@ohos.multimedia.image';
import buffer from '@ohos.buffer';
import router from '@ohos.router';

/**
 * Purpose: 作为综合监控主视图，聚合实时环境数据、设备控制、视频直播、回放和异常关键帧展示。
 * Responsibilities: 接收当前节点的传感器与控制状态，加载视频数据，解码硬件图片帧，并在不同断点下组织监控布局。
 * Flow: aboutToAppear() 并行加载直播信息、控制初始态和回放数据，同时启动图片帧轮询解码；用户操作设备时通过 MqttClientService 入队控制命令。
 * Dependencies: 依赖 VideoMonitorService、HttpService、MqttClientService、NodeState/SensorData 和 DesignToken。
 * Input: 父组件传入的 nodeId、连接状态、sensorData、nodeState 以及 sensor/equipment 元数据。
 * Output: 监控面板 UI、设备控制命令、视频回放/关键帧展示和详情页跳转。
 * Side Effects: 轮询解码 Base64 图片、读取节点详情、发出 MQTT 控制命令、跳转到设备详情页。
 */
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

  // ───────── 内部状态：全屏回放 / 关键帧查看 ─────────
  @State liveVideoError: boolean = false;
  @State playbackFullscreenUrl: string = '';
  @State keyframeFullscreenUrl: string = '';
  @State keyframeFullscreenUseSimPlaceholder: boolean = false;
  @State imageScale: number = 1;

  // ───────── 内部状态：硬件摄像头图片 ─────────
  @State cameraPixelMap: image.PixelMap | undefined = undefined;
  private lastDecodeBase64: string = '';
  private imageCheckTimer: number = -1;

  // ═══════════════ 工具方法 ═══════════════

  /** 将后端返回的相对路径解析为完整 URL */
  private resolveUrl(url: string): string {
    if (url.startsWith('/')) {
      return AppConfig.BASE_URL + url;
    }
    return url;
  }

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
    if (FrontendSimNodeService.getInstance().isManagedNode(this.nodeId)) {
      return true;
    }
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
    if (meta.warningMax !== undefined && typeof meta.warningMax === 'number' && value > meta.warningMax) {
      return true;
    }
    if (meta.warningMin !== undefined && typeof meta.warningMin === 'number' && value < meta.warningMin) {
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

  private isSliderControl(meta: EquipmentMetaItem): boolean {
    return meta.controlType === 'slider' || meta.key === 'led_light';
  }

  private isSimKeyframePlaceholder(item: KeyframeImageItem): boolean {
    return FrontendSimNodeService.getInstance().isManagedNode(this.nodeId)
      && item.thumbnailHint === 'sim_video_placeholder';
  }

  private openKeyframeFullscreen(item: KeyframeImageItem): void {
    this.imageScale = 1;
    if (item.imageUrl !== undefined && item.imageUrl.length > 0) {
      this.keyframeFullscreenUseSimPlaceholder = false;
      this.keyframeFullscreenUrl = this.resolveUrl(item.imageUrl);
      return;
    }
    if (this.isSimKeyframePlaceholder(item)) {
      this.keyframeFullscreenUrl = '';
      this.keyframeFullscreenUseSimPlaceholder = true;
      return;
    }
    promptAction.showDialog({
      title: item.label,
      message: '类型: ' + item.abnormalType + '\n'
        + '严重度: ' + (item.severity === 'critical' ? '高危' : '一般') + '\n'
        + '置信度: ' + item.confidence.toFixed(0) + '%\n'
        + '时间: ' + item.captureTime,
      buttons: [{ text: '确定', color: AppColors.Primary }]
    });
  }

  private closeKeyframeFullscreen(): void {
    this.keyframeFullscreenUrl = '';
    this.keyframeFullscreenUseSimPlaceholder = false;
    this.imageScale = 1;
  }

  // ═══════════════ 生命周期 ═══════════════

  aboutToAppear(): void {
    // Flow: 视频、控制态和回放数据相互独立，因此并行启动；图片帧使用定时检查，避免每次 sensorData 微小变化都重复解码。
    void this.loadVideoInfo();
    void this.bootstrapControlState();
    void this.loadPlaybackData();
    this.imageCheckTimer = setInterval(() => {
      this.tryDecodeImageBase64();
    }, 500);
  }

  aboutToDisappear(): void {
    if (this.imageCheckTimer !== -1) {
      clearInterval(this.imageCheckTimer);
      this.imageCheckTimer = -1;
    }
    if (this.cameraPixelMap) {
      this.cameraPixelMap.release();
      this.cameraPixelMap = undefined;
    }
  }

  private tryDecodeImageBase64(): void {
    const base64Str = this.sensorData.imageBase64;
    if (base64Str.length === 0 || base64Str === this.lastDecodeBase64) {
      return;
    }
    // Reason: 仅在图片帧发生变化时才重新解码，可显著减少像素图创建和 release 的频率。
    this.lastDecodeBase64 = base64Str;
    void this.decodeBase64ToPixelMap(base64Str);
  }

  private async decodeBase64ToPixelMap(base64Str: string): Promise<void> {
    try {
      // Flow: Base64 -> Buffer -> Uint8Array -> ImageSource -> PixelMap，旧 PixelMap 必须释放，否则长时间监控会积累内存占用。
      const buf: buffer.Buffer = buffer.from(base64Str, 'base64');
      const uint8Array = new Uint8Array(buf.length);
      for (let i = 0; i < buf.length; i++) {
        uint8Array[i] = buf.readUInt8(i);
      }
      const arrayBuffer: ArrayBuffer = uint8Array.buffer as ArrayBuffer;
      const imageSource = image.createImageSource(arrayBuffer);
      const pixelMap = await imageSource.createPixelMap();
      const oldPixelMap = this.cameraPixelMap;
      this.cameraPixelMap = pixelMap;
      if (oldPixelMap) {
        oldPixelMap.release();
      }
      imageSource.release();
    } catch (e) {
      console.error('[MonitorView] decodeBase64ToPixelMap failed', e);
    }
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
    // Reason: 首次进入监控页时先用节点详情回填控制态，避免 MQTT 首条遥测未到达前所有开关都显示默认关闭。
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
        // Flow: 默认选中最新一天的回放，并立即拉取该日期的异常关键帧，保证回放区首次进入就有可见内容。
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

      if (this.cameraPixelMap !== undefined) {
        Image(this.cameraPixelMap)
          .width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM)
          .objectFit(ImageFit.Contain).backgroundColor('#1A2332')
      } else if (this.liveInfo.streamTag === '前端模拟') {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.sim_video_placeholder'))
            .width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM)
            .objectFit(ImageFit.Cover).backgroundColor('#1A2332')
        }
      } else if (this.liveInfo.status === 'online' && this.liveInfo.streamUrl.length > 0) {
        if (this.liveVideoError) {
          Stack({ alignContent: Alignment.Center }) {
            Row() {
            }.width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM).backgroundColor('#1A2332')
            Column() {
              Text('🎥').fontSize(this.sf(32)).margin({ bottom: AppSpacing.XS })
              Text('直播预览不可用（视频编码不兼容）')
                .fontSize(this.sf(AppFontSize.Caption)).fontColor('rgba(255,255,255,0.6)')
                .textAlign(TextAlign.Center)
            }
          }
        } else {
          Video({ src: this.resolveUrl(this.liveInfo.streamUrl), controller: this.videoController })
            .width('100%').aspectRatio(16 / 9).borderRadius(AppRadius.SM).controls(true)
            .autoPlay(true)
            .onError(() => {
              console.error('[MonitorView] Live video error, src=' + this.liveInfo.streamUrl);
              this.liveVideoError = true;
            })
        }
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
      Row() {
        this.SectionHeader('监控回放', AppColors.Accent)
      }.width('100%')
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
                Text(item.available ? '▶ 查看' : '待生成')
                  .fontSize(this.sf(AppFontSize.Mini))
                  .fontColor(item.available ? AppColors.Primary : AppColors.TextTertiary)
                  .onClick(() => {
                    if (item.available) {
                      promptAction.showToast({ message: item.date + ' 回放 · ' + item.duration + ' · ' + item.quality, duration: 2000 });
                    }
                  })
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
                  if (item.imageUrl !== undefined && item.imageUrl.length > 0) {
                    Image(this.resolveUrl(item.imageUrl))
                      .width(this.sf(60)).height(this.sf(60))
                      .borderRadius(AppRadius.SM).objectFit(ImageFit.Cover)
                  } else if (this.isSimKeyframePlaceholder(item)) {
                    Image($r('app.media.sim_video_placeholder'))
                      .width(this.sf(60)).height(this.sf(60))
                      .borderRadius(AppRadius.SM).objectFit(ImageFit.Cover)
                  } else {
                    Text('📷').fontSize(this.sf(22))
                  }
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
                this.openKeyframeFullscreen(item);
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
        Scroll() {
          Column({ space: AppSpacing.SM }) {
            ForEach(this.getDisplaySensorMeta(), (meta: SensorMetaItem) => {
              this.SensorCard(meta)
            }, (meta: SensorMetaItem) => meta.key)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').layoutWeight(1).padding(AppSpacing.SM)
    .backgroundColor(AppColors.Surface).borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  // ═══════════════ 设备卡片 ═══════════════

  @Builder
  EquipmentCard(meta: EquipmentMetaItem) {
    Column() {
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
          .enabled(!this.nodeState.smartMode && !this.nodeState.isDebouncing(meta.key))
          .opacity(this.nodeState.smartMode || this.nodeState.isDebouncing(meta.key) ? 0.5 : 1)
          .onChange((isOn: boolean) => {
            if (this.nodeState.getState(meta.key) === isOn) {
              return;
            }
            if (this.nodeState.smartMode) {
              promptAction.showToast({ message: '智能模式下禁止手动操作' });
              return;
            }
            if (this.nodeState.isDebouncing(meta.key)) {
              promptAction.showToast({ message: '操作过于频繁，请稍候' });
              return;
            }
            // Boundary: 手动控制只在“非智能模式且未处于设备冷却期”时生效；状态先本地乐观更新，再等待 MQTT 回显对齐。
            if (this.isSliderControl(meta)) {
              this.nodeState.setValue(meta.key, isOn ? 100 : 0);
              this.nodeState.markCommandSent(meta.key);
              MqttClientService.getInstance().enqueueCommand(this.nodeId, meta.key,
                isOn ? 'turn_on' : 'turn_off');
            } else {
              this.nodeState.setState(meta.key, isOn);
              this.nodeState.markCommandSent(meta.key);
              MqttClientService.getInstance().enqueueCommand(this.nodeId, meta.key,
                isOn ? 'turn_on' : 'turn_off');
            }
            promptAction.showToast({ message: (isOn ? '开启' : '关闭') + ' ' + meta.name });
          })
      }
      .width('100%').height(this.sf(56)).alignItems(VerticalAlign.Center)

      if (this.isSliderControl(meta)) {
        Row() {
          Text('💡').fontSize(this.sf(AppFontSize.Mini))
          Slider({
            value: this.nodeState.getValue(meta.key),
            min: 0,
            max: 100,
            step: 1,
            style: SliderStyle.OutSet
          })
            .blockColor(AppColors.Primary)
            .trackColor(AppColors.Divider)
            .selectedColor(AppColors.PrimaryLight)
            .layoutWeight(1)
            .enabled(this.nodeState.getState(meta.key) && !this.nodeState.smartMode)
            .opacity(this.nodeState.getState(meta.key) && !this.nodeState.smartMode ? 1 : 0.4)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                let brightness = Math.round(value);
                this.nodeState.setValue(meta.key, brightness);
                this.nodeState.markCommandSent(meta.key);
                let brParam: Record<string, number> = {};
                brParam['brightness'] = brightness;
                MqttClientService.getInstance().enqueueCommand(
                  this.nodeId, meta.key, 'set_brightness', brParam);
                promptAction.showToast({ message: meta.name + ' 亮度 ' + brightness + '%' });
              }
            })
          Text(this.nodeState.getValue(meta.key).toString() + '%')
            .fontSize(this.sf(AppFontSize.Mini))
            .fontColor(AppColors.TextSecondary)
            .width(this.sf(36))
            .textAlign(TextAlign.End)
        }
        .width('100%').padding({ left: AppSpacing.SM, right: AppSpacing.SM })
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ left: AppSpacing.SM, right: AppSpacing.SM })
    .backgroundColor(this.nodeState.getState(meta.key) ? AppColors.DeviceOnBg : AppColors.Surface)
    .borderRadius(AppRadius.SM)
    .border({ width: 1, color: this.nodeState.getState(meta.key) ? AppColors.DeviceOnBorder : AppColors.Divider })
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
          .enabled(!this.nodeState.isSmartModeDebouncing())
          .opacity(this.nodeState.isSmartModeDebouncing() ? 0.5 : 1)
          .onChange((isOn: boolean) => {
            if (this.nodeState.smartMode === isOn) {
              return;
            }
            if (this.nodeState.isSmartModeDebouncing()) {
              promptAction.showToast({ message: '操作过于频繁，请稍候' });
              return;
            }
            // Reason: 智能模式切换先更新本地态并写入 smartModeCommandAt，再发命令；这样 Index 里的遥测冷却逻辑才能识别这次用户操作。
            this.nodeState.smartMode = isOn;
            this.nodeState.smartModeCommandAt = Date.now();
            setTimeout(() => {
              this.nodeState.revision++;
            }, NodeState.DEBOUNCE_MS);
            MqttClientService.getInstance().enqueueCommand(this.nodeId, 'mode', isOn ? 'smart' : 'manual');
            promptAction.showToast({ message: '已切换至' + (isOn ? '智能' : '手动') + '模式' });
          })
      }.width('100%').alignItems(VerticalAlign.Center).margin({ bottom: AppSpacing.SM })

      if (this.nodeState.smartMode) {
        Row() {
          Text('🤖').fontSize(this.sf(AppFontSize.Caption))
          Text('智能模式已开启，设备由系统自动控制')
            .fontSize(this.sf(AppFontSize.Mini))
            .fontColor(AppColors.Accent)
            .margin({ left: AppSpacing.XS })
        }
        .width('100%')
        .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.SM })
        .backgroundColor(AppColors.AccentBg)
        .borderRadius(AppRadius.SM)
        .margin({ bottom: AppSpacing.SM })
      }

      Text('').visibility(Visibility.None).fontSize(this.nodeState.revision)

      if (this.equipmentMeta.length === 0) {
        this.EmptyHint('暂无设备配置')
      } else if (this.getDisplayEquipmentMeta().length === 0) {
        this.EmptyHint('等待设备上报状态…')
      } else {
        Scroll() {
          Column({ space: AppSpacing.SM }) {
            ForEach(this.getDisplayEquipmentMeta(), (meta: EquipmentMetaItem) => {
              this.EquipmentCard(meta)
            }, (meta: EquipmentMetaItem) => meta.key)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').layoutWeight(1).padding(AppSpacing.SM)
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

  // ═══════════════ 全屏回放视频覆盖 ═══════════════

  @Builder
  PlaybackFullscreenOverlay() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Text('🎬').fontSize(48).margin({ bottom: AppSpacing.MD })
        Text('回放视频编码不兼容')
          .fontSize(AppFontSize.Body).fontColor('#FFFFFF')
        Text('当前视频为 HEVC 编码，设备暂不支持播放')
          .fontSize(AppFontSize.Caption).fontColor('rgba(255,255,255,0.5)')
          .margin({ top: AppSpacing.XS })
      }
      .width('100%').height('100%')
      .backgroundColor('#000000')
      .justifyContent(FlexAlign.Center)

      Text('✕')
        .fontSize(24).fontColor('#FFFFFF')
        .width(44).height(44).textAlign(TextAlign.Center)
        .borderRadius(AppRadius.Full)
        .backgroundColor('rgba(0,0,0,0.5)')
        .margin({ top: AppSpacing.XXL, right: AppSpacing.LG })
        .onClick(() => {
          this.playbackFullscreenUrl = '';
        })
    }
    .width('100%').height('100%')
  }

  // ═══════════════ 全屏关键帧图片覆盖 ═══════════════

  @Builder
  KeyframeFullscreenOverlay() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        if (this.keyframeFullscreenUseSimPlaceholder) {
          Image($r('app.media.sim_video_placeholder'))
            .width('100%').height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.imageScale, y: this.imageScale })
            .gesture(
              PinchGesture({ fingers: 2 })
                .onActionUpdate((event: GestureEvent) => {
                  let newScale = this.imageScale * event.scale;
                  if (newScale < 0.5) {
                    newScale = 0.5;
                  } else if (newScale > 5) {
                    newScale = 5;
                  }
                  this.imageScale = newScale;
                })
            )
        } else {
          Image(this.keyframeFullscreenUrl)
            .width('100%').height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.imageScale, y: this.imageScale })
            .gesture(
              PinchGesture({ fingers: 2 })
                .onActionUpdate((event: GestureEvent) => {
                  let newScale = this.imageScale * event.scale;
                  if (newScale < 0.5) {
                    newScale = 0.5;
                  } else if (newScale > 5) {
                    newScale = 5;
                  }
                  this.imageScale = newScale;
                })
            )
        }
      }
      .width('100%').height('100%')
      .backgroundColor('#000000')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.closeKeyframeFullscreen();
      })

      Text('✕')
        .fontSize(24).fontColor('#FFFFFF')
        .width(44).height(44).textAlign(TextAlign.Center)
        .borderRadius(AppRadius.Full)
        .backgroundColor('rgba(0,0,0,0.5)')
        .margin({ top: AppSpacing.XXL, right: AppSpacing.LG })
        .onClick(() => {
          this.closeKeyframeFullscreen();
        })
    }
    .width('100%').height('100%')
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
    Stack() {
      Column() {
        if (!this.isNodeConnected()) {
          this.OfflineContent()
        } else if (this.currentBreakpoint === 'lg') {
          Row({ space: AppSpacing.SM }) {
            Scroll() {
              this.LeftColumn()
            }
            .width('55%').height('100%')
            .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)

            Column({ space: AppSpacing.SM }) {
              this.SensorPanel()
              this.ControlPanel()
            }
            .width('45%').height('100%')
          }
          .width('100%').layoutWeight(1)
          .alignItems(VerticalAlign.Top)
        } else if (this.currentBreakpoint === 'md') {
          Row({ space: AppSpacing.SM }) {
            Scroll() {
              this.LeftColumn()
            }
            .width('50%').height('100%')
            .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)

            Column({ space: AppSpacing.SM }) {
              this.SensorPanel()
              this.ControlPanel()
            }
            .width('50%').height('100%')
          }
          .width('100%').layoutWeight(1)
          .alignItems(VerticalAlign.Top)
        } else {
          Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
            TabContent() {
              Scroll() {
                this.LeftColumn()
              }.width('100%').height('100%')
                .scrollBar(BarState.Auto).edgeEffect(EdgeEffect.Spring)
            }.tabBar(this.SmTabBar('📹', '监控', 0))

            TabContent() {
              this.SensorPanel()
            }.tabBar(this.SmTabBar('🌡️', '数据', 1))

            TabContent() {
              this.ControlPanel()
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

      if (this.playbackFullscreenUrl.length > 0) {
        this.PlaybackFullscreenOverlay()
      }
      if (this.keyframeFullscreenUrl.length > 0 || this.keyframeFullscreenUseSimPlaceholder) {
        this.KeyframeFullscreenOverlay()
      }
    }
    .width('100%').height('100%')
  }
}
