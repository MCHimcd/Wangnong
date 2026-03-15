import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

@Component
export struct ProfileView {
  @State avatarSrc: Resource = $r('app.media.startIcon');
  @State userId: string = 'WangNong_001';

  build() {
    Scroll() {
      Column() {
        Text('我的')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)
          
        Column() {
          Image(this.avatarSrc)
            .width(100)
            .height(100)
            .borderRadius(50)
            .backgroundColor('#E0E0E0')
            .margin({ top: 20, bottom: 10 })
            .onClick(() => {
              // 简易模拟修改头像
              promptAction.showActionMenu({
                title: '修改头像',
                buttons: [
                  { text: '拍照', color: '#4CAF50' },
                  { text: '从相册选择', color: '#4CAF50' }
                ]
              }).then(data => {
                promptAction.showToast({ message: '模拟：头像已更新' });
              });
            })
            
          Text(`ID: ${this.userId}`)
            .fontSize(18)
            .fontColor('#546E7A')
            .margin({ bottom: 30 })

          Row() {
            Text('溯源码：扫码展示作物信息')
              .fontSize(16)
              .fontColor('#2C3E50')
            Blank()
            Text('...')
              .fontSize(16)
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 15 })
          .onClick(() => {
            promptAction.showToast({ message: '此功能暂未开放' });
          })

          Row() {
            Text('设置')
              .fontSize(16)
              .fontColor('#2C3E50')
            Blank()
            Text('>')
              .fontSize(16)
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 15 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/SettingsPage' });
          })
          
          Row() {
            Text('切换账号')
              .fontSize(16)
              .fontColor('#2C3E50')
            Blank()
            Text('>')
              .fontSize(16)
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 15 })
          .onClick(() => {
             router.replaceUrl({ url: 'pages/LoginPage' });
          })

          Row() {
            Text('退出登录')
              .fontSize(16)
              .fontColor('#E53935')
            Blank()
            Text('>')
              .fontSize(16)
              .fontColor('#E53935')
          }
          .width('90%')
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 40 })
          .onClick(async () => {
             try {
                let context = getContext(this) as common.UIAbilityContext;
                let pref = await preferences.getPreferences(context, 'AppPreferences');
                await pref.put('autoLogin', false);
                await pref.flush();
                AppStorage.setOrCreate('isLoggedIn', false);
                router.replaceUrl({ url: 'pages/LoginPage' });
             } catch (err) {
                console.error(`Logout failed. Code:${err.code},message:${err.message}`);
                promptAction.showToast({ message: '退出失败' });
             }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Blank()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
    .scrollBar(BarState.Off)
  }
}
