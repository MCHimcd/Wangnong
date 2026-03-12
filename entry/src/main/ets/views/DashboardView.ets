import { SensorData } from '../models/SensorData';
import router from '@ohos.router';

@Component
export struct DashboardView {
  @ObjectLink sensorData: SensorData;

  build() {
    Column() {
      Text('实时环境监测')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#2C3E50')
        .margin({ top: 30, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center)

      Grid() {
        GridItem() {
          DataCardComp({
            type: 'temperature',
            title: '温度',
            value: `${this.sensorData.temperature.toFixed(1)}`,
            unit: '°C',
            badgeColor: '#FF7043',
            bgColor: '#FFF3E0',
            currentValue: this.sensorData.temperature
          })
        }

        GridItem() {
          DataCardComp({
            type: 'humidity',
            title: '湿度',
            value: `${this.sensorData.humidity.toFixed(1)}`,
            unit: '%',
            badgeColor: '#42A5F5',
            bgColor: '#E3F2FD',
            currentValue: this.sensorData.humidity
          })
        }

        GridItem() {
          DataCardComp({
            type: 'light',
            title: '光照',
            value: `${this.sensorData.light.toFixed(0)}`,
            unit: 'Lux',
            badgeColor: '#FFA726',
            bgColor: '#FFF8E1',
            currentValue: this.sensorData.light
          })
        }

        GridItem() {
          DataCardComp({
            type: 'co2',
            title: '二氧化碳',
            value: `${this.sensorData.co2.toFixed(0)}`,
            unit: 'ppm',
            badgeColor: '#26A69A',
            bgColor: '#E8F5E9',
            currentValue: this.sensorData.co2
          })
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .columnsGap(15)
      .rowsGap(15)
      .layoutWeight(1)
      .width('90%')
      .margin({ top: 10, bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}

@Component
struct DataCardComp {
  @Prop type: string = '';
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  @Prop badgeColor: string = '#000000';
  @Prop bgColor: string = '#FFFFFF';
  @Prop currentValue: number = 0;
  @State isTouched: boolean = false;

  build() {
    Column() {
      Row() {
        Circle({ width: 14, height: 14 }).fill(this.badgeColor).margin({ right: 8 })
        Text(this.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#546E7A')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 20 })

      Row() {
        Text(this.value).fontSize(36).fontWeight(FontWeight.Bolder).fontColor('#263238')
        Text(this.unit).fontSize(16).fontWeight(FontWeight.Normal).fontColor('#78909C').margin({ left: 4, bottom: 6 })
      }.alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .borderRadius(20)
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .shadow({
      radius: this.isTouched ? 5 : 15,
      color: 'rgba(76, 175, 80, 0.1)',
      offsetX: 0,
      offsetY: this.isTouched ? 2 : 8
    })
    .scale({ x: this.isTouched ? 0.96 : 1, y: this.isTouched ? 0.96 : 1 })
    .animation({ duration: 200, curve: Curve.EaseInOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isTouched = false;
      }
    })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/SensorDetailPage',
        params: {
          type: this.type,
          title: this.title,
          currentValue: this.currentValue,
          badgeColor: this.badgeColor
        }
      })
    })
  }
}
