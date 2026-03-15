import router from '@ohos.router';

@Entry
@Component
struct SettingsPage {
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
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      // 选项信息
      Column() {
        // 编辑资料
        Row() {
          Text('编辑资料')
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('>')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('90%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 12, topRight: 12 })
        .margin({ top: 20 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/EditProfilePage' })
        })
        
        Divider().color('#F2F6F3').width('85%')

        // 更改密码
        Row() {
          Text('更改密码')
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('>')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('90%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/ChangePasswordPage' })
        })

        // 协议相关
        Row() {
          Text('用户协议')
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('>')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('90%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 12, topRight: 12 })
        .margin({ top: 20 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'user' } })
        })
        
        Divider().color('#F2F6F3').width('85%')

        Row() {
          Text('隐私政策')
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('>')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('90%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius({ bottomLeft: 12, bottomRight: 12 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AgreementPage', params: { type: 'privacy' } })
        })
        
        // 版本信息
        Row() {
          Text('当前版本')
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('1.0.0')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('90%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin({ top: 20 })
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
