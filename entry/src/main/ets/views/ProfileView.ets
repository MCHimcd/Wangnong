import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

@Component
export struct ProfileView {
  @State avatarSrc: ResourceStr = $r('app.media.startIcon');
  @State userId: string = 'WangNong_001';
  @StorageLink('userRole') userRole: string = 'user';
  @StorageLink('profileUserName') userName: string = '王农';
  @StorageLink('profileAvatarSrc') profileAvatarSrc: string = '';

  private getCurrentAvatar(): ResourceStr {
    if (this.profileAvatarSrc && this.profileAvatarSrc.length > 0) {
      return this.profileAvatarSrc;
    }
    return this.avatarSrc;
  }

  private async refreshProfile() {
    let profile = await HttpService.getInstance().getUserProfile();
    if (profile) {
      if (profile.userId) this.userId = profile.userId;
      if (profile.userName) this.userName = profile.userName;
      this.userRole = profile.role || 'user';
      AppStorage.setOrCreate('userRole', this.userRole);
      this.profileAvatarSrc = profile.avatarSrc || '';
      AppStorage.setOrCreate('profileUserName', this.userName);
      AppStorage.setOrCreate('profileAvatarSrc', this.profileAvatarSrc);
    }
  }

  async aboutToAppear() {
    await this.refreshProfile();
  }

  @Builder
  MenuItem(icon: string, label: string, isDanger: boolean = false) {
    Row() {
      Text(icon)
        .fontSize(AppFontSize.H3)
        .margin({ right: AppSpacing.MD })
      Text(label)
        .fontSize(AppFontSize.Body)
        .fontColor(isDanger ? AppColors.AlertCritical : AppColors.TextPrimary)
        .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(isDanger ? AppColors.AlertCritical : AppColors.TextTertiary)
    }
    .width('100%')
    .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.MD, bottom: AppSpacing.MD })
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.MD)
  }

  build() {
    Scroll() {
      Column() {
        // 顶部横幅区域（渐变）
        Stack({ alignContent: Alignment.Center }) {
          Column() {}
            .width('100%')
            .height('100%')
            .linearGradient({
              angle: 135,
              colors: [[AppColors.GradientBannerStart, 0], [AppColors.GradientBannerEnd, 1]]
            })

          Column() {
            // 头像
            Stack() {
              Row() {}
                .width(108)
                .height(108)
                .borderRadius(54)
                .border({ width: 3, color: 'rgba(255,255,255,0.5)' })

              Image(this.getCurrentAvatar())
                .width(100)
                .height(100)
                .borderRadius(50)
                .backgroundColor(AppColors.Divider)
            }
            .margin({ bottom: AppSpacing.MD })
            .onClick(async () => {
              try {
                let menuResult = await promptAction.showActionMenu({
                  title: '修改头像',
                  buttons: [
                    { text: '拍照', color: AppColors.Primary },
                    { text: '从相册选择', color: AppColors.Primary }
                  ]
                });

                if (menuResult.index < 0) {
                  return;
                }

                let profile = await HttpService.getInstance().useFixedAvatar();
                if (!profile) {
                  promptAction.showToast({ message: '头像更新失败，请检查后端连接' });
                  return;
                }

                this.profileAvatarSrc = profile.avatarSrc || '';
                if (profile.userName) {
                  this.userName = profile.userName;
                }
                AppStorage.setOrCreate('profileAvatarSrc', this.profileAvatarSrc);
                AppStorage.setOrCreate('profileUserName', this.userName);
                promptAction.showToast({ message: '头像已更新' });
              } catch (err) {
                console.error(`Update avatar failed. Code:${err.code},message:${err.message}`);
                promptAction.showToast({ message: '头像更新失败' });
              }
            })

            Text(this.userName)
              .fontSize(AppFontSize.H1)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TextOnPrimary)

            Text(`ID: ${this.userId}`)
              .fontSize(AppFontSize.Caption)
              .fontColor('rgba(255,255,255,0.75)')
              .margin({ top: AppSpacing.XS })

            Row() {
              Text(this.userRole === 'admin' ? '🔑 管理员' : '🌱 普通用户')
                .fontSize(AppFontSize.Caption)
                .fontColor(AppColors.TextOnPrimary)
                .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
                .backgroundColor('rgba(255,255,255,0.2)')
                .borderRadius(AppRadius.Full)
            }.margin({ top: AppSpacing.SM })
          }
        }
        .width('100%')
        .height(260)

        // 菜单列表
        Column({ space: AppSpacing.SM }) {
          this.MenuItem('📦', '溯源码：扫码展示作物信息')
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.LG })
        .onClick(() => {
          router.pushUrl({ url: 'pages/TraceabilityScanPage' });
        })

        if (this.userRole === 'admin') {
          Column({ space: AppSpacing.SM }) {
            this.MenuItem('🖥️', '管理后台')
          }
          .width('100%')
          .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM })
          .onClick(() => {
            router.pushUrl({ url: 'pages/AdminPage' });
          })
        }

        Column({ space: AppSpacing.SM }) {
          this.MenuItem('⚙️', '设置')
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM })
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
        })

        Column({ space: AppSpacing.SM }) {
          this.MenuItem('🔄', '切换账号')
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM })
        .onClick(() => {
          router.replaceUrl({ url: 'pages/LoginPage' });
        })

        Column({ space: AppSpacing.SM }) {
          this.MenuItem('🚪', '退出登录', true)
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.SM, bottom: AppSpacing.XXL })
        .onClick(async () => {
          try {
            const remoteLogoutOk = await HttpService.getInstance().logout();
            let context = getContext(this) as common.UIAbilityContext;
            let pref = await preferences.getPreferences(context, 'AppPreferences');
            await pref.put('autoLogin', false);
            await pref.flush();
            AppStorage.setOrCreate('isLoggedIn', false);
            AppStorage.setOrCreate('profileUserName', '');
            AppStorage.setOrCreate('profileAvatarSrc', '');
            HttpService.getInstance().setToken('');
            if (!remoteLogoutOk) {
              promptAction.showToast({ message: '服务器退出失败，已本地退出' });
            }
            router.replaceUrl({ url: 'pages/LoginPage' });
          } catch (err) {
            console.error(`Logout failed. Code:${err.code},message:${err.message}`);
            promptAction.showToast({ message: '退出失败' });
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
    .scrollBar(BarState.Off)
  }
}
