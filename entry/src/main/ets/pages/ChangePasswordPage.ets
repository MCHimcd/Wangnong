import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

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
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => { router.back(); })
        Text('修改密码')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .alignItems(VerticalAlign.Center)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })

      Column() {
        TextInput({ placeholder: '请输入原密码', text: this.oldPass })
          .type(InputType.Password)
          .width('90%')
          .height(AppSize.InputHeight)
          .borderRadius(AppRadius.MD)
          .margin({ top: AppSpacing.LG, bottom: AppSpacing.MD })
          .onChange((val: string) => this.oldPass = val)

        TextInput({ placeholder: '请输入新密码', text: this.newPass })
          .type(InputType.Password)
          .width('90%')
          .height(AppSize.InputHeight)
          .borderRadius(AppRadius.MD)
          .margin({ bottom: AppSpacing.MD })
          .onChange((val: string) => this.newPass = val)

        TextInput({ placeholder: '请确认新密码', text: this.confirmPass })
          .type(InputType.Password)
          .width('90%')
          .height(AppSize.InputHeight)
          .borderRadius(AppRadius.MD)
          .margin({ bottom: AppSpacing.XXL })
          .onChange((val: string) => this.confirmPass = val)

        Button('确认修改')
          .width('90%')
          .height(AppSize.ButtonHeight)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.MD)
          .fontSize(AppFontSize.Body)
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
    .backgroundColor(AppColors.Background)
  }
}