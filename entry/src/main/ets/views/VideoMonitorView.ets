import { promptAction } from '@kit.ArkUI';
import { KeyframeImageItem, LiveStreamInfo, PlaybackItem } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';

@Component
export struct VideoMonitorView {
  @Prop deviceId: string = '';
  private videoController: VideoController = new VideoController();

  onRefreshLive: (() => void) | null = null;
  onOpenPlayback: ((item: PlaybackItem) => void) | null = null;
  onPreviewKeyframe: ((item: KeyframeImageItem) => void) | null = null;

  @State liveInfo: LiveStreamInfo = {
    cameraId: '',
    cameraName: '视频源加载中',
    status: 'offline',
    streamTag: '--',
    resolution: '--',
    lastHeartbeat: '--',
    streamUrl: ''
  };
  @State playbackItems: PlaybackItem[] = [];
  @State keyframes: KeyframeImageItem[] = [];
  @State abnormalFrames: KeyframeImageItem[] = [];
  @State selectedDate: string = '';
  @State isLoading: boolean = false;
  @State loadError: string = '';

  aboutToAppear() {
    void this.loadData();
  }

  private async loadData() {
    this.isLoading = true;
    this.loadError = '';
    try {
      const service = VideoMonitorService.getInstance();
      this.liveInfo = await service.getLiveStreamInfo(this.deviceId);
      this.playbackItems = await service.getDailyPlaybackList(this.deviceId);

      if (this.playbackItems.length > 0) {
        this.selectedDate = this.playbackItems[0].date;
        this.applyKeyframes(await service.getKeyframesByDate(this.deviceId, this.selectedDate));
      } else {
        this.selectedDate = '';
        this.applyKeyframes([]);
      }
    } catch (error) {
      this.loadError = '视频数据加载失败，请检查后端服务和网络';
      this.playbackItems = [];
      this.selectedDate = '';
      this.applyKeyframes([]);
      promptAction.showToast({ message: this.loadError, duration: 1800 });
      console.error('[VideoMonitorView] loadData failed', error);
    } finally {
      this.isLoading = false;
    }
  }

  private applyKeyframes(frames: KeyframeImageItem[]) {
    this.keyframes = frames;
    this.abnormalFrames = frames.filter((item: KeyframeImageItem) => item.isAbnormal);
  }

  private async onSelectPlayback(item: PlaybackItem) {
    try {
      this.selectedDate = item.date;
      this.applyKeyframes(await VideoMonitorService.getInstance().getKeyframesByDate(this.deviceId, item.date));
    } catch (error) {
      this.loadError = '关键帧加载失败，请检查后端服务';
      promptAction.showToast({ message: this.loadError, duration: 1800 });
      console.error('[VideoMonitorView] onSelectPlayback failed', error);
      return;
    }

    if (this.onOpenPlayback) {
      this.onOpenPlayback(item);
    }
  }

  private onClickKeyframe(item: KeyframeImageItem) {
    if (this.onPreviewKeyframe) {
      this.onPreviewKeyframe(item);
    } else {
      promptAction.showToast({ message: `${item.label} ${item.captureTime}`, duration: 1800 });
    }
  }

  private statusText(): string {
    return this.liveInfo.status === 'online' ? '在线' : '离线';
  }

  private statusFontColor(): string {
    return this.liveInfo.status === 'online' ? '#2E7D32' : '#C62828';
  }

  private statusBackgroundColor(): string {
    return this.liveInfo.status === 'online' ? '#E8F5E9' : '#FFEBEE';
  }

  @Builder
  LiveSection() {
    Column() {
      Row() {
        Text('实时监控画面')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')

        Blank()

        Text(this.statusText())
          .fontSize(12)
          .fontColor(this.statusFontColor())
          .backgroundColor(this.statusBackgroundColor())
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.liveInfo.status === 'online' && this.liveInfo.streamUrl.length > 0) {
        Video({ src: this.liveInfo.streamUrl, controller: this.videoController })
          .width('100%')
          .height(198)
          .borderRadius(18)
          .controls(true)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Row() {}
            .width('100%')
            .height(198)
            .borderRadius(18)
            .backgroundColor('#1F2A37')

          Column() {
            Text('视频流不可用')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
            if (this.loadError.length > 0) {
              Text(this.loadError)
                .fontSize(12)
                .fontColor('#FFCDD2')
                .margin({ top: 8 })
            }
          }
        }
      }

      Row() {
        Column() {
          Text(this.liveInfo.cameraName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#2C3E50')
          Text(`${this.liveInfo.streamTag} · ${this.liveInfo.resolution}`)
            .fontSize(13)
            .fontColor('#78909C')
            .margin({ top: 4 })
          Text(`最后心跳：${this.liveInfo.lastHeartbeat}`)
            .fontSize(12)
            .fontColor('#90A4AE')
            .margin({ top: 4 })
          Text(`流地址：${this.liveInfo.streamUrl.length > 0 ? this.liveInfo.streamUrl : '--'}`)
            .fontSize(12)
            .fontColor('#607D8B')
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Blank()

        Button('刷新画面')
          .height(34)
          .fontSize(14)
          .backgroundColor('#4CAF50')
          .onClick(() => {
            if (this.onRefreshLive) {
              this.onRefreshLive();
            } else {
              void this.loadData();
            }
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  @Builder
  PlaybackSection() {
    Column() {
      Text('监控回放（每日一个视频）')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2C3E50')
        .width('100%')
        .margin({ bottom: 12 })

      if (this.playbackItems.length === 0) {
        Text(this.isLoading ? '加载中...' : '暂无回放记录')
          .fontSize(14)
          .fontColor('#90A4AE')
          .margin({ top: 8, bottom: 8 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.playbackItems, (item: PlaybackItem) => {
            Row() {
              Column() {
                Text(item.date)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#2C3E50')
                Text(`时长 ${item.duration} · ${item.quality}`)
                  .fontSize(12)
                  .fontColor('#78909C')
                  .margin({ top: 4 })
              }

              Blank()

              Text(item.available ? '可回放' : '待生成')
                .fontSize(12)
                .fontColor(item.available ? '#2E7D32' : '#F57C00')
                .backgroundColor(item.available ? '#E8F5E9' : '#FFF3E0')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(10)
                .margin({ right: 10 })

              Text(`异常 ${item.abnormalCount}`)
                .fontSize(12)
                .fontColor(item.abnormalCount > 0 ? '#C62828' : '#607D8B')
                .backgroundColor(item.abnormalCount > 0 ? '#FFEBEE' : '#ECEFF1')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(10)
                .margin({ right: 10 })

              Button('查看')
                .height(30)
                .fontSize(13)
                .enabled(item.available)
                .backgroundColor(item.available ? '#4CAF50' : '#CFD8DC')
                .onClick(() => {
                  this.onSelectPlayback(item);
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(item.date === this.selectedDate ? '#F1F8E9' : '#FAFAFA')
            .borderRadius(14)
            .shadow({
              radius: item.date === this.selectedDate ? 8 : 2,
              color: item.date === this.selectedDate ? 'rgba(139,195,74,0.25)' : 'rgba(0,0,0,0.05)',
              offsetY: item.date === this.selectedDate ? 4 : 1
            })
          }, (item: PlaybackItem) => item.id)
        }
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  @Builder
  KeyframeSection() {
    Column() {
      Row() {
        Text('AI异常关键帧图片')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')

        Blank()

        Text(this.selectedDate.length > 0 ? this.selectedDate : '未选择日期')
          .fontSize(12)
          .fontColor('#78909C')
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.abnormalFrames.length === 0) {
        Text('当前日期未检测到异常关键帧')
          .fontSize(14)
          .fontColor('#90A4AE')
          .margin({ top: 8, bottom: 8 })
      } else {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.abnormalFrames, (item: KeyframeImageItem) => {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Row() {}
                  .width('100%')
                  .height(88)
                  .borderRadius(12)
                  .backgroundColor(item.severity === 'critical' ? '#FFCDD2' : '#FFE0B2')

                Text(item.thumbnailHint)
                  .fontSize(30)
              }

              Row() {
                Text(item.severity === 'critical' ? '高危异常' : '一般异常')
                  .fontSize(11)
                  .fontColor(item.severity === 'critical' ? '#B71C1C' : '#E65100')
                  .backgroundColor(item.severity === 'critical' ? '#FFEBEE' : '#FFF3E0')
                  .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                  .borderRadius(8)

                Blank()

                Text(item.captureTime)
                  .fontSize(12)
                  .fontColor('#546E7A')
              }
              .width('100%')
              .margin({ top: 8 })

              Text(`${item.abnormalType} · 置信度 ${item.confidence.toFixed(1)}%`)
                .fontSize(12)
                .fontColor('#90A4AE')
                .margin({ top: 2 })

              Text(item.label)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#37474F')
                .margin({ top: 2 })
            }
            .width('48%')
            .padding(10)
            .margin({ bottom: 12 })
            .backgroundColor(item.severity === 'critical' ? '#FFF5F5' : '#FFFDF8')
            .borderRadius(14)
            .onClick(() => {
              this.onClickKeyframe(item);
            })
          }, (item: KeyframeImageItem) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .padding(16)
    .shadow({ radius: 12, color: 'rgba(76,175,80,0.08)', offsetY: 4 })
  }

  build() {
    Column({ space: 14 }) {
      Text('视频监控中心')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#2C3E50')
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 20, bottom: 4 })

      this.LiveSection()
      this.PlaybackSection()
      this.KeyframeSection()
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 26 })
    .backgroundColor('#F2F6F3')
  }
}
