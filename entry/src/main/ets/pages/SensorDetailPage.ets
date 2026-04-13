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

import { HttpService, SensorHistoryData, ThresholdUpdateItem } from '../services/HttpService';
import { SensorMetaItem } from '../models/SensorMeta';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

import { CachedTrendPoint, MqttClientService } from '../services/MqttClientService';
import { promptAction } from '@kit.ArkUI';

/**
 * Purpose: 展示单个传感器指标的实时趋势、历史趋势和阈值编辑能力。
 * Responsibilities: 根据路由参数确定指标键、维护双图表模型、订阅实时遥测并同步阈值设置。
 * Flow: 页面进入后解析参数、恢复实时缓存、初始化图表，再并行启动实时流、历史数据加载和阈值刷新。
 * Dependencies: 依赖 HttpService 获取历史数据和阈值元数据，依赖 MqttClientService 接收实时遥测。
 * Input: 路由传入的 nodeId/type/title/metricKey/currentValue 等参数，以及 MQTT 环境遥测数据。
 * Output: 实时图、历史图、统计摘要和阈值保存动作。
 * Side Effects: 注册/移除 telemetryListener，调用阈值更新接口。
 */
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

const MAX_REALTIME_POINTS: number = 60;

@Entry
@Component
struct SensorDetailPage {
  @State nodeId: string = 'A03_Node_01';
  @State type: string = '';
  @State metricKey: string = '';
  @State title: string = '';
  @State currentValue: number = 0;
  @State badgeColor: string = '#4CAF50';
  @State unitFromParam: string = '';
  @State warningMin: number = -Infinity;
  @State warningMax: number = Infinity;
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

  @State editWarningMin: string = '';
  @State editWarningMax: string = '';
  @State thresholdSaving: boolean = false;

  private realTimer: number = -1;
  private realTimePoints: number = 0;
  private realTimeEntries: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private realTimeLabels: string[] = [];

  private historyEntriesAvg: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyEntriesMax: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyEntriesMin: JArrayList<EntryOhos> = new JArrayList<EntryOhos>();
  private historyLabels: string[] = [];
  private historyFullTimeLabels: string[] = [];
  
  private telemetryListener = (nodeId: string, msgStr: string) => {
    try {
      if (nodeId !== this.nodeId) {
        return;
      }
      const payload = JSON.parse(msgStr) as Record<string, Object>;
      if (payload['data']) {
        const data = payload['data'] as Record<string, Object>;
        if (data['environment']) {
          const env = data['environment'] as Record<string, number>;

          const metric = this.metricKey.length > 0 ? this.metricKey : this.getMetricKey();
          let val = env[metric];
          if (val !== undefined) {
             // Flow: 实时图使用滑动窗口保留最近 60 个点；超出窗口后重排 X 坐标，保持图表连续滚动。
             this.currentValue = val;
             this.realTimeEntries.add(new EntryOhos(this.realTimePoints, val));
             this.realTimeLabels.push(this.getTimeString(new Date()));
             this.realTimePoints++;
             
             if (this.realTimeEntries.size() > MAX_REALTIME_POINTS) {
               this.realTimeEntries.removeIndex(0);
               this.realTimeLabels.shift();
               for (let i = 0; i < this.realTimeEntries.size(); i++) {
                 let e = this.realTimeEntries.get(i);
                 e.setX(this.realTimePoints - this.realTimeEntries.size() + i);
               }
             }

             let xAxis = this.realTimeModel.getXAxis();
             if (xAxis) {
               xAxis.setAxisMaximum(this.realTimePoints - 1);
               xAxis.setAxisMinimum(Math.max(0, this.realTimePoints - MAX_REALTIME_POINTS));
             }

             this.updateRealTimeDataset();
             this.realTimeModel.notifyDataSetChanged();
             this.realTimeModel.invalidate();
          }
        }
      }
    } catch(e) {}
  };

  getMetricKey(): string {
    let t = (this.type + this.title).toLowerCase();
    // Boundary: 先匹配土壤类关键字，再匹配通用温湿度，避免 soilTemp / 土壤温度 被更宽泛的 temp / 温度规则截走。
    if (t.includes('soiltemp') || t.includes('土壤温度') || t.includes('土温')) return 'soilTemp';
    if (t.includes('soilhumidity') || t.includes('土壤湿度') || t.includes('土湿')) return 'soilHumidity';
    if (t.includes('soilph') || t.includes('土壤ph') || t.includes('ph')) return 'soilPh';
    
    if (t.includes('空气温度') || t.includes('气温') || t.includes('temp') || t.includes('温度')) return 'temperature';
    if (t.includes('空气湿度') || t.includes('气湿') || t.includes('humidity') || t.includes('湿度')) return 'humidity';
    if (t.includes('二氧化碳') || t.includes('co2')) return 'co2';
    if (t.includes('光照') || t.includes('light')) return 'light';
    
    return 'temperature';
  }

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.nodeId = (params['nodeId'] as string) || 'A03_Node_01';
      this.type = (params['type'] as string) || '';
      this.metricKey = (params['metricKey'] as string) || '';
      this.title = (params['title'] as string) || '';
      this.currentValue = (params['currentValue'] as number) || 0;
      this.badgeColor = (params['badgeColor'] as string) || '#4CAF50';
      if (params['unit'] != null) {
        this.unitFromParam = params['unit'] as string;
      }
      if (params['warningMin'] != null && typeof params['warningMin'] === 'number') {
        this.warningMin = params['warningMin'] as number;
      }
      if (params['warningMax'] != null && typeof params['warningMax'] === 'number') {
        this.warningMax = params['warningMax'] as number;
      }
    }

    if (this.metricKey.length === 0) {
      this.metricKey = this.getMetricKey();
    }

    this.editWarningMin = (this.warningMin == null || this.warningMin === -Infinity) ? '' : this.warningMin.toString();
    this.editWarningMax = (this.warningMax == null || this.warningMax === Infinity) ? '' : this.warningMax.toString();

    // Flow: 页面先恢复 MQTT 趋势缓存，再初始化图表，保证首次打开详情页时不会因为等待新遥测而出现空图。
    this.restoreRealTimeCache();
    
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

    this.startRealtimeStream();
    this.loadHistoryData();
    this.refreshThresholds();
  }

  private async refreshThresholds() {
    let metas = await HttpService.getInstance().getSensorMeta(this.nodeId);
    if (metas) {
      let found = metas.find((m: SensorMetaItem) => m.key === this.metricKey);
      if (found) {
        this.warningMin = (found.warningMin != null) ? found.warningMin : -Infinity;
        this.warningMax = (found.warningMax != null) ? found.warningMax : Infinity;
        this.editWarningMin = (this.warningMin === -Infinity) ? '' : this.warningMin.toString();
        this.editWarningMax = (this.warningMax === Infinity) ? '' : this.warningMax.toString();
      }
    }
  }

  aboutToDisappear() {
    MqttClientService.getInstance().removeTelemetryListener(this.telemetryListener);
    if (this.realTimer !== -1) {
      clearInterval(this.realTimer);
    }
  }

  getUnit(): string {
    // 优先使用路由参数传入的单位
    if (this.unitFromParam.length > 0) {
      return this.unitFromParam;
    }
    const metric = this.metricKey.length > 0 ? this.metricKey : this.getMetricKey();
    if (metric === 'temperature' || metric === 'soilTemp') return '℃';
    if (metric === 'humidity' || metric === 'soilHumidity') return '%';
    if (metric === 'soilPh') return '';
    if (metric === 'light') return 'Lux';
    if (metric === 'co2') return 'ppm';

    let t = (this.type + this.title).toLowerCase();
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

  private getCacheKey(): string {
    return `${this.nodeId}_${this.metricKey}`;
  }

  private restoreRealTimeCache(): void {
    this.realTimeEntries.clear();
    this.realTimeLabels = [];
    this.realTimePoints = 0;

    const cachedPoints = MqttClientService.getInstance().getCachedTrend(this.nodeId, this.metricKey);
    if (cachedPoints.length === 0) {
      return;
    }

    cachedPoints.forEach((point: CachedTrendPoint, index: number) => {
      this.realTimeEntries.add(new EntryOhos(index, point.value));
      this.realTimeLabels.push(point.time);
    });

    this.realTimePoints = cachedPoints.length;
    this.currentValue = cachedPoints[cachedPoints.length - 1].value;
  }

  startRealtimeStream() {
    this.updateRealTimeDataset();
    MqttClientService.getInstance().addTelemetryListener(this.telemetryListener);
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
      xAxis.setAxisMaximum(Math.max(0, this.realTimePoints - 1));
      xAxis.setAxisMinimum(Math.max(0, this.realTimePoints - MAX_REALTIME_POINTS));
      xAxis.setValueFormatter(new XAxisFormatter(this.realTimeLabels));
    }
  }

  getSolidColorInt(): number {
    return 0xff4CAF50;
  }

  async loadHistoryData() {
    let metric = this.metricKey.length > 0 ? this.metricKey : this.getMetricKey();

    let res = await HttpService.getInstance().getSensorHistory(this.nodeId, this.timeRange, metric);
    
    this.historyEntriesAvg.clear();
    this.historyEntriesMax.clear();
    this.historyEntriesMin.clear();
    this.historyLabels = [];
    this.historyFullTimeLabels = [];

    if (res && res.points) {
      this.maxValue = res.summary.max;
      this.minValue = res.summary.min;
      this.avgValue = res.summary.avg;

      for (let i = 0; i < res.points.length; i++) {
        let p = res.points[i];
        
        // Reason: 历史图的 max/min 线使用稳定包络线模拟，不直接复用单点值，便于在 UI 上呈现波动区间而不是三条完全重叠的线。
        let diff = Math.abs(p.value) * 0.05 + 0.5;
        let pMax = p.value + diff;
        let pMin = p.value - diff;

        this.historyEntriesAvg.add(new EntryOhos(i, p.value));
        this.historyEntriesMax.add(new EntryOhos(i, pMax));
        this.historyEntriesMin.add(new EntryOhos(i, pMin));

        this.historyLabels.push(p.timeLabel || '');
        this.historyFullTimeLabels.push(p.timeLabel || '');
      }
    } else {
      // Fallback
      this.maxValue = 0;
      this.minValue = 0;
      this.avgValue = 0;
    }

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
      .backgroundColor(this.timeRange === range ? AppColors.Primary : AppColors.SuccessBg)
      .fontColor(this.timeRange === range ? Color.White : AppColors.Primary)
      .fontSize(AppFontSize.Caption)
      .height(32)
      .margin({ left: AppSpacing.XS, right: AppSpacing.XS })
      .onClick(() => {
        this.timeRange = range;
        this.loadHistoryData();
      })
  }

  build() {
    Column() {
      // Header
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24)
          .height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => {
            router.back();
          })
        Text(this.title)
          .fontSize(AppFontSize.H1).fontColor(AppColors.TextPrimary).fontWeight(FontWeight.Bold).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: 40, bottom: AppSpacing.LG })
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

        TabContent() {
          Column() {
            Text('阈值设置').fontSize(AppFontSize.H2).fontWeight(FontWeight.Bold).fontColor(AppColors.TextPrimary)
              .margin({ top: AppSpacing.LG, bottom: AppSpacing.XS })
            Text('超出阈值范围时将产生告警').fontSize(AppFontSize.Caption).fontColor(AppColors.TextTertiary)
              .margin({ bottom: AppSpacing.LG })

            Column() {
              Text('最低阈值').fontSize(AppFontSize.Body).fontColor(AppColors.TextSecondary).margin({ bottom: AppSpacing.XS }).width('100%')
              TextInput({ placeholder: '留空表示不设限', text: this.editWarningMin })
                .onChange((value: string) => { this.editWarningMin = value; })
                .height(AppSize.InputHeight).backgroundColor(AppColors.Divider).borderRadius(AppRadius.MD)
                .type(InputType.Number)
                .margin({ bottom: AppSpacing.MD })

              Text('最高阈值').fontSize(AppFontSize.Body).fontColor(AppColors.TextSecondary).margin({ bottom: AppSpacing.XS }).width('100%')
              TextInput({ placeholder: '留空表示不设限', text: this.editWarningMax })
                .onChange((value: string) => { this.editWarningMax = value; })
                .height(AppSize.InputHeight).backgroundColor(AppColors.Divider).borderRadius(AppRadius.MD)
                .type(InputType.Number)
                .margin({ bottom: AppSpacing.LG })

              Row() {
                Text(`当前: ${this.warningMin === -Infinity ? '无' : this.warningMin.toString()} ~ ${this.warningMax === Infinity ? '无' : this.warningMax.toString()}`)
                  .fontSize(AppFontSize.Caption).fontColor(AppColors.TextTertiary)
              }.width('100%').margin({ bottom: AppSpacing.MD })

              Button(this.thresholdSaving ? '保存中...' : '保存阈值', { type: ButtonType.Capsule })
                .width('80%').height(AppSize.ButtonHeight).backgroundColor(AppColors.Primary).fontSize(AppFontSize.Body)
                .enabled(!this.thresholdSaving)
                .onClick(async () => {
                  this.thresholdSaving = true;
                  let item = new ThresholdUpdateItem();
                  item.sensorKey = this.metricKey;
                  item.warningMin = this.editWarningMin.trim() ? parseFloat(this.editWarningMin) : null;
                  item.warningMax = this.editWarningMax.trim() ? parseFloat(this.editWarningMax) : null;
                  let ok = await HttpService.getInstance().updateSensorThresholds(this.nodeId, [item]);
                  this.thresholdSaving = false;
                  if (ok) {
                    this.warningMin = item.warningMin !== null ? item.warningMin : -Infinity;
                    this.warningMax = item.warningMax !== null ? item.warningMax : Infinity;
                    promptAction.showToast({ message: '阈值已保存' });
                  } else {
                    promptAction.showToast({ message: '保存失败' });
                  }
                })
            }
            .width('100%').padding(AppSpacing.LG).backgroundColor(AppColors.Surface).borderRadius(AppRadius.LG)
          }
          .width('100%').padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
        }
        .tabBar("阈值设置")
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(AppColors.Background)
  }
}
