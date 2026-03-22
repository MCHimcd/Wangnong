import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { KeyframeImageItem, PlaybackItem } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';

@Entry
@Component
struct VideoDetailPage {
  @State nodeId: string = '';
  @State playbackItems: PlaybackItem[] = [];
  @State keyframes: KeyframeImageItem[] = [];
  @State abnormalFrames: KeyframeImageItem[] = [];
  @State selectedDate: string = '';
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.nodeId = params['nodeId'] ?? '';
    }
    void this.loadData();
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const service = VideoMonitorService.getInstance();
      this.playbackItems = await service.getDailyPlaybackList(this.nodeId);
      if (this.playbackItems.length > 0) {
        this.selectedDate = this.playbackItems[0].date;
        this.applyKeyframes(await service.getKeyframesByDate(this.nodeId, this.selectedDate));
      }
    } catch (e) {
      promptAction.showToast({ message: '数据加载失败', duration: 1800 });
      console.error('[VideoDetailPage] loadData failed', e);
    } finally {
      this.isLoading = false;
    }
  }

  private applyKeyframes(frames: KeyframeImageItem[]): void {
    this.keyframes = frames;
    this.abnormalFrames = frames.filter((item: KeyframeImageItem) => item.isAbnormal);
  }

  private async onSelectPlayback(item: PlaybackItem): Promise<void> {
    try {
      this.selectedDate = item.date;
      this.applyKeyframes(await VideoMonitorService.getInstance().getKeyframesByDate(this.nodeId, item.date));
    } catch (e) {
      promptAction.showToast({ message: '关键帧加载失败', duration: 1800 });
    }
  }

  @Builder
  PlaybackSection() {
    Column() {
      Text('监控回放')
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
                  void this.onSelectPlayback(item);
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(item.date === this.selectedDate ? '#F1F8E9' : '#FAFAFA')
            .borderRadius(14)
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
        Text('AI异常关键帧')
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
        Column({ space: 12 }) {
          ForEach(this.abnormalFrames, (item: KeyframeImageItem) => {
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Row() {}
                  .width(88)
                  .height(88)
                  .borderRadius(12)
                  .backgroundColor(item.severity === 'critical' ? '#FFCDD2' : '#FFE0B2')
                Text(item.thumbnailHint)
                  .fontSize(30)
              }
              .margin({ right: 12 })

              Column() {
                Row() {
                  Text(item.severity === 'critical' ? '高危异常' : '一般异常')
                    .fontSize(11)
                    .fontColor(item.severity === 'critical' ? '#B71C1C' : '#E65100')
                    .backgroundColor(item.severity === 'critical' ? '#FFEBEE' : '#FFF3E0')
                    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                    .borderRadius(8)
                  Text(item.captureTime)
                    .fontSize(12)
                    .fontColor('#546E7A')
                    .margin({ left: 8 })
                }

                Text(`${item.abnormalType} · 置信度 ${item.confidence.toFixed(1)}%`)
                  .fontSize(12)
                  .fontColor('#90A4AE')
                  .margin({ top: 4 })
                Text(item.label)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#37474F')
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(item.severity === 'critical' ? '#FFF5F5' : '#FFFDF8')
            .borderRadius(14)
            .onClick(() => {
              promptAction.showToast({ message: `${item.label} ${item.captureTime}`, duration: 1800 });
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
    Column() {
      // Header
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(28)
          .height(28)
          .margin({ right: 15 })
          .fillColor('#2C3E50')
          .onClick(() => {
            router.back();
          })
        Text('视频监控详情')
          .fontSize(24)
          .fontColor('#2C3E50')
          .fontWeight(FontWeight.Bolder)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 40, bottom: 20 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          this.PlaybackSection()
          this.KeyframeSection()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 26 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
