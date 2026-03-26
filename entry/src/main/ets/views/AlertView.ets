import { AlertData } from '../models/AlertData';
import { promptAction } from '@kit.ArkUI';
import { AlertSyncService } from '../services/AlertSyncService';
import router from '@ohos.router';

@Component
export struct AlertView {
  @State alerts: AlertData[] = [];
  @State sortBy: string = 'timestamp';
  @State order: string = 'desc';
  @State highlightedAlertId: string = '';

  private onDataChange = () => {
    this.alerts = AlertSyncService.getInstance().getAllAlerts();
    this.sortAlertsLocally();
  }

  aboutToAppear() {
    AlertSyncService.getInstance().subscribeDataChange(this.onDataChange);
    AlertSyncService.getInstance().startRealtimeSync();
    this.alerts = AlertSyncService.getInstance().getAllAlerts();
    this.sortAlertsLocally();
  }

  aboutToDisappear() {
    AlertSyncService.getInstance().unsubscribeDataChange(this.onDataChange);
  }

  sortAlertsLocally() {
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
      return '#F44336';
    } 
    if (level === 'warning') {
      return '#FF9800';
    } 
    return '#2196F3'; 
  }

  build() {
    Column() {
      Text('告警消息')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#2C3E50')
        .margin({ top: 30, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center)

      Row() {
        Text('排序:')
          .fontSize(14).fontColor('#666')
        Select([{ value: '时间' }, { value: '类型' }])
          .selected(this.sortBy === 'timestamp' ? 0 : 1)
          .value(this.sortBy === 'timestamp' ? '时间' : '类型')
          .onSelect((index: number) => {
            this.sortBy = index === 0 ? 'timestamp' : 'type';
            this.sortAlertsLocally();
          })
          .height(30)
          .margin({ left: 8 })

        Select([{ value: '降序' }, { value: '升序' }])
          .selected(this.order === 'desc' ? 0 : 1)
          .value(this.order === 'desc' ? '降序' : '升序')
          .onSelect((index: number) => {
            this.order = index === 0 ? 'desc' : 'asc';
            this.sortAlertsLocally();
          })
          .height(30)
          .margin({ left: 8 })

        Blank()

        Text('实时更新中')
          .fontSize(14)
          .fontColor('#2E7D32')
      }
      .width('100%')
      .padding(15)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })

      List({ space: 10 }) {
        ForEach(this.alerts, (alert: AlertData) => {
          ListItem() {
            Column() {
              Row() {
                Circle({ width: 10, height: 10 }).fill(this.getLevelColor(alert.level)).margin({ right: 8 })
                Text(alert.type_name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333')
                Text(alert.source_name)
                  .fontSize(11)
                  .fontColor('#546E7A')
                  .backgroundColor('#ECEFF1')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(8)
                  .margin({ left: 8 })
                Blank()
                Text(this.formatDate(alert.timestamp))
                  .fontSize(12)
                  .fontColor('#999')
              }.width('100%')

              Text(alert.message)
                .fontSize(14)
                .fontColor('#666')
                .margin({ top: 10, bottom: 10 })
                .lineHeight(20)

              Row() {
                Text(alert.is_handled ? '已处理' : '待处理')
                  .fontSize(12)
                  .fontColor(alert.is_handled ? '#4CAF50' : '#F44336')
                  .padding({
                    left: 6,
                    right: 6,
                    top: 2,
                    bottom: 2
                  })
                  .backgroundColor(alert.is_handled ? '#E8F5E9' : '#FFEBEE')
                  .borderRadius(4)

                Blank()

                if (!alert.is_handled) {
                  Button('标记处理')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor('#4CAF50')
                    .onClick(() => {
                      this.markAsHandled(alert.alert_id);
                    })
                } else if (alert.handle_time) {
                  Text(`处理时间: ${this.formatDate(alert.handle_time)}`)
                    .fontSize(12)
                    .fontColor('#999')
                }
              }.width('100%').alignItems(VerticalAlign.Center)
            }
            .padding(15)
            .backgroundColor(alert.alert_id === this.highlightedAlertId ? '#FFF8E1' : '#FFF')
            .borderRadius(8)
            .shadow({
              radius: alert.alert_id === this.highlightedAlertId ? 8 : 4,
              color: alert.alert_id === this.highlightedAlertId ? 'rgba(255,193,7,0.35)' : 'rgba(0,0,0,0.05)',
              offsetY: 2
            })
            .width('100%')
            .onClick(() => {
              router.pushUrl({ url: 'pages/AlertDetailPage', params: { alertId: alert.alert_id } });
            })
          }
        })
      }
      .padding({
        left: 15,
        right: 15,
        top: 15,
        bottom: 15
      })
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
