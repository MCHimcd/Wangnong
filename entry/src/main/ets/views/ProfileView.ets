import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

@Component
export struct ProfileView {
  build() {
    Scroll() {
      Column() {
        Text('个人中心')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)
          
        Blank()

        Button('退出登录', { type: ButtonType.Capsule })
          .width('90%')
          .height(50)
          .margin({ top: 40, bottom: 40 })
          .backgroundColor('#E53935')
          .fontColor(Color.White)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .onClick(async () => {
             try {
                let context = getContext(this) as common.UIAbilityContext;
                let pref = await preferences.getPreferences(context, 'AppPreferences');
                await pref.put('autoLogin', false);
                await pref.flush();
                router.replaceUrl({ url: 'pages/LoginPage' });
             } catch (err) {
                console.error(`Logout failed. Code:${err.code},message:${err.message}`);
                promptAction.showToast({ message: '退出失败' });
             }
          })
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
