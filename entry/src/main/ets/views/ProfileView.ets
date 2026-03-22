import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HttpService } from '../services/HttpService';

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
          Image(this.getCurrentAvatar())
            .width(100)
            .height(100)
            .borderRadius(50)
            .backgroundColor('#E0E0E0')
            .margin({ top: 20, bottom: 10 })
            .onClick(async () => {
              try {
                let menuResult = await promptAction.showActionMenu({
                  title: '修改头像',
                  buttons: [
                    { text: '拍照', color: '#4CAF50' },
                    { text: '从相册选择', color: '#4CAF50' }
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
          
          Text(`名称: ${this.userName}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ top: 10 })

          Text(`ID: ${this.userId}`)
            .fontSize(16)
            .fontColor('#78909c')
            .margin({ bottom: 20 })

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
            router.pushUrl({ url: 'pages/TraceabilityScanPage' });
          })

          if (this.userRole === 'admin') {
            Row() {
              Text('管理后台')
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
              router.pushUrl({ url: 'pages/AdminPage' });
            })
          }

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
