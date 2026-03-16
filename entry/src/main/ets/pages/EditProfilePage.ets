import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';
import { UserProfile } from '../models/UserData';

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
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })
          .fontColor('#333333')
          .onClick(() => {
            router.back();
          })
        Text('编辑资料')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      // 表单
      Column() {
        Row() {
          Text('姓名')
            .fontSize(16)
            .fontColor('#333333')
          TextInput({ text: this.userName })
            .width('70%')
            .backgroundColor(Color.Transparent)
            .textAlign(TextAlign.End)
            .onChange((value: string) => {
              this.userName = value;
            })
        }
        .width('90%')
        .height(60)
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 12, topRight: 12 })
        .margin({ top: 20 })
        .justifyContent(FlexAlign.SpaceBetween)

        Divider().color('#F2F6F3').width('85%')

        Row() {
          Text('性别')
            .fontSize(16)
            .fontColor('#333333')
          Row() {
            Text(this.gender)
              .fontSize(16)
              .fontColor('#666666')
              .margin({ right: 8 })
            Text('>')
              .fontSize(16)
              .fontColor('#999999')
          }
          .onClick(() => {
            promptAction.showActionMenu({
               title: '选择性别',
               buttons: [
                 { text: '男', color: '#4CAF50' },
                 { text: '女', color: '#4CAF50' },
                 { text: '保密', color: '#4CAF50' }
               ]
            }).then(data => {
               const options = ['男', '女', '保密'];
               this.gender = options[data.index];
            });
          })
        }
        .width('90%')
        .height(60)
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.White)
        .justifyContent(FlexAlign.SpaceBetween)

        Divider().color('#F2F6F3').width('85%')

        Row() {
          Text('出生日期')
            .fontSize(16)
            .fontColor('#333333')
          Row() {
            Text(this.birthDate)
              .fontSize(16)
              .fontColor('#666666')
              .margin({ right: 8 })
            Text('>')
              .fontSize(16)
              .fontColor('#999999')
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
        .width('90%')
        .height(60)
        .padding({ left: 20, right: 20 })
        .backgroundColor(Color.White)
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
        .justifyContent(FlexAlign.SpaceBetween)

        Button('保存修改')
          .width('90%')
          .height(50)
          .backgroundColor('#4CAF50')
          .margin({ top: 40 })
          .onClick(async () => {
             let newProfile: UserProfile = {
               userId: this.originalProfile ? this.originalProfile.userId : '',
               userName: this.userName,
               gender: this.gender,
               birthDate: this.birthDate,
               avatarSrc: this.originalProfile ? this.originalProfile.avatarSrc : ''
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
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}