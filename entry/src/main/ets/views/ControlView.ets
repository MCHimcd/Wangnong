import { DeviceState } from '../models/DeviceState';
import router from '@ohos.router';

interface DeviceControlItem {
  type: string;
  title: string;
  icon: string;
  isOn: boolean;
  onToggle: (isOn: boolean) => void;
}

@Component
export struct ControlView {
  @Prop deviceId: string = '';
  @ObjectLink deviceState: DeviceState;

  private getDeviceItems(): DeviceControlItem[] {
    return [
      {
        type: 'water_pump',
        title: '水泵',
        icon: '💧',
        isOn: this.deviceState.waterPumpOn,
        onToggle: (isOn: boolean) => {
          this.deviceState.waterPumpOn = isOn;
        }
      },
      {
        type: 'led_light',
        title: '补光灯',
        icon: '💡',
        isOn: this.deviceState.ledOn,
        onToggle: (isOn: boolean) => {
          this.deviceState.ledOn = isOn;
        }
      },
      {
        type: 'fan',
        title: '排风扇',
        icon: '🌀',
        isOn: this.deviceState.fanOn,
        onToggle: (isOn: boolean) => {
          this.deviceState.fanOn = isOn;
        }
      }
    ];
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Row() {
            Text('⚙️')
              .fontSize(20)
              .margin({ right: 6 })
            Text('设备实时状态')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2D24')
          }

          Blank()

          Text('LIVE')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor('#2E7D32')
            .borderRadius(12)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ top: 24, bottom: 16 })
        .padding({ left: 20, right: 20 })

        Grid() {
          ForEach(this.getDeviceItems(), (item: DeviceControlItem) => {
            GridItem() {
              ControlCardComp({
                type: item.type,
                title: item.title,
                icon: item.icon,
                isOn: item.isOn,
                onStateChange: item.onToggle
              })
            }
          }, (item: DeviceControlItem) => item.type)
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
  @Prop onStateChange: (isOn: boolean) => void = () => {};
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
            .fill(this.isOn ? '#2E7D32' : '#B0B7B0')
            .margin({ right: 6 })

          Text(this.isOn ? '运行中' : '已停止')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isOn ? '#2E7D32' : '#7B847D')
        }
      }
      .width('74%')
      .height(36)
      .backgroundColor(this.isOn ? '#E5F3E7' : '#F4F5F4')
      .border({
        width: 1,
        color: this.isOn ? '#92C69A' : '#D9DFDA'
      })
      .stateEffect(false)
      .onClick(() => {
        this.onStateChange(!this.isOn);
      })

      Blank()

      Text(this.type === 'water_pump' ? '灌溉设备' : this.type === 'led_light' ? '光照设备' : '通风设备')
        .fontSize(12)
        .fontColor('#98A29A')
        .margin({ bottom: 8 })
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
    .shadow({
      radius: this.isTouched ? 6 : 10,
      color: this.isOn ? 'rgba(58, 131, 66, 0.14)' : 'rgba(0, 0, 0, 0.06)',
      offsetX: 0,
      offsetY: this.isTouched ? 2 : 5
    })
    .scale({ x: this.isTouched ? 0.98 : 1, y: this.isTouched ? 0.98 : 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
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