import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';

@Entry
@Component
struct ChangePasswordPage {
  @State oldPass: string = '';
  @State newPass: string = '';
  @State confirmPass: string = '';

  build() {
    Column() {
      // 头部导航
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })
          .fontColor('#333333')
          .onClick(() => {
            router.back();
          })
        Text('修改密码')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      Column() {
        TextInput({ placeholder: '请输入原密码', text: this.oldPass })
          .type(InputType.Password)
          .width('90%')
          .height(50)
          .margin({ top: 20, bottom: 15 })
          .onChange((val: string) => this.oldPass = val)

        TextInput({ placeholder: '请输入新密码', text: this.newPass })
          .type(InputType.Password)
          .width('90%')
          .height(50)
          .margin({ bottom: 15 })
          .onChange((val: string) => this.newPass = val)

        TextInput({ placeholder: '请确认新密码', text: this.confirmPass })
          .type(InputType.Password)
          .width('90%')
          .height(50)
          .margin({ bottom: 30 })
          .onChange((val: string) => this.confirmPass = val)

        Button('确认修改')
          .width('90%')
          .height(50)
          .backgroundColor('#4CAF50')
          .onClick(async () => {
            if (!this.oldPass || !this.newPass || !this.confirmPass) {
              promptAction.showToast({ message: '请填写完整信息' });
              return;
            }
            if (this.newPass !== this.confirmPass) {
              promptAction.showToast({ message: '两次新密码输入不一致' });
              return;
            }

            let success = await HttpService.getInstance().changePassword(this.oldPass, this.newPass);
            if (!success) {
              promptAction.showToast({ message: '密码修改失败，请检查原密码或网络' });
              return;
            }

            promptAction.showToast({ message: '密码修改成功' });
            router.back();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}