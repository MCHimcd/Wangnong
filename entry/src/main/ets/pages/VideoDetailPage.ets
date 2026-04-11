import router from '@ohos.router';
import { AppColors, AppFontSize, AppSpacing, AppRadius } from '../common/DesignToken';

@Entry
@Component
struct VideoDetailPage {
  aboutToAppear(): void {
    // 功能已迁移到 MonitorView
  }

  build() {
    Column() {
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => { router.back(); })
        Text('视频监控详情')
          .fontSize(AppFontSize.H1)
          .fontColor(AppColors.TextPrimary)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: 40, bottom: AppSpacing.LG })
      .alignItems(VerticalAlign.Center)

      Column() {
        Text('📹').fontSize(48).margin({ bottom: AppSpacing.MD })
        Text('回放与关键帧功能已迁移至监控页')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Center)
        Text('请返回主页查看')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextTertiary)
          .margin({ top: AppSpacing.SM })
        Button('返回', { type: ButtonType.Capsule })
          .height(36)
          .fontSize(AppFontSize.Body)
          .backgroundColor(AppColors.Primary)
          .margin({ top: AppSpacing.XL })
          .onClick(() => { router.back(); })
      }
      .width('100%').layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding(AppSpacing.PagePadding)
    }
    .width('100%').height('100%')
    .backgroundColor(AppColors.Background)
  }
}
