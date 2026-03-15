import router from '@ohos.router';

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
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })
          .fontColor('#333333')
          .onClick(() => {
            router.back();
          })
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Text(this.content)
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(26)
          .padding(20)
          .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
