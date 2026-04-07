import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import { camera, cameraPicker } from '@kit.CameraKit';
import { HttpService } from '../services/HttpService';
import { AvatarCaptureHelper } from '../common/AvatarCaptureHelper';
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

  private async ensureCameraPermission(): Promise<boolean> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissionList: Array<Permissions> = ['ohos.permission.CAMERA' as Permissions];
      const grantResult = await atManager.requestPermissionsFromUser(context, permissionList);

      let granted = false;
      let i = 0;
      while (i < grantResult.authResults.length) {
        if (grantResult.authResults[i] === 0) {
          granted = true;
          break;
        }
        i++;
      }
      return granted;
    } catch (err) {
      return false;
    }
  }

  private copyUriToSandbox(sourceUri: string): string {
    const context = getContext(this) as common.UIAbilityContext;
    const timestamp = Date.now();
    const destPath = `${context.cacheDir}/avatar_source_${timestamp}.jpg`;

    let srcFile: fs.File | null = null;
    let destFile: fs.File | null = null;
    try {
      srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.copyFileSync(srcFile.fd, destFile.fd);
      return destPath;
    } finally {
      if (srcFile !== null) {
        fs.closeSync(srcFile);
      }
      if (destFile !== null) {
        fs.closeSync(destFile);
      }
    }
  }

  private async pickAvatarFromAlbum(): Promise<string> {
    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new picker.PhotoViewPicker();
      const selected = await photoPicker.select(photoSelectOptions);
      if (!selected || selected.photoUris.length === 0) {
        return '';
      }
      return selected.photoUris[0];
    } catch (err) {
      promptAction.showToast({ message: '打开相册失败' });
      return '';
    }
  }

  private async pickAvatarFromCamera(): Promise<string> {
    try {
      const granted = await this.ensureCameraPermission();
      if (!granted) {
        promptAction.showToast({ message: '未授予相机权限，请在系统设置中允许后重试' });
        return '';
      }

      const context = getContext(this) as common.UIAbilityContext;
      let profile = new cameraPicker.PickerProfile();
      profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
      const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile);
      if (!result || result.resultUri.length === 0) {
        return '';
      }
      return result.resultUri;
    } catch (err) {
      const businessError = err as BusinessError;
      const errorCode: number = businessError.code ?? 0;
      const errorMessage: string = businessError.message ?? '';
      const friendlyMessage = AvatarCaptureHelper.messageForCameraError(errorCode, errorMessage);
      if (friendlyMessage.length > 0) {
        promptAction.showToast({ message: friendlyMessage });
      }
      console.error(`Camera pick failed. Code:${errorCode}, message:${errorMessage}`);
      return '';
    }
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

                let pickedUri: string = '';
                if (menuResult.index === 0) {
                  pickedUri = await this.pickAvatarFromCamera();
                } else {
                  pickedUri = await this.pickAvatarFromAlbum();
                }

                if (pickedUri.length === 0) {
                  return;
                }

                // 复制到应用沙盒，确保裁剪页能正确读取
                let sandboxPath: string = '';
                try {
                  sandboxPath = this.copyUriToSandbox(pickedUri);
                } catch (copyErr) {
                  console.error(`Copy to sandbox failed: ${JSON.stringify(copyErr)}`);
                  promptAction.showToast({ message: '读取图片失败，请重试' });
                  return;
                }

                // Image组件需要 file:// 前缀才能正确读取沙盒文件
                const imageUri = sandboxPath.startsWith('file://') ? sandboxPath : `file://${sandboxPath}`;
                router.pushUrl({
                  url: 'pages/AvatarCropPage',
                  params: {
                    imageUri: imageUri
                  }
                });
              } catch (err) {
                const bizErr = err as BusinessError;
                console.error(`Update avatar failed. Code:${bizErr.code},message:${bizErr.message}`);
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
