import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

/**
 * Purpose: 提供已登录用户的密码修改表单页。
 * Responsibilities: 收集旧密码与两次新密码、做前端一致性校验，并调用 HttpService 提交修改请求。
 * Flow: 用户填写表单后点击确认；页面先校验必填与两次新密码一致，再请求后端并根据结果返回上一页。
 * Dependencies: 依赖 HttpService.changePassword() 和 promptAction 提示反馈。
 * Input: 用户输入的旧密码、新密码和确认密码。
 * Output: 成功时触发密码修改请求并返回；失败时保留当前表单状态。
 * Boundary: 这里只做最小前端校验，密码复杂度规则仍以后端为准。
 */
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
            // Flow: 先做本地校验，再发请求；这样可以避免无效输入直接打到后端。
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