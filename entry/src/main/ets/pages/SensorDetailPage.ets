import router from '@ohos.router';
import {
  LineChart,
  LineChartModel,
  LineData,
  LineDataSet,
  ILineDataSet,
  EntryOhos,
  JArrayList,
  Mode,
  XAxisPosition,
  YAxisLabelPosition,
  OnChartValueSelectedListener,
  Highlight,
  IAxisValueFormatter,
  AxisBase
} from '@ohos/mpchart';

export interface HistoricalDatapoint {
  time: string;
  value: number;
  maxVal?: number;
  minVal?: number;
}

class ValueSelectedListener implements OnChartValueSelectedListener {
  private cb: (e: EntryOhos | null, h: Highlight | null) => void;
  constructor(cb: (e: EntryOhos | null, h: Highlight | null) => void) {
    this.cb = cb;
  }
  onValueSelected(e: EntryOhos, h: Highlight): void {
    this.cb(e, h);
  }
  onNothingSelected(): void {
    this.cb(null, null);
  }
}

class XAxisFormatter implements IAxisValueFormatter {
  private labels: string[];
  constructor(labels: string[]) {
    this.labels = labels;
  }
  getFormattedValue(value: number, axis: AxisBase): string {
    let index = Math.floor(value);
    if (index >= 0 && index < this.labels.length) {
      return this.labels[index];
    }
    return "";
  }
}

@Entry
@Component
struct SensorDetailPage {
  @State type: string = '';
  @State title: string = '';
  @State currentValue: number = 0;
  @State badgeColor: string = '#4CAF50';
  @State timeRange: string = '24h'; // '24h', '7d', '30d'
  @State maxValue: number = 0;
  @State minValue: number = 0;
  @State avgValue: number = 0;
  
  @State realTimeModel: LineChartModel = new LineChartModel();
  @State historyModel: LineChartModel = new LineChartModel();

  @State selectedTooltipText: string = '';
  @State isTooltipVisible: boolean = false;
  @State tooltipX: number = 0;
  @State tooltipY: number = 0;

  @State showAvgLine: boolean = true;
  @State showMaxLine: boolean = true;
  @State showMinLine: boolean = true;

  private realTimer: number = -1;
  private realTimePoints: number = 0;
  private realTimeEntries: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private realTimeLabels: string[] = [];

  private historyEntriesAvg: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyEntriesMax: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyEntriesMin: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyLabels: string[] = [];
  private historyFullTimeLabels: string[] = [];

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.type = params['type'] as string;
      this.title = params['title'] as string;
      this.currentValue = params['currentValue'] as number;
      this.badgeColor = params['badgeColor'] as string;
    }
    
    this.initChartModel(this.realTimeModel);
    this.initChartModel(this.historyModel);

    this.realTimeModel.setOnChartValueSelectedListener(new ValueSelectedListener((e: EntryOhos | null, h: Highlight | null) => {
      if (e && h) {
        let unit = this.getUnit();
        let unitStr = unit ? `(${unit})` : '';
        let startX = this.realTimePoints - this.realTimeLabels.length;
        let idx = Math.floor(e.getX()) - startX;
        let timeStr = idx >= 0 && idx < this.realTimeLabels.length ? this.realTimeLabels[idx] : this.getTimeString(new Date());
        this.selectedTooltipText = `${timeStr}\n${this.title}${unitStr}: ${e.getY().toFixed(2)}`;
        this.updateTooltipPosition(h, 160);
        this.isTooltipVisible = true;
      } else {
        this.isTooltipVisible = false;
      }
    }));

    this.historyModel.setOnChartValueSelectedListener(new ValueSelectedListener((e: EntryOhos | null, h: Highlight | null) => {
      if (e && h) {
        let unit = this.getUnit();
        let unitStr = unit ? `(${unit})` : '';
        let index = Math.floor(e.getX());
        let timeStr = index < this.historyFullTimeLabels.length ? this.historyFullTimeLabels[index] : "";
        this.selectedTooltipText = `${timeStr}\n${this.title}${unitStr}: ${e.getY().toFixed(2)}`;
        this.updateTooltipPosition(h, 180);
        this.isTooltipVisible = true;
      } else {
        this.isTooltipVisible = false;
      }
    }));

    this.startRealTimeMock();
    this.loadMockHistoryData();
  }

  aboutToDisappear() {
    if (this.realTimer !== -1) {
      clearInterval(this.realTimer);
    }
  }

  getUnit(): string {
    let t = (this.type + this.title).toLowerCase();
    if (t.includes('temp') || t.includes('温度')) return '℃';
    if (t.includes('humidity') || t.includes('湿度')) return '%';
    if (t.includes('ph')) return 'pH';
    if (t.includes('light') || t.includes('照度') || t.includes('光照')) return 'Lux';
    if (t.includes('co2') || t.includes('二氧化碳')) return 'ppm';
    if (t.includes('speed') || t.includes('风速') || t.includes('fan')) return 'm/s';
    if (t.includes('ec') || t.includes('电导率')) return 'µS/cm';
    if (t.includes('n') || t.includes('氮') || t.includes('p') || t.includes('磷') || t.includes('k') || t.includes('钾')) return 'mg/kg';
    return '';
  }

  getFullTimeString(date: Date): string {
    let y = date.getFullYear();
    let m = (date.getMonth() + 1).toString().padStart(2, '0');
    let d = date.getDate().toString().padStart(2, '0');
    let hh = date.getHours().toString().padStart(2, '0');
    let mm = date.getMinutes().toString().padStart(2, '0');
    let ss = date.getSeconds().toString().padStart(2, '0');
    return `${y}-${m}-${d} ${hh}:${mm}:${ss}`;
  }

  updateTooltipPosition(h: Highlight, widthVp: number): void {
    let xVp = h.getXPx();
    let yVp = h.getYPx();

    let left = xVp + 10;
    if (left + widthVp > 300) {
      left = xVp - widthVp - 10;
    }
    if (left < 8) {
      left = 8;
    }

    let top = yVp - 60;
    if (top < 8) {
      top = yVp + 12;
    }

    this.tooltipX = left;
    this.tooltipY = top;
  }

  toggleHistoryLine(lineKey: string): void {
    if (lineKey === 'avg') {
      this.showAvgLine = !this.showAvgLine;
    } else if (lineKey === 'max') {
      this.showMaxLine = !this.showMaxLine;
    } else if (lineKey === 'min') {
      this.showMinLine = !this.showMinLine;
    }
    this.updateHistoryDataset();
  }

  initChartModel(model: LineChartModel) {
    model.setDrawGridBackground(false);
    model.getDescription()?.setEnabled(false);
    model.getLegend()?.setEnabled(false);
    model.setTouchEnabled(true);
    model.setDragEnabled(true);
    model.setScaleEnabled(false);
    model.setPinchZoom(false);
    model.setExtraOffsets(20, 20, 20, 20); // Extra padding for tooltip and labels

    let xAxis = model.getXAxis();
    if (xAxis) {
      xAxis.setPosition(XAxisPosition.BOTTOM);
      xAxis.setDrawGridLines(true);
      xAxis.setGridColor(0xFFECEFF1);
      xAxis.setAxisLineColor(0xFFECEFF1);
      xAxis.setTextColor(0xFF90A4AE);
      xAxis.setAxisMinimum(0);
      xAxis.setLabelCount(5, true);
    }

    let leftAxis = model.getAxisLeft();
    if (leftAxis) {
      leftAxis.setPosition(YAxisLabelPosition.OUTSIDE_CHART);
      leftAxis.setDrawGridLines(true);
      leftAxis.setGridColor(0xFFECEFF1);
      leftAxis.setAxisLineColor(0xFFECEFF1);
      leftAxis.setTextColor(0xFF90A4AE);
    }

    let rightAxis = model.getAxisRight();
    if (rightAxis) {
      rightAxis.setEnabled(false);
    }
  }

  getTimeString(date: Date): string {
    let h = date.getHours().toString().padStart(2, '0');
    let m = date.getMinutes().toString().padStart(2, '0');
    let s = date.getSeconds().toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  }

  startRealTimeMock() {
    for (let i = 0; i < 60; i++) {
       let val = this.currentValue + (Math.random() * 4 - 2);
       this.realTimeEntries.add(new EntryOhos(this.realTimePoints, val));
       let d = new Date();
       d.setSeconds(d.getSeconds() - (60 - i) * 2);
       this.realTimeLabels.push(this.getTimeString(d));
       this.realTimePoints++;
    }
    this.updateRealTimeDataset();

    this.realTimer = setInterval(() => {
       // Update @State to make UI text refresh
       this.currentValue = this.currentValue + (Math.random() * 4 - 2);
       
       this.realTimeEntries.add(new EntryOhos(this.realTimePoints, this.currentValue));
       this.realTimeLabels.push(this.getTimeString(new Date()));
       this.realTimePoints++;

       if (this.realTimeEntries.size() > 60) {
         this.realTimeEntries.removeIndex(0);
         this.realTimeLabels.shift();
       }
       
       let xAxis = this.realTimeModel.getXAxis();
       if (xAxis) {
         xAxis.setAxisMinimum(this.realTimePoints - 60);
         xAxis.setAxisMaximum(this.realTimePoints);
       }

       this.updateRealTimeDataset();
       this.realTimeModel.notifyDataSetChanged();
       this.realTimeModel.invalidate();
    }, 2000);
  }

  updateRealTimeDataset() {
    let dataSet = new LineDataSet(this.realTimeEntries, "实时数据");
    dataSet.setMode(Mode.CUBIC_BEZIER);
    dataSet.setDrawCircles(true);
    dataSet.setCircleColor(this.getSolidColorInt());
    dataSet.setCircleRadius(3);
    dataSet.setDrawValues(false);
    dataSet.setColorByColor(this.getSolidColorInt());
    dataSet.setLineWidth(3);
    dataSet.setDrawFilled(true);
    dataSet.setFillColor(this.getSolidColorInt());
    dataSet.setFillAlpha(80);

    let dataItems = new JArrayList<ILineDataSet>();
    dataItems.add(dataSet);
    
    let lineData = new LineData(dataItems);
    this.realTimeModel.setData(lineData);

    let xAxis = this.realTimeModel.getXAxis();
    if (xAxis) {
      xAxis.setValueFormatter(new XAxisFormatter(this.realTimeLabels));
    }
  }

  getSolidColorInt(): number {
    return 0xff4CAF50;
  }

  loadMockHistoryData() {
    let points = 0;
    let baseValue = this.currentValue;
    let variance = 10;

    if (this.timeRange === '24h') points = 24;
    else if (this.timeRange === '7d') points = 7;
    else if (this.timeRange === '30d') points = 30;

    let sum = 0;
    let minT = Number.MAX_VALUE;
    let maxT = Number.MIN_VALUE;

    this.historyEntriesAvg.clear();
    this.historyEntriesMax.clear();
    this.historyEntriesMin.clear();
    this.historyLabels = [];
    this.historyFullTimeLabels = [];

    let targetBase = baseValue;
    for (let i = 0; i < points; i++) {
       targetBase = targetBase + (Math.random() * variance * 0.8 - variance * 0.4);
       if (targetBase < 0) targetBase = 0;
       
       let pMax = targetBase + (Math.random() * 5);
       let pMin = targetBase - (Math.random() * 5);
       if (pMin < 0) pMin = 0;

       sum += targetBase;
       if (pMin < minT) minT = pMin;
       if (pMax > maxT) maxT = pMax;

       this.historyEntriesAvg.add(new EntryOhos(i, targetBase));
       this.historyEntriesMax.add(new EntryOhos(i, pMax));
       this.historyEntriesMin.add(new EntryOhos(i, pMin));
       
       let d = new Date();
       if (this.timeRange === '24h') {
         d.setHours(d.getHours() - (points - 1 - i));
         this.historyLabels.push(`${d.getHours()}:00`);
       } else {
         d.setDate(d.getDate() - (points - 1 - i));
         this.historyLabels.push(`${d.getMonth() + 1}-${d.getDate()}`);
       }
       this.historyFullTimeLabels.push(this.getFullTimeString(d));
    }

    this.maxValue = maxT;
    this.minValue = minT;
    this.avgValue = sum / points;

    this.updateHistoryDataset();
  }

  updateHistoryDataset() {
    let dataItems = new JArrayList<ILineDataSet>();

    if (this.showMaxLine) {
      let dsMax = new LineDataSet(this.historyEntriesMax, "最高");
      dsMax.setMode(Mode.CUBIC_BEZIER);
      dsMax.setDrawCircles(true);
      dsMax.setCircleColor(0xffFF5252);
      dsMax.setCircleRadius(3);
      dsMax.setDrawValues(false);
      dsMax.setColorByColor(0xffFF5252); // Red
      dsMax.setLineWidth(2);
      dsMax.setDrawFilled(true);
      dsMax.setFillColor(0xffFF5252);
      dsMax.setFillAlpha(30);
      dataItems.add(dsMax);
    }

    if (this.showAvgLine) {
      let dsAvg = new LineDataSet(this.historyEntriesAvg, "平均");
      dsAvg.setMode(Mode.CUBIC_BEZIER);
      dsAvg.setDrawCircles(true);
      dsAvg.setCircleColor(0xff4CAF50);
      dsAvg.setCircleRadius(4);
      dsAvg.setDrawValues(false);
      dsAvg.setColorByColor(0xff4CAF50);
      dsAvg.setLineWidth(3);
      dsAvg.setDrawFilled(true);
      dsAvg.setFillColor(0xff4CAF50);
      dsAvg.setFillAlpha(50);
      dataItems.add(dsAvg);
    }

    if (this.showMinLine) {
      let dsMin = new LineDataSet(this.historyEntriesMin, "最低");
      dsMin.setMode(Mode.CUBIC_BEZIER);
      dsMin.setDrawCircles(true);
      dsMin.setCircleColor(0xff2196F3);
      dsMin.setCircleRadius(3);
      dsMin.setDrawValues(false);
      dsMin.setColorByColor(0xff2196F3); // Blue
      dsMin.setLineWidth(2);
      dsMin.setDrawFilled(true);
      dsMin.setFillColor(0xff2196F3);
      dsMin.setFillAlpha(70);
      dataItems.add(dsMin);
    }

    let lineData = new LineData(dataItems);
    this.historyModel.setData(lineData);
    
    let xAxis = this.historyModel.getXAxis();
    if (xAxis) {
      xAxis.setAxisMaximum(this.historyLabels.length - 1);
      xAxis.setAxisMinimum(0);
      xAxis.setValueFormatter(new XAxisFormatter(this.historyLabels));
    }

    this.historyModel.notifyDataSetChanged();
    this.historyModel.invalidate();
  }

  @Builder CustomTooltip() {
    if (this.isTooltipVisible) {
      Row() {
        Text(this.selectedTooltipText)
          .fontSize(12)
          .fontColor(Color.White)
          .padding(8)
          .backgroundColor('rgba(0,0,0,0.8)')
          .borderRadius(8)
      }
      .position({ x: this.tooltipX, y: this.tooltipY })
      .zIndex(10)
    }
  }



  @Builder TimeButton(label: string, range: string) {
    Button(label, { type: ButtonType.Capsule })
      .backgroundColor(this.timeRange === range ? '#4CAF50' : '#E8F5E9')
      .fontColor(this.timeRange === range ? Color.White : '#4CAF50')
      .fontSize(14)
      .height(32)
      .margin({ left: 5, right: 5 })
      .onClick(() => {
        this.timeRange = range;
        this.loadMockHistoryData();
      })
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
        Text(this.title)
          .fontSize(24).fontColor('#2C3E50').fontWeight(FontWeight.Bolder).layoutWeight(1)
        Text('模拟连接')
          .fontSize(14)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#4CAF50')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 40, bottom: 20 })
      .alignItems(VerticalAlign.Center)

      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          Stack({ alignContent: Alignment.Top }) {
            Column() {
              Text(`${this.currentValue.toFixed(1)}`)
                .fontSize(48)
                .fontWeight(FontWeight.Bolder)
                .fontColor(this.badgeColor)
                .margin({ top: 20, bottom: 10 })
              Text('实时监测数值')
                .fontSize(14)
                .fontColor('#78909C')
                .margin({ bottom: 30 })

              Stack({ alignContent: Alignment.TopStart }) {
                LineChart({ model: this.realTimeModel })
                  .width('100%')
                  .height(300)
                this.CustomTooltip()
              }
              .width('100%')
            }
            .width('100%')
            .padding(20)
          }
        }
        .tabBar("实时趋势")

        TabContent() {
          Scroll() {
            Column() {
              Text('提示：点击卡片可显示/隐藏对应曲线')
                .fontSize(12)
                .fontColor('#90A4AE')
                .margin({ top: 10, bottom: 10 })
                
              Row() {
                // 平均值卡片
                Column() {
                  Text('平均值 (绿)').fontSize(14).fontColor(this.showAvgLine ? '#78909C' : '#B0BEC5').margin({ bottom: 8 })
                  Text(this.showAvgLine ? this.avgValue.toFixed(1) : '--').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.showAvgLine ? '#4CAF50' : '#B0BEC5')
                }
                .width('30%')
                .padding(15)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .border({ width: 2, color: this.showAvgLine ? '#4CAF50' : '#E0E0E0' })
                .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 5 })
                .onClick(() => {
                  this.toggleHistoryLine('avg');
                })

                // 最高值卡片
                Column() {
                  Text('最高值 (红)').fontSize(14).fontColor(this.showMaxLine ? '#78909C' : '#B0BEC5').margin({ bottom: 8 })
                  Text(this.showMaxLine ? this.maxValue.toFixed(1) : '--').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.showMaxLine ? '#FF5252' : '#B0BEC5')
                }
                .width('30%')
                .padding(15)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .border({ width: 2, color: this.showMaxLine ? '#FF5252' : '#E0E0E0' })
                .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 5 })
                .onClick(() => {
                  this.toggleHistoryLine('max');
                })

                // 最低值卡片
                Column() {
                  Text('最低值 (蓝)').fontSize(14).fontColor(this.showMinLine ? '#78909C' : '#B0BEC5').margin({ bottom: 8 })
                  Text(this.showMinLine ? this.minValue.toFixed(1) : '--').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.showMinLine ? '#2196F3' : '#B0BEC5')
                }
                .width('30%')
                .padding(15)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .border({ width: 2, color: this.showMinLine ? '#2196F3' : '#E0E0E0' })
                .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)', offsetY: 5 })
                .onClick(() => {
                  this.toggleHistoryLine('min');
                })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceEvenly)
              .margin({ bottom: 20 })

              Row() {
                this.TimeButton('24小时', '24h')
                this.TimeButton('近7天', '7d')
                this.TimeButton('近30天', '30d')
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ bottom: 20 })

              Stack({ alignContent: Alignment.TopStart }) {
                LineChart({ model: this.historyModel })
                  .width('100%')
                  .height(300)
                this.CustomTooltip()
              }
              .width('100%')
              .backgroundColor(Color.White)
              .borderRadius(16)
              .padding(10)
            }
            .width('100%')
            .padding({ left: 15, right: 15, bottom: 40 })
          }
        }
        .tabBar("历史数据")
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor('#F2F6F3')
  }
}
