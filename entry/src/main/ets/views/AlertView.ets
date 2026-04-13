import { AlertData } from '../models/AlertData';
import { promptAction } from '@kit.ArkUI';
import { AlertSyncService } from '../services/AlertSyncService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';
import router from '@ohos.router';

/**
 * Purpose: 展示全局告警列表，并提供排序、查看详情和标记处理操作。
 * Responsibilities: 订阅 AlertSyncService 的数据变化、在本地按当前排序规则重排，并驱动详情页导航。
 * Flow: aboutToAppear() 订阅并启动实时同步；告警变化后通过 onDataChange 刷新列表；用户可进入详情或直接标记处理。
 * Dependencies: 依赖 AlertSyncService、router 和 DesignToken。
 * Input: 告警同步服务中的全量告警数据，以及当前排序方式。
 * Output: 排序后的告警列表 UI 和处理动作请求。
 * Boundary: 列表页只做展示排序，不在这里定义告警去重或全局弹窗策略。
 */
@Component
export struct AlertView {
  @State alerts: AlertData[] = [];
  @State sortBy: string = 'timestamp';
  @State order: string = 'desc';
  @State highlightedAlertId: string = '';
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  private onDataChange = () => {
    this.alerts = AlertSyncService.getInstance().getAllAlerts();
    this.sortAlertsLocally();
  }

  aboutToAppear() {
    // Flow: 进入页面即订阅内存态更新，保证处理状态和 MQTT 新告警能即时反映到当前列表。
    AlertSyncService.getInstance().subscribeDataChange(this.onDataChange);
    AlertSyncService.getInstance().startRealtimeSync();
    this.alerts = AlertSyncService.getInstance().getAllAlerts();
    this.sortAlertsLocally();
  }

  aboutToDisappear() {
    AlertSyncService.getInstance().unsubscribeDataChange(this.onDataChange);
  }

  sortAlertsLocally() {
    // Reason: 服务层维护的是统一告警池；排序属于当前视图偏好，放在本地处理可避免影响其他消费方。
    this.alerts = this.alerts.sort((a, b) => {
      let result = 0;
      if (this.sortBy === 'timestamp') {
        result = b.timestamp - a.timestamp;
      } else if (this.sortBy === 'type') {
        result = a.type_name.localeCompare(b.type_name);
      }
      return this.order === 'desc' ? result : -result;
    });
  }

  async markAsHandled(alertId: string) {
    const success = await AlertSyncService.getInstance().markHandled(alertId);
    if (success) {
      promptAction.showToast({ message: '标记成功' });
    } else {
      promptAction.showToast({ message: '标记失败，请检查后端连接' });
    }
  }

  formatDate(timestamp: number): string {
    let date = new Date(timestamp);
    let m = date.getMonth() + 1;
    let d = date.getDate();
    let h = date.getHours().toString().padStart(2, '0');
    let min = date.getMinutes().toString().padStart(2, '0');
    return `${m}-${d} ${h}:${min}`;
  }

  getLevelColor(level: string): string {
    if (level === 'critical') {
      return AppColors.AlertCritical;
    }
    if (level === 'warning') {
      return AppColors.AlertWarning;
    }
    return AppColors.AlertInfo;
  }

  getLevelBg(level: string): string {
    if (level === 'critical') {
      return AppColors.AlertCriticalBg;
    }
    if (level === 'warning') {
      return AppColors.AlertWarningBg;
    }
    return AppColors.AlertInfoBg;
  }

  build() {
    Column() {
      // 标题
      Text('告警消息')
        .fontSize(AppFontSize.H1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')
        .margin({ top: AppSpacing.XL, bottom: AppSpacing.LG })
        .padding({ left: AppSpacing.PagePadding })

      // 排序工具条（使用 Select 组件，保证交互可靠）
      Row() {
        Text('排序:')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextSecondary)
        Select([{ value: '时间' }, { value: '类型' }])
          .selected(this.sortBy === 'timestamp' ? 0 : 1)
          .value(this.sortBy === 'timestamp' ? '时间' : '类型')
          .onSelect((index: number) => {
            this.sortBy = index === 0 ? 'timestamp' : 'type';
            this.sortAlertsLocally();
          })
          .height(32)
          .margin({ left: AppSpacing.SM })

        Select([{ value: '降序' }, { value: '升序' }])
          .selected(this.order === 'desc' ? 0 : 1)
          .value(this.order === 'desc' ? '降序' : '升序')
          .onSelect((index: number) => {
            this.order = index === 0 ? 'desc' : 'asc';
            this.sortAlertsLocally();
          })
          .height(32)
          .margin({ left: AppSpacing.SM })

        Blank()
        Row() {
          Circle({ width: 6, height: 6 })
            .fill(AppColors.Success)
            .margin({ right: AppSpacing.XS })
          Text('实时同步')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.Success)
        }
      }
      .width('100%')
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM, bottom: AppSpacing.SM })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })

      if (this.alerts.length === 0) {
        Column() {
          Text('🔔').fontSize(48).margin({ bottom: AppSpacing.MD })
          Text('暂无告警消息')
            .fontSize(AppFontSize.H3)
            .fontColor(AppColors.TextTertiary)
        }
        .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: AppSpacing.MD }) {
          ForEach(this.alerts, (alert: AlertData) => {
            ListItem() {
              Column() {
                Row() {
                  Circle({ width: 10, height: 10 })
                    .fill(this.getLevelColor(alert.level))
                    .margin({ right: AppSpacing.SM })
                  Text(alert.type_name)
                    .fontSize(AppFontSize.H3)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.TextPrimary)
                  Text(alert.source_name)
                    .fontSize(AppFontSize.Mini)
                    .fontColor(AppColors.TextSecondary)
                    .backgroundColor(AppColors.Divider)
                    .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 2, bottom: 2 })
                    .borderRadius(AppRadius.SM)
                    .margin({ left: AppSpacing.SM })
                  Blank()
                  Text(this.formatDate(alert.timestamp))
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextTertiary)
                }.width('100%')

                Text(alert.message)
                  .fontSize(AppFontSize.Body)
                  .fontColor(AppColors.TextSecondary)
                  .margin({ top: AppSpacing.SM, bottom: AppSpacing.SM })
                  .lineHeight(20)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  Text(alert.is_handled ? '✓ 已处理' : '● 待处理')
                    .fontSize(AppFontSize.Caption)
                    .fontColor(alert.is_handled ? AppColors.Success : AppColors.AlertCritical)
                    .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 2, bottom: 2 })
                    .backgroundColor(alert.is_handled ? AppColors.SuccessBg : AppColors.AlertCriticalBg)
                    .borderRadius(AppRadius.SM)

                  Blank()

                  if (!alert.is_handled) {
                    Button('标记处理', { type: ButtonType.Capsule })
                      .height(26)
                      .fontSize(AppFontSize.Caption)
                      .backgroundColor(AppColors.Primary)
                      .onClick(() => {
                        this.markAsHandled(alert.alert_id);
                      })
                  } else if (alert.handle_time) {
                    Text(`处理于 ${this.formatDate(alert.handle_time)}`)
                      .fontSize(AppFontSize.Caption)
                      .fontColor(AppColors.TextTertiary)
                  }
                }.width('100%').alignItems(VerticalAlign.Center)
              }
              .padding(AppSpacing.LG)
              .backgroundColor(alert.alert_id === this.highlightedAlertId ? '#FFF8E1' : AppColors.Surface)
              .borderRadius(AppRadius.MD)
              .border({ width: { left: 4 }, color: { left: this.getLevelColor(alert.level) } })
              .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
              .width('100%')
              .onClick(() => {
                router.pushUrl({ url: 'pages/AlertDetailPage', params: { alertId: alert.alert_id } });
              })
            }
          })
        }
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM, bottom: AppSpacing.LG })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
}
