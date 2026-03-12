import { AlertData } from '../models/AlertData';
import { HttpService } from '../services/HttpService';
import { promptAction } from '@kit.ArkUI';

@Component
export struct AlertView {
  @State alerts: AlertData[] = [];
  @State isLoading: boolean = false;
  @State sortBy: string = 'timestamp';
  @State order: string = 'desc';
  @State filterType: string = 'all';
  @State filterStatus: string = 'all';

  aboutToAppear() {
    this.fetchAlerts();
  }

  async fetchAlerts() {
    this.isLoading = true;
    try {
      let res =
        await HttpService.getInstance().getAlerts(1, 20, this.sortBy, this.order, this.filterType, this.filterStatus);
      if (res && res.data) {
        let data = res.data as Record<string, Object>;
        if (data.alerts) {
          this.alerts = data.alerts as AlertData[];
        } else {
          // Mock data fallback if backend structure differs or fails
          this.alerts = this.getMockAlerts();
        }
      } else {
        // Fallback to mock data if network fails
        this.alerts = this.getMockAlerts();
      }
    } catch (e) {
      console.error('Fetch alerts failed, using mock data.');
      this.alerts = this.getMockAlerts();
    }

    // Sort locally in case backend mock doesn't handle params
    this.sortAlertsLocally();
    this.isLoading = false;
  }

  getMockAlerts(): AlertData[] {
    return [
      {
        alert_id: "AL_001",
        type: "temp_high",
        type_name: "高温异常",
        level: "critical",
        timestamp: 1710200000000,
        message: "气温持续高于32°C(最高达35.3°C)，超出番茄适宜生长温度范围(25-28°C)，可能导致植株热胁迫、落花落果。",
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: "AL_002",
        type: "pest_warning",
        type_name: "病害预警",
        level: "warning",
        timestamp: 1710100000000,
        message: "视觉检测连续识别到番茄早疫病(置信度0.9-0.98)，高湿环境可能加速病害扩散，需立即干预。",
        is_handled: true,
        handle_time: 1710105000000
      },
      {
        alert_id: "AL_003",
        type: "humidity_low",
        type_name: "空气湿度过低",
        level: "info",
        timestamp: 1710000000000,
        message: "气湿最低至41.7%，低于番茄生长适宜湿度(60-70%)，可能加剧蒸腾作用与水分胁迫。",
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: "AL_004",
        type: "moisture_low",
        type_name: "土壤湿度偏低",
        level: "warning",
        timestamp: 1709900000000,
        message: "土湿仅18.5%-20.5%，低于番茄生长适宜阈值(约25-30%)，需关注灌溉系统是否正常。",
        is_handled: false,
        handle_time: null
      },
      {
        alert_id: "AL_005",
        type: "equipment_offline",
        type_name: "设备未响应环境异常",
        level: "critical",
        timestamp: 1709800000000,
        message: "系统处于自动模式，但高温、低湿条件下风扇与水泵均未启动，可能存在控制逻辑或执行器故障。",
        is_handled: false,
        handle_time: null
      }
    ];
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
    let success = await HttpService.getInstance().handleAlert(alertId, 'mark_handled', '已处理');
    if (success) {
      promptAction.showToast({ message: '标记成功' });
    } else {
      promptAction.showToast({ message: '(模拟) 标记成功' });
    }
    // Update local state
    let target = this.alerts.find(a => a.alert_id === alertId);
    if (target) {
      target.is_handled = true;
      target.handle_time = new Date().getTime();
    }
    // Reassign array to trigger UI update
    this.alerts = [...this.alerts];
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
    } // Red
    if (level === 'warning') {
      return '#FF9800';
    } // Orange
    return '#2196F3'; // Blue info
  }

  build() {
    Column() {
      // Top Control Bar
      Row() {
        Text('排序:')
          .fontSize(14).fontColor('#666')
        Select([{ value: '时间' }, { value: '类型' }])
          .selected(this.sortBy === 'timestamp' ? 0 : 1)
          .value(this.sortBy === 'timestamp' ? '时间' : '类型')
          .onSelect((index: number) => {
            this.sortBy = index === 0 ? 'timestamp' : 'type';
            this.fetchAlerts();
          })
          .height(30)
          .margin({ left: 8 })

        Select([{ value: '降序' }, { value: '升序' }])
          .selected(this.order === 'desc' ? 0 : 1)
          .value(this.order === 'desc' ? '降序' : '升序')
          .onSelect((index: number) => {
            this.order = index === 0 ? 'desc' : 'asc';
            this.fetchAlerts();
          })
          .height(30)
          .margin({ left: 8 })

        Blank()

        Button('刷新')
          .fontSize(14)
          .height(30)
          .onClick(() => {
            this.fetchAlerts();
          })
      }
      .width('100%')
      .padding(15)
      .backgroundColor('#FFF')

      // List of Alerts
      if (this.isLoading) {
        Column() {
          Text('加载中...').fontSize(16).fontColor('#999')
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      } else {
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
              .backgroundColor('#FFF')
              .borderRadius(8)
              .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
              .width('100%')
            }
          })
        }
        .padding({
          left: 15,
          right: 15,
          top: 5,
          bottom: 15
        })
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
