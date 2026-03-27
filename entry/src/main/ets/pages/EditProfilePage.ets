import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';
import { UserProfile } from '../models/UserData';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

@Entry
@Component
struct EditProfilePage {
  @State userName: string = '';
  @State gender: string = '保密';
  @State birthDate: string = '1990-01-01';
  private originalProfile: UserProfile | null = null;

  async aboutToAppear() {
    let profile = await HttpService.getInstance().getUserProfile();
    if (profile) {
      this.originalProfile = profile;
      this.userName = profile.userName;
      this.gender = profile.gender || '保密';
      this.birthDate = profile.birthDate || '1990-01-01';
      AppStorage.setOrCreate('profileUserName', this.userName);
      AppStorage.setOrCreate('profileAvatarSrc', profile.avatarSrc || '');
    }
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
        Text('编辑资料')
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

      // 表单
      Column() {
        Row() {
          Text('姓名')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextPrimary)
          TextInput({ text: this.userName })
            .width('70%')
            .backgroundColor(Color.Transparent)
            .textAlign(TextAlign.End)
            .onChange((value: string) => {
              this.userName = value;
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
        .backgroundColor(AppColors.Surface)
        .borderRadius({ topLeft: AppRadius.MD, topRight: AppRadius.MD })
        .margin({ top: AppSpacing.LG })
        .justifyContent(FlexAlign.SpaceBetween)

        Divider().color(AppColors.Divider).width('90%')

        Row() {
          Text('性别')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextPrimary)
          Row() {
            Text(this.gender)
              .fontSize(AppFontSize.Body)
              .fontColor(AppColors.TextSecondary)
              .margin({ right: AppSpacing.SM })
            Text('›')
              .fontSize(20)
              .fontColor(AppColors.TextTertiary)
          }
          .onClick(() => {
            promptAction.showActionMenu({
               title: '选择性别',
               buttons: [
                 { text: '男', color: AppColors.Primary },
                 { text: '女', color: AppColors.Primary },
                 { text: '保密', color: AppColors.Primary }
               ]
            }).then(data => {
               const options = ['男', '女', '保密'];
               this.gender = options[data.index];
            });
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
        .backgroundColor(AppColors.Surface)
        .justifyContent(FlexAlign.SpaceBetween)

        Divider().color(AppColors.Divider).width('90%')

        Row() {
          Text('出生日期')
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextPrimary)
          Row() {
            Text(this.birthDate)
              .fontSize(AppFontSize.Body)
              .fontColor(AppColors.TextSecondary)
              .margin({ right: AppSpacing.SM })
            Text('›')
              .fontSize(20)
              .fontColor(AppColors.TextTertiary)
          }
          .onClick(() => {
            DatePickerDialog.show({
              start: new Date("1900-1-1"),
              end: new Date(),
              selected: new Date(this.birthDate),
              onAccept: (value: DatePickerResult) => {
                this.birthDate = `${value.year}-${(value.month as number) + 1}-${value.day}`;
              }
            })
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
        .backgroundColor(AppColors.Surface)
        .borderRadius({ bottomLeft: AppRadius.MD, bottomRight: AppRadius.MD })
        .justifyContent(FlexAlign.SpaceBetween)

        Button('保存修改')
          .width('100%')
          .height(AppSize.ButtonHeight)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.MD)
          .fontSize(AppFontSize.Body)
          .margin({ top: 36 })
          .onClick(async () => {
             let newProfile: UserProfile = {
               userId: this.originalProfile ? this.originalProfile.userId : '',
               userName: this.userName,
               gender: this.gender,
               birthDate: this.birthDate,
               avatarSrc: this.originalProfile ? this.originalProfile.avatarSrc : '',
               role: this.originalProfile ? (this.originalProfile.role || 'user') : 'user'
             };
             let success = await HttpService.getInstance().updateUserProfile(newProfile);
             if (success) {
               AppStorage.setOrCreate('profileUserName', this.userName);
               AppStorage.setOrCreate('profileAvatarSrc', newProfile.avatarSrc || '');
               promptAction.showToast({ message: '资料已保存' });
               router.back();
             } else {
               promptAction.showToast({ message: '保存失败' });
             }
          })
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