import { SensorData } from '../models/SensorData';
import { DeviceState } from '../models/DeviceState';
import { SensorMetaItem } from '../models/SensorMeta';
import { EquipmentMetaItem } from '../models/EquipmentMeta';
import { LiveStreamInfo } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';
import { MqttClientService } from '../services/MqttClientService';
import { HttpService } from '../services/HttpService';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Component
export struct MonitorView {
  @Prop deviceId: string = '';
  @ObjectLink sensorData: SensorData;
  @ObjectLink deviceState: DeviceState;
  @Prop sensorMeta: SensorMetaItem[] = [];
  @Prop equipmentMeta: EquipmentMetaItem[] = [];

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

  aboutToAppear(): void {
    void this.loadVideoInfo();
    void this.bootstrapControlState();
  }

  private async loadVideoInfo(): Promise<void> {
    this.videoLoading = true;
    try {
      this.liveInfo = await VideoMonitorService.getInstance().getLiveStreamInfo(this.deviceId);
    } catch (e) {
      console.error('[MonitorView] loadVideoInfo failed', e);
    } finally {
      this.videoLoading = false;
    }
  }

  private async bootstrapControlState(): Promise<void> {
    if (this.deviceState.controlStateBootstrapped) {
      return;
    }
    const detail = await HttpService.getInstance().getDeviceDetail(this.deviceId);
    if (!detail || !detail.deviceState) {
      return;
    }
    const st: Record<string, boolean | undefined> = detail.deviceState;
    const keys = Object.keys(st);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] === 'smartMode') {
        this.deviceState.smartMode = Boolean(st[keys[i]]);
      } else {
        this.deviceState.setState(keys[i], Boolean(st[keys[i]]));
      }
    }
    this.deviceState.controlStateBootstrapped = true;
  }

  /** 传感器卡片 isWarning 判定 */
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
  SensorSection() {
    Column() {
      Text('环境数据')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2C3E50')
        .width('100%')
        .margin({ bottom: 12 })

      // 触发依赖
      Text('').visibility(Visibility.None).fontSize(this.sensorData.revision)

      if (this.sensorMeta.length === 0) {
        Text('暂无传感器配置')
          .fontSize(14)
          .fontColor('#90A4AE')
          .margin({ top: 8, bottom: 8 })
      } else {
        List({ space: 12 }) {
          ForEach(this.sensorMeta, (meta: SensorMetaItem) => {
            ListItem() {
              this.SensorCard(meta)
            }
          }, (meta: SensorMetaItem) => meta.key)
        }
        .listDirection(Axis.Horizontal)
        .width('100%')
        .height(140)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  @Builder
  SensorCard(meta: SensorMetaItem) {
    Column() {
      Row() {
        Text(meta.icon).fontSize(18).margin({ right: 6 })
        Text(meta.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#546E7A')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      Row() {
        Text(this.formatValue(meta))
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key)) ? '#D32F2F' : '#263238')
        if (meta.unit.length > 0) {
          Text(meta.unit)
            .fontSize(13)
            .fontColor(this.isWarning(meta, this.sensorData.getValue(meta.key)) ? '#E57373' : '#78909C')
            .margin({ left: 3, bottom: 4 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .width(140)
    .height(110)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .padding(14)
    .justifyContent(FlexAlign.Center)
    .shadow({ radius: 10, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SensorDetailPage',
        params: {
          deviceId: this.deviceId,
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
        Text('实时监控')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')
        Blank()
        Text(this.liveInfo.status === 'online' ? '在线' : '离线')
          .fontSize(12)
          .fontColor(this.liveInfo.status === 'online' ? '#2E7D32' : '#C62828')
          .backgroundColor(this.liveInfo.status === 'online' ? '#E8F5E9' : '#FFEBEE')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.liveInfo.status === 'online' && this.liveInfo.streamUrl.length > 0) {
        Video({ src: this.liveInfo.streamUrl, controller: this.videoController })
          .width('100%')
          .aspectRatio(16 / 9)
          .borderRadius(16)
          .controls(true)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Row() {}.width('100%').aspectRatio(16 / 9).borderRadius(16).backgroundColor('#1F2A37')
          Text('视频流不可用')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
      }

      Row() {
        Column() {
          Text(this.liveInfo.cameraName)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2C3E50')
          Text(`${this.liveInfo.streamTag} · ${this.liveInfo.resolution}`)
            .fontSize(12)
            .fontColor('#78909C')
            .margin({ top: 4 })
        }
        Blank()
        Button('查看回放')
          .height(32)
          .fontSize(13)
          .backgroundColor('#4CAF50')
          .onClick(() => {
            router.pushUrl({
              url: 'pages/VideoDetailPage',
              params: { deviceId: this.deviceId }
            });
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  @Builder
  ControlSection() {
    Column() {
      Row() {
        Text('设备控制')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')
        Blank()
        Text('智能模式')
          .fontSize(14)
          .fontColor('#34495E')
          .margin({ right: 8 })
        Toggle({ type: ToggleType.Switch, isOn: this.deviceState.smartMode })
          .selectedColor('#4CAF50')
          .onChange((isOn: boolean) => {
            this.deviceState.smartMode = isOn;
            MqttClientService.getInstance().publishCommand(this.deviceId, 'mode', isOn ? 'smart' : 'manual');
            promptAction.showToast({ message: `已切换至${isOn ? '智能' : '手动'}模式` });
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 触发依赖
      Text('').visibility(Visibility.None).fontSize(this.deviceState.revision)

      if (this.equipmentMeta.length === 0) {
        Text('暂无设备配置')
          .fontSize(14)
          .fontColor('#90A4AE')
          .margin({ top: 8, bottom: 8 })
      } else {
        List({ space: 12 }) {
          ForEach(this.equipmentMeta, (meta: EquipmentMetaItem) => {
            ListItem() {
              this.EquipmentCard(meta)
            }
          }, (meta: EquipmentMetaItem) => meta.key)
        }
        .listDirection(Axis.Horizontal)
        .width('100%')
        .height(160)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  @Builder
  EquipmentCard(meta: EquipmentMetaItem) {
    Column() {
      Text(meta.icon)
        .fontSize(32)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      Text(meta.name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#212B25')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      Button({ type: ButtonType.Capsule }) {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.deviceState.getState(meta.key) ? '#2E7D32' : '#B0B7B0')
            .margin({ right: 6 })
          Text(this.deviceState.getState(meta.key) ? '运行中' : '已停止')
            .fontSize(13)
            .fontColor(this.deviceState.getState(meta.key) ? '#2E7D32' : '#7B847D')
        }
      }
      .width('82%')
      .height(32)
      .backgroundColor(this.deviceState.getState(meta.key) ? '#E5F3E7' : '#F4F5F4')
      .border({
        width: 1,
        color: this.deviceState.getState(meta.key) ? '#92C69A' : '#D9DFDA'
      })
      .opacity(this.deviceState.smartMode ? 0.6 : 1.0)
      .onClick(() => {
        if (this.deviceState.smartMode) {
          return;
        }
        const newState = !this.deviceState.getState(meta.key);
        MqttClientService.getInstance().publishCommand(
          this.deviceId, meta.key, newState ? 'turn_on' : 'turn_off'
        );
        promptAction.showToast({ message: `已发送${newState ? '开启' : '关闭'}指令` });
      })
    }
    .width(140)
    .height(140)
    .backgroundColor(this.deviceState.getState(meta.key) ? '#EAF4EA' : '#FFFFFF')
    .border({ width: 2, color: this.deviceState.getState(meta.key) ? '#6AAA71' : '#D8DEDA' })
    .borderRadius(16)
    .padding(10)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/DeviceDetailPage',
        params: { type: meta.key, title: meta.name, isOn: this.deviceState.getState(meta.key) }
      });
    })
  }

  build() {
    Column({ space: 14 }) {
      this.VideoSection()
      this.SensorSection()
      this.ControlSection()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 26 })
    .backgroundColor('#F2F6F3')
  }
}
