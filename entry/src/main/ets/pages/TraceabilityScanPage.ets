import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService } from '../services/HttpService';

@Entry
@Component
struct TraceabilityScanPage {
  @State scanText: string = '';
  @State resultText: string = '';
  @State isSubmitting: boolean = false;

  aboutToAppear() {
    this.generateMockScanCode();
  }

  private generateMockScanCode() {
    this.scanText = `TRACE_${new Date().getTime()}`;
  }

  private async submitScanResult() {
    if (!this.scanText || this.scanText.trim().length === 0) {
      promptAction.showToast({ message: '请先扫描或输入二维码内容' });
      return;
    }
    if (this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    let result = await HttpService.getInstance().uploadTraceCode(this.scanText.trim());
    this.isSubmitting = false;

    if (!result) {
      promptAction.showToast({ message: '上传失败，请检查后端连接' });
      return;
    }

    this.resultText = result;
    promptAction.showToast({ message: '上传成功' });
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })
          .fontColor('#333333')
          .onClick(() => {
            router.back();
          })
        Text('溯源码扫码')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Row() {}
              .width('90%')
              .height(240)
              .borderRadius(16)
              .backgroundColor('#0F172A')

            Column() {
              Text('扫码测试界面')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#E2E8F0')
              Text('当前为模拟扫码，可手动编辑内容后上传后端')
                .fontSize(13)
                .fontColor('#94A3B8')
                .margin({ top: 10 })
            }
          }
          .width('100%')
          .margin({ top: 20 })

          TextInput({ placeholder: '扫描结果（测试可手动输入）', text: this.scanText })
            .width('90%')
            .height(50)
            .margin({ top: 18 })
            .onChange((value: string) => {
              this.scanText = value;
            })

          Row() {
            Button('模拟重新扫码')
              .width('44%')
              .height(46)
              .backgroundColor('#334155')
              .onClick(() => {
                this.generateMockScanCode();
                promptAction.showToast({ message: '已生成新的测试二维码内容' });
              })

            Button(this.isSubmitting ? '上传中...' : '上传后端')
              .width('44%')
              .height(46)
              .backgroundColor('#4CAF50')
              .enabled(!this.isSubmitting)
              .onClick(() => {
                this.submitScanResult();
              })
          }
          .width('90%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 14 })

          if (this.resultText.length > 0) {
            Column() {
              Text('作物信息返回（后端）')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1E293B')
                .width('100%')

              Text(this.resultText)
                .fontSize(15)
                .fontColor('#334155')
                .lineHeight(24)
                .margin({ top: 10 })
                .width('100%')
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ top: 18, bottom: 24 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
