import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { KeyframeImageItem, PlaybackItem } from '../models/VideoMonitorData';
import { VideoMonitorService } from '../services/VideoMonitorService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

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
        .fontSize(AppFontSize.H2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')
        .margin({ bottom: AppSpacing.MD })

      if (this.playbackItems.length === 0) {
        Text(this.isLoading ? '加载中...' : '暂无回放记录')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else {
        Column({ space: 10 }) {
          ForEach(this.playbackItems, (item: PlaybackItem) => {
            Row() {
              Column() {
                Text(item.date)
                  .fontSize(AppFontSize.H3)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TextPrimary)
                Text(`时长 ${item.duration} · ${item.quality}`)
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.TextTertiary)
                  .margin({ top: AppSpacing.XS })
              }
              Blank()
              Text(item.available ? '可回放' : '待生成')
                .fontSize(AppFontSize.Caption)
                .fontColor(item.available ? AppColors.Primary : AppColors.AlertWarning)
                .backgroundColor(item.available ? AppColors.SuccessBg : AppColors.AlertWarningBg)
                .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
                .borderRadius(AppRadius.SM)
                .margin({ right: AppSpacing.SM })
              Text(`异常 ${item.abnormalCount}`)
                .fontSize(AppFontSize.Caption)
                .fontColor(item.abnormalCount > 0 ? AppColors.AlertCritical : AppColors.TextSecondary)
                .backgroundColor(item.abnormalCount > 0 ? AppColors.AlertCriticalBg : AppColors.Divider)
                .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
                .borderRadius(AppRadius.SM)
                .margin({ right: AppSpacing.SM })
              Button('查看')
                .height(30)
                .fontSize(AppFontSize.Caption)
                .enabled(item.available)
                .backgroundColor(item.available ? AppColors.Primary : AppColors.Border)
                .borderRadius(AppRadius.SM)
                .onClick(() => {
                  void this.onSelectPlayback(item);
                })
            }
            .width('100%')
            .padding(AppSpacing.MD)
            .backgroundColor(item.date === this.selectedDate ? AppColors.SuccessBg : AppColors.Background)
            .borderRadius(AppRadius.LG)
          }, (item: PlaybackItem) => item.id)
        }
      }
    }
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .padding(AppSpacing.PagePadding)
    .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  KeyframeSection() {
    Column() {
      Row() {
        Text('AI异常关键帧')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
        Blank()
        Text(this.selectedDate.length > 0 ? this.selectedDate : '未选择日期')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextTertiary)
      }
      .width('100%')
      .margin({ bottom: AppSpacing.MD })

      if (this.abnormalFrames.length === 0) {
        Text('当前日期未检测到异常关键帧')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
      } else {
        Column({ space: 12 }) {
          ForEach(this.abnormalFrames, (item: KeyframeImageItem) => {
            Row() {
              Stack({ alignContent: Alignment.Center }) {
                Row() {}
                  .width(88)
                  .height(88)
                  .borderRadius(AppRadius.MD)
                  .backgroundColor(item.severity === 'critical' ? AppColors.AlertCriticalBg : AppColors.AlertWarningBg)
                Text(item.thumbnailHint)
                  .fontSize(30)
              }
              .margin({ right: AppSpacing.MD })

              Column() {
                Row() {
                  Text(item.severity === 'critical' ? '高危异常' : '一般异常')
                    .fontSize(AppFontSize.Mini)
                    .fontColor(item.severity === 'critical' ? AppColors.AlertCritical : AppColors.AlertWarning)
                    .backgroundColor(item.severity === 'critical' ? AppColors.AlertCriticalBg : AppColors.AlertWarningBg)
                    .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                    .borderRadius(AppRadius.SM)
                  Text(item.captureTime)
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextSecondary)
                    .margin({ left: AppSpacing.SM })
                }

                Text(`${item.abnormalType} · 置信度 ${item.confidence.toFixed(1)}%`)
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.TextTertiary)
                  .margin({ top: AppSpacing.XS })
                Text(item.label)
                  .fontSize(AppFontSize.Body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.TextPrimary)
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(AppSpacing.MD)
            .backgroundColor(item.severity === 'critical' ? '#FFF5F5' : '#FFFDF8')
            .borderRadius(AppRadius.LG)
            .onClick(() => {
              promptAction.showToast({ message: `${item.label} ${item.captureTime}`, duration: 1800 });
            })
          }, (item: KeyframeImageItem) => item.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .padding(AppSpacing.PagePadding)
    .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  build() {
    Column() {
      // Header
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24)
          .height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => {
            router.back();
          })
        Text('视频监控详情')
          .fontSize(AppFontSize.H1)
          .fontColor(AppColors.TextPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: 40, bottom: AppSpacing.LG })
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
    .backgroundColor(AppColors.Background)
  }
}
