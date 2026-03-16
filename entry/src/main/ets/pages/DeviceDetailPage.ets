import router from '@ohos.router';
import { HttpService, DeviceDataPoint, EquipmentStatsData } from '../services/HttpService';

@Entry
@Component
struct DeviceDetailPage {
  @State type: string = '';
  @State title: string = '';
  @State isOn: boolean = false;
  @State dataPoints: DeviceDataPoint[] = [];
  @State summaryTotal: number = 0;
  @State yAxisLabel: string = '';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.type = params['type'] as string;
      this.title = params['title'] as string;
      this.isOn = params['isOn'] as boolean;
    }
    this.loadData();
  }

  async loadData() {
    let res = await HttpService.getInstance().getEquipmentStats(this.type, '7d');
    if (res && res.code === 200 && res.data) {
      let dataObj: EquipmentStatsData = res.data;
      let summaryObj = dataObj.summary;
      let pointsArr: DeviceDataPoint[] = dataObj.points;

      this.summaryTotal = summaryObj.total_value || 0;
      this.yAxisLabel = summaryObj.unit || '';
      this.dataPoints = pointsArr || [];
      this.drawBarChart();
    } else {
      this.summaryTotal = 0;
      this.dataPoints = [];
      this.drawBarChart();
    }
  }

  drawBarChart() {
    if (!this.context || this.dataPoints.length === 0) {
      return;
    }

    const width = this.context.width;
    const height = this.context.height;
    this.context.clearRect(0, 0, width, height);

    const paddingLeft = 40;
    const paddingTop = 40;
    const paddingRight = 20;
    const paddingBottom = 60;
    const graphWidth = width - paddingLeft - paddingRight;
    const graphHeight = height - paddingTop - paddingBottom;

    // Draw Grid (Light Grey)
    this.context.strokeStyle = '#ECEFF1';
    this.context.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      let yLine = paddingTop + (graphHeight / 4) * i;
      this.context.beginPath();
      this.context.moveTo(paddingLeft, yLine);
      this.context.lineTo(width - paddingRight, yLine);
      this.context.stroke();
    }

    let maxVal = Math.max(...this.dataPoints.map(p => p.value));
    if (maxVal === 0) {
      maxVal = 10;
    }
    const yMax = maxVal * 1.2;

    const barWidth = (graphWidth / this.dataPoints.length) * 0.45;
    const spacing = (graphWidth / this.dataPoints.length);

    // Draw Rectangular Bars
    for (let i = 0; i < this.dataPoints.length; i++) {
      const point = this.dataPoints[i];
      const barHeight = (point.value / yMax) * graphHeight;
      const x = paddingLeft + i * spacing + (spacing - barWidth) / 2;
      const y = height - paddingBottom - barHeight;

      // Draw Gradient Rect Bar
      let grd = this.context.createLinearGradient(x, y, x, y + barHeight);
      if (this.type === 'ai_camera') {
        grd.addColorStop(0, '#FF8A65');
        grd.addColorStop(1, '#FFCCBC');
      } else if (this.type === 'led_light') {
        grd.addColorStop(0, '#FFF176');
        grd.addColorStop(1, '#FFF9C4');
      } else if (this.type === 'fan') {
        grd.addColorStop(0, '#81D4FA');
        grd.addColorStop(1, '#B3E5FC');
        grd.addColorStop(0, '#4CAF50');
        grd.addColorStop(1, '#A5D6A7');
      }
      this.context.fillStyle = grd;

      this.context.fillRect(x, y, barWidth, barHeight);

      // Top Value Label
      this.context.fillStyle = '#546E7A';
      this.context.font = 'bold 32px sans-serif';
      const textWidth = this.context.measureText(point.value.toString()).width;
      this.context.fillText(point.value.toString(), x + (barWidth - textWidth) / 2, y - 10);

      // Bottom Date Label
      this.context.fillStyle = '#90A4AE';
      this.context.font = '32px sans-serif';
      const timeWidth = this.context.measureText(point.timeLabel).width;
      this.context.fillText(point.timeLabel, x + (barWidth - timeWidth) / 2, height - paddingBottom + 25);
    }

    // Y Axis unit text
    this.context.fillStyle = '#90A4AE';
    this.context.font = '32px sans-serif';
    this.context.fillText(yMax.toFixed(0), 5, paddingTop + 5);
    this.context.fillText('0', 5, height - paddingBottom);
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
        Text(`${this.title}`)
          .fontSize(24).fontColor('#2C3E50').fontWeight(FontWeight.Bolder).layoutWeight(1)

        Text(this.isOn ? '运行中' : '已离线')
          .fontSize(14)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.isOn ? '#4CAF50' : '#B0BEC5')
          .padding({
            left: 12,
            right: 12,
            top: 6,
            bottom: 6
          })
          .borderRadius(20)
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 40,
        bottom: 20
      })
      .alignItems(VerticalAlign.Center)

      // Summary
      Row() {
        Column() {
          Text(`近7日总${this.yAxisLabel.split('(')[0]}`).fontSize(15).fontColor('#78909C')
          Text(`${this.summaryTotal}`)
            .fontSize(42)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#2C3E50')
            .margin({ top: 5 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)

        // decorative icon background
        Circle({ width: 60, height: 60 }).fill('#F1F8E9').opacity(0.8)
      }
      .width('90%')
      .padding(25)
      .backgroundColor(Color.White)
      .borderRadius(24)
      .margin({ bottom: 25 })
      .shadow({
        radius: 20,
        color: 'rgba(76, 175, 80, 0.08)',
        offsetX: 0,
        offsetY: 10
      })

      // Chart Area
      Column() {
        Text(`过去7天数据统计`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')
          .margin({ bottom: 15, left: 20, top: 20 })
          .width('100%')

        Canvas(this.context)
          .width('100%')
          .height(280)
          .onReady(() => {
            this.drawBarChart();
          })
      }
      .width('90%').backgroundColor(Color.White).borderRadius(24)
      .shadow({
        radius: 20,
        color: 'rgba(76, 175, 80, 0.08)',
        offsetX: 0,
        offsetY: 10
      })
    }
    .width('100%').height('100%').backgroundColor('#F2F6F3')
  }
}