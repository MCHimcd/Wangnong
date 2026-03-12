import { HttpService } from '../services/HttpService';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SettingsView {
  @Consume tempThreshold: number; // 从全局注入的温度告警阈值
  @Consume humidThreshold: number; // 从全局注入的湿度灌溉阈值
  @Consume autoIrrigation: boolean; // 自动灌溉开关
  @Consume autoCooling: boolean; // 自动降温排风开关
  @Consume connectionStatus: 'connected' | 'mock' | 'disconnected'; // 模拟/实际连接状态

  async syncSettings() {
    let success = await HttpService.getInstance().saveSettings(
      this.autoIrrigation,
      this.autoCooling,
      this.tempThreshold,
      this.humidThreshold
    );
    if (!success) {
      console.warn('云端同步失败，使用本地配置兜底');
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('系统与模式切换')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)

        Text('系统模式').fontSize(14).fontColor('#90A4AE').width('100%').padding({ left: 20, bottom: 10 })

        SettingToggleItemComp({
          title: '启用模拟模式',
          description: '断开实际连接，系统进入纯本地模拟数据源状态',
          isOn: this.connectionStatus === 'mock',
          onStateChange: (val) => {
            this.connectionStatus = val ? 'mock' : 'connected'
            promptAction.showToast({ message: val ? '已切至模拟模式' : '已切至实际连接模式', duration: 1500 })
          }
        })

        Text('智能控制').fontSize(14).fontColor('#90A4AE').width('100%').padding({ left: 20, top: 15, bottom: 10 })

        SettingToggleItemComp({
          title: '允许自动灌溉系统',
          description: '当土壤湿度低于设置的下限时自动开启水泵进行灌溉',
          isOn: this.autoIrrigation,
          onStateChange: (val) => {
            this.autoIrrigation = val
            this.syncSettings()
          }
        })

        SettingToggleItemComp({
          title: '允许设备高温排风',
          description: '当温度高于预先设置的上限警戒值时自动开启排风',
          isOn: this.autoCooling,
          onStateChange: (val) => {
            this.autoCooling = val
            this.syncSettings()
          }
        })

        Text('阈值配置').fontSize(14).fontColor('#90A4AE').width('100%').padding({ left: 20, top: 15, bottom: 10 })

        SettingItemComp({
          title: '温度高位告警阈值 (°C)',
          value: this.tempThreshold,
          min: 10,
          max: 50,
          onValueChange: (val) => {
            this.tempThreshold = val
            this.syncSettings()
          }
        })
        SettingItemComp({
          title: '土壤湿度低位灌溉阈值 (%)',
          value: this.humidThreshold,
          min: 10,
          max: 80,
          onValueChange: (val) => {
            this.humidThreshold = val
            this.syncSettings()
          }
        })
      }
      .width('100%')
      .padding({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
    .scrollBar(BarState.Off)
  }
}

@Component
struct SettingToggleItemComp {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop isOn: boolean = false;
  onStateChange?: (val: boolean) => void;

  build() {
    Row() {
      Column() {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2C3E50')
        if (this.description) {
          Text(this.description).fontSize(12).fontColor('#78909C').margin({ top: 6 }).lineHeight(16)
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding({ right: 10 })

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
    .padding({
      left: 20,
      right: 20,
      top: 18,
      bottom: 18
    })
    .backgroundColor(Color.White)
    .borderRadius(20)
    .margin({ bottom: 15 })
    .shadow({
      radius: 15,
      color: 'rgba(76, 175, 80, 0.05)',
      offsetX: 0,
      offsetY: 5
    })
  }
}

@Component
struct SettingItemComp {
  @Prop title: string = '';
  @Prop value: number = 0;
  @Prop min: number = 0;
  @Prop max: number = 100;
  onValueChange?: (val: number) => void;

  build() {
    Column() {
      Row() {
        Text(this.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#2C3E50')
        Blank()
        Text(`${this.value.toFixed(0)}`).fontSize(18).fontWeight(FontWeight.Bolder).fontColor('#4CAF50')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 20,
        bottom: 10
      })

      Slider({ value: this.value, min: this.min, max: this.max })
        .selectedColor('#4CAF50')
        .blockColor('#FFFFFF')
        .trackColor('#E8F5E9')
        .onChange((val: number) => {
          if (this.onValueChange) {
            this.onValueChange(val);
          }
        })
        .margin({ left: 10, right: 10, bottom: 20 })
    }
    .width('90%')
    .backgroundColor(Color.White)
    .borderRadius(20)
    .margin({ bottom: 15 })
    .shadow({
      radius: 15,
      color: 'rgba(76, 175, 80, 0.05)',
      offsetX: 0,
      offsetY: 5
    })
  }
}
