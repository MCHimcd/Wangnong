import router from '@ohos.router';
import { AlertData } from '../models/AlertData';
import { AlertSyncService } from '../services/AlertSyncService';
import { promptAction } from '@kit.ArkUI';

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
    if (level === 'critical') return '#F44336';
    if (level === 'warning') return '#FF9800';
    return '#2196F3';
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
          .width(28).height(28).margin({ right: 15 }).fillColor('#2C3E50')
          .onClick(() => { router.back(); })
        Text('告警详情')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2C3E50').layoutWeight(1)
      }
      .width('100%').height(56).padding({ left: 15, right: 15 })
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })

      if (!this.loaded) {
        Column() {
          Blank()
          Text('告警数据未找到').fontSize(16).fontColor('#90A4AE')
          Blank()
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // Level badge
            Row() {
              Circle({ width: 12, height: 12 }).fill(this.getLevelColor(this.alert.level)).margin({ right: 8 })
              Text(this.getLevelText(this.alert.level))
                .fontSize(16).fontWeight(FontWeight.Bold)
                .fontColor(this.getLevelColor(this.alert.level))
              Blank()
              Text(this.alert.is_handled ? '已处理' : '待处理')
                .fontSize(13)
                .fontColor(this.alert.is_handled ? '#4CAF50' : '#F44336')
                .backgroundColor(this.alert.is_handled ? '#E8F5E9' : '#FFEBEE')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
            }
            .width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(12)
            .margin({ top: 15 })

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
            .width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(12)
            .margin({ top: 10 })

            // Message
            Column() {
              Text('告警详情').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#2C3E50')
                .margin({ bottom: 10 })
              Text(this.alert.message)
                .fontSize(14).fontColor('#546E7A').lineHeight(22)
            }
            .width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(12)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)

            // Action button
            if (!this.alert.is_handled) {
              Button('标记为已处理', { type: ButtonType.Capsule })
                .width('80%').height(44).fontSize(16)
                .backgroundColor('#4CAF50')
                .margin({ top: 30 })
                .onClick(() => { this.markAsHandled(); })
            }
          }
          .width('100%')
          .padding({ left: 15, right: 15, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor('#F2F6F3')
  }

  @Builder DetailRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(14).fontColor('#90A4AE').width(80)
      Text(value).fontSize(14).fontColor('#2C3E50').layoutWeight(1)
    }
    .width('100%').padding({ top: 8, bottom: 8 })
  }
}
