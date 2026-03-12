import { DeviceState } from '../models/DeviceState';
import { MqttClientService } from '../services/MqttClientService';
import router from '@ohos.router';

@Component
export struct ControlView {
  @Prop deviceId: string = '';
  @ObjectLink deviceState: DeviceState;

  build() {
    Scroll() {
      Column() {
        Text('智能控制中心')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)

        ControlCardComp({
          type: 'water_pump',
          title: '灌溉系统 - 水泵',
          isOn: this.deviceState.waterPumpOn,
          onStateChange: (isOn: boolean) => {
            this.deviceState.waterPumpOn = isOn;
            let param: Record<string, number> = { "duration_seconds": 15 };
            MqttClientService.getInstance().publishCommand(
              this.deviceId,
              'water_pump',
              isOn ? 'turn_on' : 'turn_off',
              isOn ? param : undefined
            );
          }
        })

        // LED 补光控制
        Column() {
          Row() {
            Text('植物补光 - LED灯')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.deviceState.ledOn ? '#FFFFFF' : '#2C3E50')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.deviceState.ledOn })
              .selectedColor('#E6EE9C')
              .switchPointColor('#4CAF50')
              .onChange((isOn: boolean) => {
                this.deviceState.ledOn = isOn;
                MqttClientService.getInstance().publishCommand(
                  this.deviceId,
                  'led_light',
                  isOn ? 'turn_on' : 'turn_off'
                );
              })
          }
          .width('100%')
          .padding({
            left: 20,
            right: 20,
            top: 20,
            bottom: 10
          })

          Row() {
            Text('亮度').fontSize(14).fontColor(this.deviceState.ledOn ? '#E8F5E9' : '#78909C')
            Slider({ value: this.deviceState.ledBrightness, min: 0, max: 100 })
              .selectedColor(this.deviceState.ledOn ? '#FFFFFF' : '#4CAF50')
              .blockColor('#FFFFFF')
              .onChange((value: number, mode: SliderChangeMode) => {
                this.deviceState.ledBrightness = value;
                if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                  let param: Record<string, number> = { "brightness": Math.round(value) };
                  MqttClientService.getInstance().publishCommand(
                    this.deviceId,
                    'led_light',
                    'set_brightness',
                    param
                  );
                }
              })
              .layoutWeight(1)
              .margin({ left: 10, right: 10 })
            Text(`${this.deviceState.ledBrightness.toFixed(0)}%`)
              .fontSize(14)
              .fontColor(this.deviceState.ledOn ? '#E8F5E9' : '#78909C')
              .width(40)
          }.width('100%').padding({ left: 20, right: 20, bottom: 20 })
        }
        .width('90%')
        .backgroundColor(this.deviceState.ledOn ? '#4CAF50' : Color.White)
        .borderRadius(20)
        .margin({ bottom: 15 })
        .shadow({
          radius: 15,
          color: 'rgba(76, 175, 80, 0.1)',
          offsetX: 0,
          offsetY: 8
        })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/DeviceDetailPage',
            params: { type: 'led_light', title: '植物补光 - LED灯', isOn: this.deviceState.ledOn }
          });
        })

        // 扩展设备 - YOLO CNN 智能识别
        ControlCardComp({
          type: 'ai_camera',
          title: 'AI 摄像头 - YOLO识别',
          isOn: this.deviceState.extensionOn,
          onStateChange: (isOn: boolean) => {
            this.deviceState.extensionOn = isOn;
            MqttClientService.getInstance().publishCommand(
              this.deviceId,
              'camera',
              isOn ? 'turn_on' : 'turn_off'
            );
          }
        })

      }
      .width('100%')
      .padding({ bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
    .scrollBar(BarState.Off)
  }
}

@Component
struct ControlCardComp {
  @Prop type: string = '';
  @Prop title: string = '';
  @Prop isOn: boolean = false;
  onStateChange: ((isOn: boolean) => void) | null = null;
  @State isTouched: boolean = false;

  build() {
    Row() {
      Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.isOn ? '#FFFFFF' : '#2C3E50')
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor('#E6EE9C')
        .switchPointColor('#4CAF50')
        .onChange((isOn: boolean) => {
          if (this.onStateChange) {
            this.onStateChange(isOn);
          }
        })
    }
    .width('90%')
    .height(85)
    .backgroundColor(this.isOn ? '#4CAF50' : Color.White)
    .borderRadius(20)
    .margin({ bottom: 15 })
    .padding({ left: 20, right: 20 })
    .shadow({
      radius: this.isTouched ? 5 : 15,
      color: 'rgba(76, 175, 80, 0.1)',
      offsetX: 0,
      offsetY: this.isTouched ? 2 : 8
    })
    .scale({ x: this.isTouched ? 0.98 : 1, y: this.isTouched ? 0.98 : 1 })
    .animation({ duration: 300, curve: Curve.FastOutSlowIn })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isTouched = true;
      } else if (event.type === TouchType.Up ||
        event.type === TouchType.Cancel) {
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