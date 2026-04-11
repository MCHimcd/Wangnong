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
  @State filterStartDate: string = '';
  @State filterEndDate: string = '';
  @State showDateFilter: boolean = false;
  private readonly pageSize: number = 10;

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
      const startDate = this.filterStartDate.length > 0 ? this.filterStartDate : undefined;
      const endDate = this.filterEndDate.length > 0 ? this.filterEndDate : undefined;
      const result = await HttpService.getInstance().getOperationLogs(
        this.currentPage, this.pageSize, 'DEVICE_CONTROL', this.type, startDate, endDate);
      if (result) {
        if (this.currentPage === 1) {
          this.logs = result.items;
        } else {
          this.logs = this.logs.concat(result.items);
        }
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

  private resetAndReload(): void {
    this.logs = [];
    this.currentPage = 1;
    this.total = 0;
    void this.loadLogs();
  }

  private parseDetail(detail: string | null): ParsedDetail {
    let parsed = new ParsedDetail();
    if (detail === null || detail.length === 0) {
      return parsed;
    }
    try {
      const obj: Record<string, string> = JSON.parse(detail) as Record<string, string>;
      if (obj['action'] === 'turn_on') {
        parsed.action = '开启';
      } else if (obj['action'] === 'turn_off') {
        parsed.action = '关闭';
      } else if (obj['action'] === 'set_brightness') {
        const br = obj['brightness'];
        parsed.action = br !== undefined ? `亮度 ${br}%` : '亮度调节';
      } else if (obj['action'] !== undefined) {
        parsed.action = obj['action'];
      }
      if (obj['mode'] === 'smart') {
        parsed.mode = '智能模式';
      } else if (obj['mode'] === 'manual') {
        parsed.mode = '手动模式';
      } else if (obj['mode'] !== undefined) {
        parsed.mode = obj['mode'];
      }
      if (obj['source'] === 'smart') {
        parsed.source = 'smart';
      } else {
        parsed.source = 'manual';
      }
    } catch (_e) {
      if (detail.indexOf('turn_on') >= 0) {
        parsed.action = '开启';
      } else if (detail.indexOf('turn_off') >= 0) {
        parsed.action = '关闭';
      }
    }
    return parsed;
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

  private formatDate(createdAt: string | null): string {
    if (createdAt === null || createdAt.length === 0) {
      return '--';
    }
    if (createdAt.length >= 10) {
      return createdAt.substring(0, 10);
    }
    return createdAt;
  }

  private formatTimeOnly(createdAt: string | null): string {
    if (createdAt === null || createdAt.length === 0) {
      return '--';
    }
    const tIdx = createdAt.indexOf('T');
    if (tIdx >= 0 && createdAt.length > tIdx + 5) {
      return createdAt.substring(tIdx + 1, tIdx + 6);
    }
    if (createdAt.length > 16) {
      return createdAt.substring(11, 16);
    }
    return createdAt;
  }

  private getTodayString(): string {
    const d = new Date();
    const y = d.getFullYear().toString();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  @Builder
  StatusBadge() {
    Text(this.isOn ? '运行中' : '已停止')
      .fontSize(AppFontSize.Caption)
      .fontColor(Color.White)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.isOn ? AppColors.Success : AppColors.TextTertiary)
      .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
      .borderRadius(AppRadius.Full)
  }

  @Builder
  DateFilterBar() {
    Column() {
      Row() {
        Text('📅').fontSize(AppFontSize.Body)
        Text('日期筛选')
          .fontSize(AppFontSize.Body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .margin({ left: AppSpacing.XS })
        Blank()
        if (this.filterStartDate.length > 0 || this.filterEndDate.length > 0) {
          Text('清除')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.AlertCritical)
            .onClick(() => {
              this.filterStartDate = '';
              this.filterEndDate = '';
              this.resetAndReload();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: AppSpacing.SM }) {
        Column() {
          Text('开始日期')
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextTertiary)
            .margin({ bottom: AppSpacing.XS })
          Text(this.filterStartDate.length > 0 ? this.filterStartDate : '选择日期')
            .fontSize(AppFontSize.Caption)
            .fontColor(this.filterStartDate.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
            .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
            .backgroundColor(AppColors.Background)
            .borderRadius(AppRadius.SM)
            .border({ width: 1, color: AppColors.Divider })
            .onClick(() => {
              DatePickerDialog.show({
                selected: new Date(),
                onDateAccept: (value: Date) => {
                  const y = value.getFullYear().toString();
                  const m = (value.getMonth() + 1).toString().padStart(2, '0');
                  const d = value.getDate().toString().padStart(2, '0');
                  this.filterStartDate = `${y}-${m}-${d}`;
                  this.resetAndReload();
                }
              });
            })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)

        Text('至')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextSecondary)

        Column() {
          Text('结束日期')
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextTertiary)
            .margin({ bottom: AppSpacing.XS })
          Text(this.filterEndDate.length > 0 ? this.filterEndDate : '选择日期')
            .fontSize(AppFontSize.Caption)
            .fontColor(this.filterEndDate.length > 0 ? AppColors.TextPrimary : AppColors.TextTertiary)
            .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
            .backgroundColor(AppColors.Background)
            .borderRadius(AppRadius.SM)
            .border({ width: 1, color: AppColors.Divider })
            .onClick(() => {
              DatePickerDialog.show({
                selected: new Date(),
                onDateAccept: (value: Date) => {
                  const y = value.getFullYear().toString();
                  const m = (value.getMonth() + 1).toString().padStart(2, '0');
                  const d = value.getDate().toString().padStart(2, '0');
                  this.filterEndDate = `${y}-${m}-${d}`;
                  this.resetAndReload();
                }
              });
            })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: AppSpacing.SM })

      // 快捷筛选按钮
      Row({ space: AppSpacing.SM }) {
        Text('今天')
          .fontSize(AppFontSize.Mini)
          .fontColor(this.filterStartDate === this.getTodayString() && this.filterEndDate === this.getTodayString()
            ? Color.White : AppColors.Primary)
          .backgroundColor(this.filterStartDate === this.getTodayString() && this.filterEndDate === this.getTodayString()
            ? AppColors.Primary : AppColors.PrimaryBg)
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
          .onClick(() => {
            const today = this.getTodayString();
            this.filterStartDate = today;
            this.filterEndDate = today;
            this.resetAndReload();
          })
        Text('近7天')
          .fontSize(AppFontSize.Mini)
          .fontColor(AppColors.Primary)
          .backgroundColor(AppColors.PrimaryBg)
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
          .onClick(() => {
            const now = new Date();
            const end = this.getTodayString();
            const past = new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000);
            const y = past.getFullYear().toString();
            const m = (past.getMonth() + 1).toString().padStart(2, '0');
            const d = past.getDate().toString().padStart(2, '0');
            this.filterStartDate = `${y}-${m}-${d}`;
            this.filterEndDate = end;
            this.resetAndReload();
          })
        Text('近30天')
          .fontSize(AppFontSize.Mini)
          .fontColor(AppColors.Primary)
          .backgroundColor(AppColors.PrimaryBg)
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
          .onClick(() => {
            const now = new Date();
            const end = this.getTodayString();
            const past = new Date(now.getTime() - 29 * 24 * 60 * 60 * 1000);
            const y = past.getFullYear().toString();
            const m = (past.getMonth() + 1).toString().padStart(2, '0');
            const d = past.getDate().toString().padStart(2, '0');
            this.filterStartDate = `${y}-${m}-${d}`;
            this.filterEndDate = end;
            this.resetAndReload();
          })
      }
      .width('100%')
      .margin({ top: AppSpacing.SM })
    }
    .width('100%')
    .padding(AppSpacing.MD)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  LogCard(item: OperationLogItem) {
    Column() {
      // 顶部：时间 + 操作类型标签
      Row() {
        Text(this.formatTime(item.createdAt))
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextSecondary)
        Blank()
        Text(this.parseDetail(item.detail).source === 'smart' ? '智能' : '手动')
          .fontSize(AppFontSize.Mini)
          .fontColor(this.parseDetail(item.detail).source === 'smart' ? AppColors.Accent : AppColors.Primary)
          .backgroundColor(this.parseDetail(item.detail).source === 'smart' ? AppColors.AccentBg : AppColors.PrimaryBg)
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 2, bottom: 2 })
          .borderRadius(AppRadius.Full)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 中间：操作内容
      Row() {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.parseDetail(item.detail).action === '开启' ? AppColors.Success : AppColors.AlertCritical)
        }
        .width(24).height(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.parseDetail(item.detail).action === '开启' ? AppColors.SuccessBg : AppColors.AlertCriticalBg)
        .borderRadius(12)

        Text(this.parseDetail(item.detail).action)
          .fontSize(AppFontSize.H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.parseDetail(item.detail).action === '开启' ? AppColors.Success : AppColors.AlertCritical)
          .margin({ left: AppSpacing.SM })

        if (this.parseDetail(item.detail).mode.length > 0) {
          Text(this.parseDetail(item.detail).mode)
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextSecondary)
            .backgroundColor(AppColors.Background)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(AppRadius.SM)
            .margin({ left: AppSpacing.SM })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: AppSpacing.SM })

      // 底部：操作人信息
      Row() {
        if (this.parseDetail(item.detail).source === 'smart') {
          Text('🤖 智能策略触发')
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.Accent)
        } else if (item.userName !== null && item.userName.length > 0) {
          Text('👤 ' + item.userName)
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextTertiary)
        } else {
          Text('👤 手动操作')
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextTertiary)
        }
      }
      .width('100%')
      .margin({ top: AppSpacing.SM })
    }
    .width('100%')
    .padding(AppSpacing.MD)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
  }

  @Builder
  SummaryBar() {
    Row() {
      Column() {
        Text(this.total.toString())
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.Primary)
        Text('总记录')
          .fontSize(AppFontSize.Mini)
          .fontColor(AppColors.TextTertiary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Center)

      Row() {}.width(1).height(30).backgroundColor(AppColors.Divider)

      Column() {
        Text(this.isOn ? '运行中' : '已停止')
          .fontSize(AppFontSize.H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isOn ? AppColors.Success : AppColors.TextTertiary)
        Text('当前状态')
          .fontSize(AppFontSize.Mini)
          .fontColor(AppColors.TextTertiary)
      }.layoutWeight(1).alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: AppSpacing.MD, bottom: AppSpacing.MD })
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
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
        this.StatusBadge()
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: 40, bottom: AppSpacing.SM })
      .alignItems(VerticalAlign.Center)

      // 主体区域
      List({ space: AppSpacing.SM }) {
        // 统计概览
        ListItem() {
          this.SummaryBar()
        }.padding({ left: AppSpacing.LG, right: AppSpacing.LG })

        // 日期筛选
        ListItem() {
          Column() {
            Row() {
              Text('')
                .width(3).height(16).borderRadius(2)
                .backgroundColor(AppColors.Primary)
                .margin({ right: AppSpacing.SM })
              Text('操作记录')
                .fontSize(AppFontSize.H2)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TextPrimary)
              Blank()
              Text(this.showDateFilter ? '收起筛选' : '筛选')
                .fontSize(AppFontSize.Caption)
                .fontColor(AppColors.Primary)
                .onClick(() => {
                  this.showDateFilter = !this.showDateFilter;
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ bottom: AppSpacing.SM })

            if (this.showDateFilter) {
              this.DateFilterBar()
            }
          }
        }.padding({ left: AppSpacing.LG, right: AppSpacing.LG })

        // 日志列表
        if (this.loading && this.logs.length === 0) {
          ListItem() {
            Column() {
              Text('加载中...')
                .fontSize(AppFontSize.Body)
                .fontColor(AppColors.TextTertiary)
            }
            .width('100%').height(200)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          }
        } else if (this.logs.length === 0) {
          ListItem() {
            Column() {
              Text('📋').fontSize(40).margin({ bottom: AppSpacing.SM })
              Text('暂无操作记录')
                .fontSize(AppFontSize.Body)
                .fontColor(AppColors.TextTertiary)
            }
            .width('100%').height(200)
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          }
        } else {
          ForEach(this.logs, (item: OperationLogItem) => {
            ListItem() {
              this.LogCard(item)
            }.padding({ left: AppSpacing.LG, right: AppSpacing.LG })
          }, (item: OperationLogItem) => item.id.toString())

          // 加载更多
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
      }
      .width('100%').layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .backgroundColor(AppColors.Background)
  }
}

class ParsedDetail {
  action: string = '操作';
  mode: string = '';
  source: string = 'manual';
}
