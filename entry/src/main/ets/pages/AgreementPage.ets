import router from '@ohos.router';
import { AppColors, AppFontSize, AppSpacing, AppShadow } from '../common/DesignToken';

@Entry
@Component
struct AgreementPage {
  @State title: string = '';
  @State content: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      if (params['type'] === 'user') {
        this.title = '用户协议';
        this.content = '在此处展示用户协议详细文本...\n\n1. 您的权利与义务\n2. 账号管理\n3. 隐私保护\n4. 免责声明...';
      } else if (params['type'] === 'privacy') {
        this.title = '隐私政策';
        this.content = '在此处展示隐私政策详细文本...\n\n1. 信息收集\n2. 信息使用\n3. 信息保护\n4. 用户控制...';
      }
    }
  }

  build() {
    Column() {
      // 头部导航
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24)
          .fillColor(AppColors.TextPrimary)
          .margin({ right: AppSpacing.MD })
          .onClick(() => {
            router.back();
          })
        Text(this.title)
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Text(this.content)
          .fontSize(AppFontSize.H3)
          .fontColor(AppColors.TextPrimary)
          .lineHeight(26)
          .padding(AppSpacing.XL)
          .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Surface)
  }
}
