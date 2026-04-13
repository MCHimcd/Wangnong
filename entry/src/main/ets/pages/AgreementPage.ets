import router from '@ohos.router';
import { AppColors, AppFontSize, AppSpacing, AppShadow } from '../common/DesignToken';

/**
 * Purpose: 承载用户协议与隐私政策的通用展示页。
 * Responsibilities: 根据路由参数切换标题与正文，并提供统一的返回导航壳。
 * Flow: SettingsPage 传入 type 参数后进入本页；aboutToAppear() 根据 type 选择要展示的文本。
 * Dependencies: 依赖 router 获取页面参数，依赖 DesignToken 保持文档页视觉一致。
 * Input: router params.type，当前支持 user 和 privacy 两种值。
 * Output: 文档标题与正文被渲染到滚动区域。
 * Boundary: 该页当前展示的是占位协议文本，真实法务内容应在同一入口下替换。
 */
@Entry
@Component
struct AgreementPage {
  @State title: string = '';
  @State content: string = '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    // Boundary: type 决定展示哪份协议；未知值保持空内容，避免误展示默认文案。
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
