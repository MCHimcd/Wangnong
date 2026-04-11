import router from '@ohos.router';
import { HttpService, OperationLogItem } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

@Entry
@Component
struct DeviceDetailPage {
  @State type: string = '';
  @State title: string = '';
  @State isOn: boolean = false;
  @State logs: OperationLogItem[] = [];
  @State loading: boolean = false;
  @State total: number = 0;
  @State currentPage: number = 1;
  private readonly pageSize: number = 30;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.type = params['type'] as string;
      this.title = params['title'] as string;
      this.isOn = params['isOn'] as boolean;
    }
    void this.loadLogs();
  }

  private async loadLogs(): Promise<void> {
    this.loading = true;
    try {
      const result = await HttpService.getInstance().getOperationLogs(this.currentPage, this.pageSize, 'DEVICE_CONTROL');
      if (result) {
        const filtered = result.items.filter((item: OperationLogItem) => item.targetId === this.type);
        this.logs = this.logs.concat(filtered);
        this.total = result.total;
      }
    } catch (e) {
      console.error('[DeviceDetailPage] loadLogs failed', e);
    } finally {
      this.loading = false;
    }
  }

  private async loadMore(): Promise<void> {
    this.currentPage++;
    await this.loadLogs();
  }

  private parseDetail(detail: string | null): Record<string, string> {
    let action = '操作';
    let mode = '';
    if (detail !== null && detail.length > 0) {
      try {
        const obj: Record<string, string> = JSON.parse(detail) as Record<string, string>;
        if (obj['action'] === 'turn_on') {
          action = '开启';
        } else if (obj['action'] === 'turn_off') {
          action = '关闭';
        } else if (obj['action'] !== undefined) {
          action = obj['action'];
        }
        if (obj['mode'] === 'smart') {
          mode = '智能模式';
        } else if (obj['mode'] === 'manual') {
          mode = '手动模式';
        } else if (obj['mode'] !== undefined) {
          mode = obj['mode'];
        }
      } catch (_e) {
        if (detail.indexOf('turn_on') >= 0) {
          action = '开启';
        } else if (detail.indexOf('turn_off') >= 0) {
          action = '关闭';
        }
      }
    }
    let result: Record<string, string> = {};
    result['action'] = action;
    result['mode'] = mode;
    return result;
  }

  private formatTime(createdAt: string | null): string {
    if (createdAt === null || createdAt.length === 0) {
      return '--';
    }
    if (createdAt.length > 16) {
      return createdAt.substring(0, 16).replace('T', ' ');
    }
    return createdAt.replace('T', ' ');
  }

  @Builder
  LogItem(item: OperationLogItem, isLast: boolean) {
    Row() {
      // 时间线装饰
      Column() {
        Circle({ width: 10, height: 10 })
          .fill(AppColors.Primary)
        if (!isLast) {
          Row() {}
            .width(1).layoutWeight(1)
            .backgroundColor(AppColors.Divider)
        }
      }
      .width(20)
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ right: AppSpacing.SM })

      // 日志内容
      Column() {
        Text(this.formatTime(item.createdAt))
          .fontSize(AppFontSize.Mini)
          .fontColor(AppColors.TextTertiary)

        Row() {
          Text(this.parseDetail(item.detail)['action'] ?? '操作')
            .fontSize(AppFontSize.H3)
            .fontWeight(FontWeight.Medium)
            .fontColor(
              (this.parseDetail(item.detail)['action'] === '开启')
                ? AppColors.Success : AppColors.AlertCritical
            )
          if ((this.parseDetail(item.detail)['mode'] ?? '').length > 0) {
            Text(this.parseDetail(item.detail)['mode'] ?? '')
              .fontSize(AppFontSize.Mini)
              .fontColor(AppColors.TextSecondary)
              .backgroundColor(AppColors.Background)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(AppRadius.SM)
              .margin({ left: AppSpacing.SM })
          }
        }
        .alignItems(VerticalAlign.Center)
        .margin({ top: AppSpacing.XS })

        if (item.userName !== null && item.userName.length > 0) {
          Text('操作人: ' + item.userName)
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextTertiary)
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: AppSpacing.MD })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => { router.back(); })
        Text(this.title)
          .fontSize(AppFontSize.H1).fontColor(AppColors.TextPrimary)
          .fontWeight(FontWeight.Bold).layoutWeight(1)
        Text(this.isOn ? '运行中' : '已停止')
          .fontSize(AppFontSize.Caption)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.isOn ? AppColors.Success : AppColors.TextTertiary)
          .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: 40, bottom: AppSpacing.LG })
      .alignItems(VerticalAlign.Center)

      // 操作记录标题
      Row() {
        Text('')
          .width(3).height(16).borderRadius(2)
          .backgroundColor(AppColors.Primary)
          .margin({ right: AppSpacing.SM })
        Text('操作记录')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, bottom: AppSpacing.SM })

      // 日志列表
      if (this.loading && this.logs.length === 0) {
        Column() {
          Text('加载中...')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextTertiary)
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else if (this.logs.length === 0) {
        Column() {
          Text('📋').fontSize(40).margin({ bottom: AppSpacing.SM })
          Text('暂无操作记录')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextTertiary)
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.logs, (item: OperationLogItem, index: number) => {
            ListItem() {
              this.LogItem(item, index === this.logs.length - 1)
            }
          }, (item: OperationLogItem) => item.id.toString())

          if (this.currentPage * this.pageSize < this.total) {
            ListItem() {
              Row() {
                Text(this.loading ? '加载中...' : '加载更多')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.Primary)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(AppSpacing.MD)
              .onClick(() => {
                if (!this.loading) {
                  void this.loadMore();
                }
              })
            }
          }
        }
        .width('100%').layoutWeight(1)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(AppColors.Background)
  }
}
