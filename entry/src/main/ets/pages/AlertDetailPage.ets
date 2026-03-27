import router from '@ohos.router';
import { AlertData } from '../models/AlertData';
import { AlertSyncService } from '../services/AlertSyncService';
import { promptAction } from '@kit.ArkUI';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

@Entry
@Component
struct AlertDetailPage {
  @State alert: AlertData = new AlertData();
  @State loaded: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['alertId']) {
      let alertId = params['alertId'] as string;
      let all = AlertSyncService.getInstance().getAllAlerts();
      let found = all.find((a: AlertData) => a.alert_id === alertId);
      if (found) {
        this.alert = found;
        this.loaded = true;
      }
    }
  }

  formatDate(timestamp: number): string {
    let date = new Date(timestamp);
    let y = date.getFullYear();
    let m = (date.getMonth() + 1).toString().padStart(2, '0');
    let d = date.getDate().toString().padStart(2, '0');
    let h = date.getHours().toString().padStart(2, '0');
    let min = date.getMinutes().toString().padStart(2, '0');
    let s = date.getSeconds().toString().padStart(2, '0');
    return `${y}-${m}-${d} ${h}:${min}:${s}`;
  }

  getLevelText(level: string): string {
    if (level === 'critical') return '严重';
    if (level === 'warning') return '警告';
    return '信息';
  }

  getLevelColor(level: string): string {
    if (level === 'critical') return AppColors.AlertCritical;
    if (level === 'warning') return AppColors.AlertWarning;
    return AppColors.AlertInfo;
  }

  getLevelBg(level: string): string {
    if (level === 'critical') return AppColors.AlertCriticalBg;
    if (level === 'warning') return AppColors.AlertWarningBg;
    return AppColors.AlertInfoBg;
  }

  async markAsHandled() {
    const success = await AlertSyncService.getInstance().markHandled(this.alert.alert_id);
    if (success) {
      this.alert.is_handled = true;
      this.alert.handle_time = Date.now();
      promptAction.showToast({ message: '标记成功' });
    } else {
      promptAction.showToast({ message: '标记失败' });
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24).margin({ right: AppSpacing.MD }).fillColor(AppColors.TextPrimary)
          .onClick(() => { router.back(); })
        Text('告警详情')
          .fontSize(AppFontSize.H2).fontWeight(FontWeight.Bold).fontColor(AppColors.TextPrimary).layoutWeight(1)
      }
      .width('100%').height(56).padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })

      if (!this.loaded) {
        Column() {
          Text('🔔').fontSize(48).margin({ bottom: AppSpacing.MD })
          Text('告警数据未找到').fontSize(AppFontSize.Body).fontColor(AppColors.TextTertiary)
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // Level badge bar
            Row() {
              Row() {}
                .width(4).height(20).borderRadius(2)
                .backgroundColor(this.getLevelColor(this.alert.level))
                .margin({ right: AppSpacing.SM })
              Text(this.getLevelText(this.alert.level))
                .fontSize(AppFontSize.Body).fontWeight(FontWeight.Bold)
                .fontColor(this.getLevelColor(this.alert.level))
              Blank()
              Text(this.alert.is_handled ? '✓ 已处理' : '● 待处理')
                .fontSize(AppFontSize.Caption)
                .fontColor(this.alert.is_handled ? AppColors.Success : AppColors.AlertCritical)
                .backgroundColor(this.alert.is_handled ? AppColors.SuccessBg : AppColors.AlertCriticalBg)
                .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
                .borderRadius(AppRadius.Full)
            }
            .width('100%').padding(AppSpacing.LG).backgroundColor(AppColors.Surface).borderRadius(AppRadius.MD)
            .margin({ top: AppSpacing.MD })

            // Details card
            Column() {
              this.DetailRow('告警类型', this.alert.type_name)
              this.DetailRow('告警来源', this.alert.source_name)
              this.DetailRow('所属节点', this.alert.alert_id.split('_').slice(0, 3).join('_'))
              this.DetailRow('触发时间', this.formatDate(this.alert.timestamp))
              if (this.alert.is_handled && this.alert.handle_time) {
                this.DetailRow('处理时间', this.formatDate(this.alert.handle_time))
              }
            }
            .width('100%').padding(AppSpacing.LG).backgroundColor(AppColors.Surface).borderRadius(AppRadius.MD)
            .margin({ top: AppSpacing.SM })

            // Message
            Column() {
              Text('告警详情').fontSize(AppFontSize.H3).fontWeight(FontWeight.Medium).fontColor(AppColors.TextPrimary)
                .margin({ bottom: AppSpacing.SM })
              Text(this.alert.message)
                .fontSize(AppFontSize.Body).fontColor(AppColors.TextSecondary).lineHeight(22)
            }
            .width('100%').padding(AppSpacing.LG).backgroundColor(AppColors.Surface).borderRadius(AppRadius.MD)
            .margin({ top: AppSpacing.SM })
            .alignItems(HorizontalAlign.Start)

            // Action button
            if (!this.alert.is_handled) {
              Button('标记为已处理', { type: ButtonType.Capsule })
                .width('80%').height(AppSize.ButtonHeight).fontSize(AppFontSize.Body)
                .backgroundColor(AppColors.Primary)
                .margin({ top: AppSpacing.XXL })
                .onClick(() => { this.markAsHandled(); })
            }
          }
          .width('100%')
          .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor(AppColors.Background)
  }

  @Builder DetailRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(AppFontSize.Body).fontColor(AppColors.TextTertiary).width(80)
      Text(value).fontSize(AppFontSize.Body).fontColor(AppColors.TextPrimary).layoutWeight(1)
    }
    .width('100%').padding({ top: AppSpacing.SM, bottom: AppSpacing.SM })
  }
}
