import router from '@ohos.router';
import { HttpService } from '../services/HttpService';

export interface HistoricalDatapoint {
  time: string;
  value: number;
  maxVal?: number;
  minVal?: number;
}

export interface PointCoord {
  x: number;
  y: number;
  yMax?: number;
  yMin?: number;
}

@Entry
@Component
struct SensorDetailPage {
  @State type: string = '';
  @State title: string = '';
  @State currentValue: number = 0;
  @State badgeColor: string = '#4CAF50';
  @State timeRange: string = '24h'; // '24h', '7d', '30d'
  @State dataPoints: HistoricalDatapoint[] = [];
  @State maxValue: number = 0;
  @State minValue: number = 0;
  @State avgValue: number = 0;
  @State selectedIdx: number = -1;
  @State showAvg: boolean = true;
  @State showMax: boolean = true;
  @State showMin: boolean = true;
  private pointsCoords: PointCoord[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.type = params['type'] as string;
      this.title = params['title'] as string;
      this.currentValue = params['currentValue'] as number;
      this.badgeColor = params['badgeColor'] as string;
    }
    this.loadData();
  }

  async loadData() {
    let res = await HttpService.getInstance().getSensorHistory(this.type, this.timeRange);
    if (res && res['code'] === 200 && res['data']) {
      let dataObj = res['data'] as Record<string, Object>;
      let summaryObj = dataObj['summary'] as Record<string, number>;
      let pointsArr = dataObj['points'] as HistoricalDatapoint[];
      this.avgValue = summaryObj['avg_value'] || 0;
      this.maxValue = summaryObj['max_value'] || 0;
      this.minValue = summaryObj['min_value'] || 0;
      this.dataPoints = pointsArr || [];
      this.drawChart();
    } else {
      this.loadMockData(); // HTTP Error fallback to pure mock
    }
  }

  loadMockData() {
    let points = 0;
    let baseValue = this.currentValue;
    let variance = 0;

    if (this.type === 'temperature') {
      variance = 5;
    } else if (this.type === 'humidity') {
      variance =
        10;
    } else if (this.type === 'light') {
      variance = 500;
    } else if (this.type === 'co2') {
      variance = 100;
    } else {
      variance =
        10;
    }

    if (this.timeRange === '24h') {
      points = 24;
    } else if (this.timeRange === '7d') {
      points = 7;
    } else if (this.timeRange ===
      '30d') {
      points = 30;
    }

    const newData: HistoricalDatapoint[] = [];
    let sum = 0;
    let min = Number.MAX_VALUE;
    let max = Number.MIN_VALUE;

    let targetBase = baseValue;
    for (let i = 0; i < points; i++) {
      // make it a bit smooth looking in random
      targetBase = targetBase + (Math.random() * variance * 0.8 - variance * 0.4);
      if (targetBase < 0) {
        targetBase = 0;
      }

      let timeStr = '';
      let d = new Date();
      if (this.timeRange === '24h') {
        d.setHours(d.getHours() - (points - 1 - i));
        timeStr = `${d.getHours()}:00`;
        newData.push({ time: timeStr, value: targetBase });

        sum += targetBase;
        if (targetBase < min) {
          min = targetBase;
        }
        if (targetBase > max) {
          max = targetBase;
        }
      } else {
        d.setDate(d.getDate() - (points - 1 - i));
        timeStr = `${d.getMonth() + 1}-${d.getDate()}`;

        let dMax = targetBase + Math.random() * variance * 0.5;
        let dMin = Math.max(0, targetBase - Math.random() * variance * 0.5);
        newData.push({
          time: timeStr,
          value: targetBase,
          maxVal: dMax,
          minVal: dMin
        });

        sum += targetBase;
        if (dMin < min) {
          min = dMin;
        }
        if (dMax > max) {
          max = dMax;
        }
      }
    }

    this.dataPoints = newData;
    this.maxValue = max;
    this.minValue = min;
    this.avgValue = sum / points;

    this.drawChart();
  }

  drawChart() {
    if (!this.context || this.dataPoints.length === 0) {
      return;
    }

    const width = this.context.width;
    const height = this.context.height;
    this.context.clearRect(0, 0, width, height);

    const paddingLeft = 50;
    const paddingRight = 30;
    const paddingTop = 40;
    const paddingBottom = 50;
    const graphWidth = width - paddingLeft - paddingRight;
    const graphHeight = height - paddingTop - paddingBottom;

    // Draw grid lines instead of solid axes
    this.context.strokeStyle = '#E0E0E0';
    this.context.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      let yLine = paddingTop + (graphHeight / 4) * i;
      this.context.beginPath();
      this.context.moveTo(paddingLeft, yLine);
      this.context.lineTo(width - paddingRight, yLine);
      this.context.stroke();
    }

    const yMax = this.maxValue * 1.1;
    const yMin = Math.max(0, this.minValue * 0.9);
    const yRange = yMax - yMin === 0 ? 1 : (yMax - yMin);

    this.pointsCoords = [];

    for (let i = 0; i < this.dataPoints.length; i++) {
      const point = this.dataPoints[i];
      const x = paddingLeft + (i / (this.dataPoints.length - 1)) * graphWidth;
      const y = height - paddingBottom - ((point.value - yMin) / yRange) * graphHeight;
      let coord: PointCoord = { x: x, y: y };

      if (point.maxVal !== undefined) {
        coord.yMax = height - paddingBottom - ((point.maxVal - yMin) / yRange) * graphHeight;
      }
      if (point.minVal !== undefined) {
        coord.yMin = height - paddingBottom - ((point.minVal - yMin) / yRange) * graphHeight;
      }

      this.pointsCoords.push(coord);
    }

    if (this.pointsCoords.length === 0) {
      return;
    }

    const getVal =
      (pt: PointCoord, prop: 'y' | 'yMax' | 'yMin') => prop === 'y' ? pt.y : (prop === 'yMax' ? pt.yMax : pt.yMin);

    // Draw lines & points
    const drawLine = (prop: 'y' | 'yMax' | 'yMin', color: string) => {
      this.context.beginPath();
      let startVal = prop === 'y' ? this.pointsCoords[0].y :
        (prop === 'yMax' ? this.pointsCoords[0].yMax : this.pointsCoords[0].yMin);
      this.context.moveTo(this.pointsCoords[0].x, startVal as number);
      for (let i = 1; i < this.pointsCoords.length; i++) {
        let val = prop === 'y' ? this.pointsCoords[i].y :
          (prop === 'yMax' ? this.pointsCoords[i].yMax : this.pointsCoords[i].yMin);
        this.context.lineTo(this.pointsCoords[i].x, val as number);
      }
      this.context.strokeStyle = color;
      this.context.lineWidth = 3;
      this.context.lineJoin = 'round';
      this.context.stroke();

      this.context.fillStyle = color;
      for (let i = 0; i < this.pointsCoords.length; i++) {
        let val = prop === 'y' ? this.pointsCoords[i].y :
          (prop === 'yMax' ? this.pointsCoords[i].yMax : this.pointsCoords[i].yMin);
        this.context.beginPath();
        this.context.arc(this.pointsCoords[i].x, val as number, 4, 0, Math.PI * 2);
        this.context.fill();
      }
    };

    if (this.timeRange === '24h') {
      if (this.showAvg) {
        drawLine('y', '#FFA000');
      }
    } else {
      if (this.showMax) {
        drawLine('yMax', '#FF5252');
      }
      if (this.showAvg) {
        drawLine('y', '#FFA000');
      }
      if (this.showMin) {
        drawLine('yMin', '#448AFF');
      }
    }

    // Draw Y axis labels
    this.context.fillStyle = '#90A4AE';
    this.context.font = '32px sans-serif';
    this.context.fillText(yMax.toFixed(0), 5, paddingTop + 5);
    this.context.fillText(((yMax + yMin) / 2).toFixed(0), 5, paddingTop + graphHeight / 2 + 5);
    this.context.fillText(yMin.toFixed(0), 5, height - paddingBottom);

    // Draw X axis Date Labels
    this.context.fillStyle = '#90A4AE';
    this.context.font = '32px sans-serif';
    const labelStep = Math.max(1, Math.floor(this.dataPoints.length / 5));
    for (let i = 0; i < this.dataPoints.length; i++) {
      if (i % labelStep === 0 || i === this.dataPoints.length - 1) {
        let label = this.dataPoints[i].time;
        let lw = this.context.measureText(label).width;
        let tx = this.pointsCoords[i].x - lw / 2;
        if (tx < paddingLeft) {
          tx = paddingLeft;
        }
        if (tx + lw > width) {
          tx = width - lw;
        }
        this.context.fillText(label, tx, height - paddingBottom + 25);
      }
    }

    // Draw Interactive Tooltip
    if (this.selectedIdx >= 0 && this.selectedIdx < this.pointsCoords.length) {
      let p = this.pointsCoords[this.selectedIdx];
      let dp = this.dataPoints[this.selectedIdx];

      this.context.beginPath();
      this.context.moveTo(p.x, paddingTop);
      this.context.lineTo(p.x, height - paddingBottom);
      this.context.strokeStyle = '#90A4AE';
      this.context.lineWidth = 1;
      this.context.setLineDash([4, 4]);
      this.context.stroke();
      this.context.setLineDash([]);

      let lines: string[] = [dp.time];
      if (this.timeRange === '24h') {
        if (this.showAvg) {
          lines.push(`数值: ${dp.value.toFixed(1)}`);
        }
      } else {
        if (this.showMax) {
          lines.push(`最高: ${(dp.maxVal || 0).toFixed(1)}`);
        }
        if (this.showAvg) {
          lines.push(`平均: ${dp.value.toFixed(1)}`);
        }
        if (this.showMin) {
          lines.push(`最低: ${(dp.minVal || 0).toFixed(1)}`);
        }
      }

      this.context.font = '24px sans-serif';
      let boxWidth = 0;
      lines.forEach(l => {
        let w = this.context.measureText(l).width + 30;
        if (w > boxWidth) {
          boxWidth = w;
        }
      });
      let boxHeight = lines.length * 28 + 10;
      let byTarget = (p.yMax !== undefined && this.showMax) ? p.yMax : p.y;

      const drawDot = (prop: 'y' | 'yMax' | 'yMin', col: string) => {
        const val = prop === 'y' ? p.y : (prop === 'yMax' ? p.yMax : p.yMin);
        if (val !== undefined) {
          this.context.beginPath();
          this.context.arc(p.x, val as number, 7, 0, Math.PI * 2);
          this.context.fillStyle = col;
          this.context.fill();
          this.context.lineWidth = 2;
          this.context.strokeStyle = '#FFFFFF';
          this.context.stroke();
        }
      };

      if (this.timeRange === '24h') {
        if (this.showAvg) {
          drawDot('y', '#FFA000');
        }
      } else {
        if (this.showMax) {
          drawDot('yMax', '#FF5252');
        }
        if (this.showAvg) {
          drawDot('y', '#FFA000');
        }
        if (this.showMin) {
          drawDot('yMin', '#448AFF');
        }
      }

      let bx = p.x - boxWidth / 2;
      let by = byTarget - boxHeight - 15;

      if (bx < 5) {
        bx = 5;
      }
      if (bx + boxWidth > width - 5) {
        bx = width - boxWidth - 5;
      }
      if (by < 5) {
        by = 5;
      }
      if (by + boxHeight > height - 5) {
        by = height - boxHeight - 5;
      }

      this.context.fillStyle = '#37474F';
      const radius = 8;
      this.context.beginPath();
      this.context.moveTo(bx + radius, by);
      this.context.arcTo(bx + boxWidth, by, bx + boxWidth, by + boxHeight, radius);
      this.context.arcTo(bx + boxWidth, by + boxHeight, bx, by + boxHeight, radius);
      this.context.arcTo(bx, by + boxHeight, bx, by, radius);
      this.context.arcTo(bx, by, bx + boxWidth, by, radius);
      this.context.closePath();
      this.context.fill();

      this.context.fillStyle = '#FFFFFF';
      lines.forEach((l, i) => {
        this.context.fillText(l, bx + 15, by + 28 + i * 28);
      });
    }
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
        Text(`${this.title}分析`)
          .fontSize(24)
          .fontColor('#2C3E50')
          .fontWeight(FontWeight.Bolder)
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 40,
        bottom: 20
      })
      .alignItems(VerticalAlign.Center)

      // Modern Segmented Control
      Row() {
        this.SegmentButton('24h', '24小时')
        this.SegmentButton('7d', '7天')
        this.SegmentButton('30d', '30天')
      }
      .width('90%')
      .backgroundColor('#E8F5E9')
      .borderRadius(16)
      .padding(4)
      .margin({ bottom: 25 })

      // Data Summary Cards (Horizontal Scroll)
      Row() {
        Column() {
          Text('平均值').fontSize(13).fontColor('#78909C').margin({ bottom: 8 })
          Text(this.avgValue.toFixed(1)).fontSize(24).fontColor('#2C3E50').fontWeight(FontWeight.Bolder)
        }
        .width('31%')
        .backgroundColor(Color.White)
        .padding({ top: 15, bottom: 15 })
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)
        .shadow({
          radius: 10,
          color: 'rgba(76, 175, 80, 0.05)',
          offsetX: 0,
          offsetY: 4
        })

        Column() {
          Text('最高值').fontSize(13).fontColor('#78909C').margin({ bottom: 8 })
          Text(this.maxValue.toFixed(1)).fontSize(24).fontColor('#2C3E50').fontWeight(FontWeight.Bolder)
        }
        .width('31%')
        .backgroundColor(Color.White)
        .padding({ top: 15, bottom: 15 })
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)
        .shadow({
          radius: 10,
          color: 'rgba(76, 175, 80, 0.05)',
          offsetX: 0,
          offsetY: 4
        })

        Column() {
          Text('最低值').fontSize(13).fontColor('#78909C').margin({ bottom: 8 })
          Text(this.minValue.toFixed(1)).fontSize(24).fontColor('#2C3E50').fontWeight(FontWeight.Bolder)
        }
        .width('31%')
        .backgroundColor(Color.White)
        .padding({ top: 15, bottom: 15 })
        .borderRadius(16)
        .alignItems(HorizontalAlign.Center)
        .shadow({
          radius: 10,
          color: 'rgba(76, 175, 80, 0.05)',
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 30 })

      // Chart Area
      Column() {
        Row() {
          Text(`历史趋势图`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#2C3E50')
          Blank()
          if (this.timeRange === '24h') {
            Row() {
              Circle({ width: 10, height: 10 })
                .fill(this.showAvg ? '#FFA000' : 'transparent')
                .stroke('#FFA000')
                .strokeWidth(2)
                .margin({ right: 4 })
              Text('数值').fontSize(14).fontColor(this.showAvg ? '#546E7A' : '#B0BEC5')
            }.margin({ left: 10 }).onClick(() => {
              this.showAvg = !this.showAvg;
              this.drawChart();
            })
          } else {
            Row() {
              Circle({ width: 10, height: 10 })
                .fill(this.showMax ? '#FF5252' : 'transparent')
                .stroke('#FF5252')
                .strokeWidth(2)
                .margin({ right: 4 })
              Text('最高').fontSize(14).fontColor(this.showMax ? '#546E7A' : '#B0BEC5')
            }.margin({ left: 10 }).onClick(() => {
              this.showMax = !this.showMax;
              this.drawChart();
            })

            Row() {
              Circle({ width: 10, height: 10 })
                .fill(this.showAvg ? '#FFA000' : 'transparent')
                .stroke('#FFA000')
                .strokeWidth(2)
                .margin({ right: 4 })
              Text('平均').fontSize(14).fontColor(this.showAvg ? '#546E7A' : '#B0BEC5')
            }.margin({ left: 10 }).onClick(() => {
              this.showAvg = !this.showAvg;
              this.drawChart();
            })

            Row() {
              Circle({ width: 10, height: 10 })
                .fill(this.showMin ? '#448AFF' : 'transparent')
                .stroke('#448AFF')
                .strokeWidth(2)
                .margin({ right: 4 })
              Text('最低').fontSize(14).fontColor(this.showMin ? '#546E7A' : '#B0BEC5')
            }.margin({ left: 10 }).onClick(() => {
              this.showMin = !this.showMin;
              this.drawChart();
            })
          }
        }
        .width('100%')
        .padding({
          left: 20,
          right: 20,
          top: 20,
          bottom: 10
        })

        Canvas(this.context)
          .width('100%')
          .height(280)
          .onReady(() => {
            this.drawChart();
          })
          .onTouch((event: TouchEvent) => {
            if (this.pointsCoords.length > 0) {
              const x = event.touches[0].x;
              let minD = 9999;
              let idx = -1;
              for (let i = 0; i < this.pointsCoords.length; i++) {
                let d = Math.abs(this.pointsCoords[i].x - x);
                if (d < minD) {
                  minD = d;
                  idx = i;
                }
              }
              if (minD < 30) {
                if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.selectedIdx = -1;
                } else {
                  this.selectedIdx = idx;
                }
              } else {
                this.selectedIdx = -1;
              }
              this.drawChart();
            }
          })
      }
      .width('90%')
      .backgroundColor(Color.White)
      .borderRadius(24)
      .shadow({
        radius: 20,
        color: 'rgba(76, 175, 80, 0.08)',
        offsetX: 0,
        offsetY: 10
      })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }

  @Builder
  SegmentButton(id: string, label: string) {
    Text(label)
      .fontSize(15)
      .fontWeight(this.timeRange === id ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.timeRange === id ? '#FFFFFF' : '#4CAF50')
      .backgroundColor(this.timeRange === id ? '#4CAF50' : 'transparent')
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(36)
      .borderRadius(12)
      .animation({ duration: 200 })
      .onClick(() => {
        if (this.timeRange !== id) {
          this.timeRange = id;
          this.loadData();
        }
      })
  }
}