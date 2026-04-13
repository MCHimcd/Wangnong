import router from '@ohos.router';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

/**
 * Purpose: 提供个人设置入口页，集中承载资料编辑、密码修改和协议查看导航。
 * Responsibilities: 组织设置菜单行、版本信息卡片和返回导航，不直接处理业务保存逻辑。
 * Flow: 用户从 ProfileView 进入后，通过各设置行跳转到对应页面；协议页通过 params 区分文档类型。
 * Dependencies: 依赖 router 进行页面跳转，依赖 DesignToken 构建统一列表样式。
 * Input: 无外部参数。
 * Output: 设置入口列表和版本展示。
 */
@Entry
@Component
struct SettingsPage {

  // Purpose: 复用统一的设置行视觉结构，把真正的点击跳转放在调用方容器上处理。
  @Builder SettingsRow(icon: string, label: string) {
    Row() {
      Text(icon)
        .fontSize(AppFontSize.H3)
        .margin({ right: AppSpacing.MD })
      Text(label)
        .fontSize(AppFontSize.Body)
        .fontColor(AppColors.TextPrimary)
        .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.TextTertiary)
    }
    .width('100%')
    .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.MD, bottom: AppSpacing.MD })
  }

  build() {
    Column() {
      // 头部导航
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24).height(24)
          .margin({ right: AppSpacing.MD })
          .fillColor(AppColors.TextPrimary)
          .onClick(() => { router.back(); })
        Text('设置')
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
        Column() {
          this.SettingsRow('✏️', '编辑资料')
        }
        .backgroundColor(AppColors.Surface)
        .borderRadius({ topLeft: AppRadius.MD, topRight: AppRadius.MD })
        .margin({ top: AppSpacing.LG })
        .onClick(() => { router.pushUrl({ url: 'pages/EditProfilePage' }) })

        Divider().color(AppColors.Divider).width('90%')

        Column() {
          this.SettingsRow('🔒', '更改密码')
        }
        .backgroundColor(AppColors.Surface)
        .borderRadius({ bottomLeft: AppRadius.MD, bottomRight: AppRadius.MD })
        .onClick(() => { router.pushUrl({ url: 'pages/ChangePasswordPage' }) })

        Column() {
          this.SettingsRow('📄', '用户协议')
        }
        .backgroundColor(AppColors.Surface)
        .borderRadius({ topLeft: AppRadius.MD, topRight: AppRadius.MD })
        .margin({ top: AppSpacing.LG })
        .onClick(() => { router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'user' } }) })

        Divider().color(AppColors.Divider).width('90%')

        Column() {
          this.SettingsRow('🔐', '隐私政策')
        }
        .backgroundColor(AppColors.Surface)
        .borderRadius({ bottomLeft: AppRadius.MD, bottomRight: AppRadius.MD })
        .onClick(() => { router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'privacy' } }) })

        Row() {
          Text('ℹ️')
            .fontSize(AppFontSize.H3)
            .margin({ right: AppSpacing.MD })
          Text('当前版本')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextPrimary)
            .layoutWeight(1)
          Text('1.0.0')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextTertiary)
        }
        .width('100%')
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.MD, bottom: AppSpacing.MD })
        .backgroundColor(AppColors.Surface)
        .borderRadius(AppRadius.MD)
        .margin({ top: AppSpacing.LG })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
}
