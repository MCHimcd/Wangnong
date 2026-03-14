import { DeviceState } from '../models/DeviceState';
import router from '@ohos.router';

@Component
export struct ControlView {
  @Prop deviceId: string = '';
  @ObjectLink deviceState: DeviceState;
  @State isSmartMode: boolean = false;

  build() {
    Scroll() {
      Column() {
        Text('设备实时状态')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 10 })
          .width('100%')
          .textAlign(TextAlign.Center)
          
        Row() {
          Text('智能控制模式')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#34495E')
          
          Toggle({ type: ToggleType.Switch, isOn: this.isSmartMode })
            .selectedColor('#4CAF50')
            .onChange((isOn: boolean) => {
              this.isSmartMode = isOn;
            })
        }
        .width('90%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .margin({ bottom: 20 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 2 })

        Grid() {
          GridItem() {
            ControlCardComp({
              type: 'water_pump',
              title: '水泵',
              icon: '💧',
              isOn: this.deviceState.waterPumpOn,
              isSmartMode: this.isSmartMode,
              onStateChange: (isOn: boolean) => {
                this.deviceState.waterPumpOn = isOn;
              }
            })
          }
          GridItem() {
            ControlCardComp({
              type: 'led_light',
              title: '补光灯',
              icon: '💡',
              isOn: this.deviceState.ledOn,
              isSmartMode: this.isSmartMode,
              onStateChange: (isOn: boolean) => {
                this.deviceState.ledOn = isOn;
              }
            })
          }
          GridItem() {
            ControlCardComp({
              type: 'fan',
              title: '排风扇',
              icon: '🌀',
              isOn: this.deviceState.fanOn,
              isSmartMode: this.isSmartMode,
              onStateChange: (isOn: boolean) => {
                this.deviceState.fanOn = isOn;
              }
            })
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(14)
        .rowsGap(14)
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 28 })

      }
      .width('100%')
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F4')
    .scrollBar(BarState.Off)
  }
}

@Component
struct ControlCardComp {
  @Prop type: string = '';
  @Prop title: string = '';
  @Prop icon: string = '⚙️';
  @Prop isOn: boolean = false;
  @Prop isSmartMode: boolean = false;
  onStateChange: (isOn: boolean) => void = () => {};
  @State isTouched: boolean = false;

  build() {
    Column() {
      Text(this.icon)
        .fontSize(38)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 10, bottom: 12 })

      Text(this.title)
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor('#212B25')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 12 })

      Button({ type: ButtonType.Capsule }) {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.isSmartMode ? (this.isOn ? '#1976D2' : '#90A4AE') : (this.isOn ? '#2E7D32' : '#B0B7B0'))
            .margin({ right: 6 })

          Text(this.isSmartMode ? (this.isOn ? '自动(运行)' : '自动(停止)') : (this.isOn ? '运行中' : '已停止'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isSmartMode ? (this.isOn ? '#1976D2' : '#78909C') : (this.isOn ? '#2E7D32' : '#7B847D'))
        }
      }
      .width('82%')
      .height(36)
      .backgroundColor(this.isSmartMode ? (this.isOn ? '#E3F2FD' : '#ECEFF1') : (this.isOn ? '#E5F3E7' : '#F4F5F4'))
      .border({
        width: 1,
        color: this.isSmartMode ? (this.isOn ? '#90CAF9' : '#CFD8DC') : (this.isOn ? '#92C69A' : '#D9DFDA')
      })
      .stateEffect(!this.isSmartMode)
      .onClick(() => {
        if (!this.isSmartMode) {
          this.onStateChange(!this.isOn);
        }
      })

      Blank()
    }
    .width('100%')
    .height(176)
    .backgroundColor(this.isOn ? '#EAF4EA' : '#FFFFFF')
    .border({
      width: 2,
      color: this.isOn ? '#6AAA71' : '#D8DEDA'
    })
    .borderRadius(16)
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .opacity(this.isSmartMode ? 0.6 : 1.0)
    .shadow({
      radius: this.isTouched ? 6 : 10,
      color: this.isOn ? 'rgba(58, 131, 66, 0.14)' : 'rgba(0, 0, 0, 0.06)',
      offsetX: 0,
      offsetY: this.isTouched ? 2 : 5
    })
    .scale({ x: this.isTouched && !this.isSmartMode ? 0.98 : 1, y: this.isTouched && !this.isSmartMode ? 0.98 : 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (this.isSmartMode) return;
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isTouched = false;
      }
    })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/DeviceDetailPage',
        params: { type: this.type, title: this.title, isOn: this.isOn }
      });
    })
  }
}