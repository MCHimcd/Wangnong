import picker from '@ohos.file.picker';
import promptAction from '@ohos.promptAction';
import { HttpService } from '../services/HttpService';

interface DetectionResult {
  name: string;
  confidence: string;
  color: string;
}

@Component
export struct PestDetectionView {
  @State selectedImageUri: string = '';
  @State isAnalyzing: boolean = false;
  @State hasResult: boolean = false;
  @State detectionResults: DetectionResult[] = [];

  showPickerMenu() {
    promptAction.showActionMenu({
      title: '选择图片来源',
      buttons: [
        { text: '📸 拍照', color: '#2C3E50' },
        { text: '🖼️ 从相册选择', color: '#2C3E50' }
      ]
    }).then(data => {
      if (data.index === 0) {
        // 拍照占位
        promptAction.showToast({ message: '拍照功能已点击（暂用弹窗占位，待对接系统相机）', duration: 2500 });
      } else if (data.index === 1) {
        this.selectFromGallery();
      }
    }).catch((err: Error) => {
      console.error('Menu cancelled', err);
    });
  }

  async selectFromGallery() {
    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new picker.PhotoViewPicker();
      photoPicker.select(photoSelectOptions).then(result => {
        if (result && result.photoUris && result.photoUris.length > 0) {
          this.selectedImageUri = result.photoUris[0];
          this.hasResult = false;
          this.isAnalyzing = false;
        }
      });
    } catch (err) {
      console.error('PhotoPicker failed', err);
      promptAction.showToast({ message: '打开相册失败' });
    }
  }

  async startDetection() {
    if (!this.selectedImageUri) {
      promptAction.showToast({ message: '请先选择要检测的图片' });
      return;
    }
    
    this.isAnalyzing = true;
    this.hasResult = false;
    this.detectionResults = [];

    // 网络请求
    let res = await HttpService.getInstance().analyzePest(this.selectedImageUri);

    this.isAnalyzing = false;
    if (res && res.data) {
      this.hasResult = true;
      this.detectionResults = [
        { name: res.data['pestName'] as string, confidence: res.data['confidence'] as string, color: res.data['color'] as string }
      ];
    } else {
      this.hasResult = false;
      this.detectionResults = [];
      promptAction.showToast({ message: '检测失败，请检查后端连接' });
    }
  }

  build() {
    Scroll() {
      Column() {
        Text('病虫害检测')
          .fontSize(28)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#2C3E50')
          .margin({ top: 30, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)
          
        Text('上传农作物病害部位的照片，即可智能识别病虫害种类并提供防治建议。')
          .fontSize(14)
          .fontColor('#78909C')
          .width('90%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 24 })

        // 大图预览区（点击上传）
        Stack({ alignContent: Alignment.Center }) {
          if (this.selectedImageUri) {
            Image(this.selectedImageUri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Cover)
              .borderRadius(16)
          } else {
            Column() {
              Text('➕')
                .fontSize(40)
                .fontColor('#90A4AE')
                .margin({ bottom: 12 })
              Text('点击此处拍照或选择图片')
                .fontSize(16)
                .fontColor('#90A4AE')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#FAFAFA')
            .borderRadius(16)
            .border({ width: 2, color: '#CFD8DC', style: BorderStyle.Dashed })
          }
        }
        .width('90%')
        .height(260)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetY: 4 })
        .onClick(() => {
          if (!this.isAnalyzing) {
            this.showPickerMenu();
          }
        })

        // 确认上传按钮
        Button(this.isAnalyzing ? '正在智能分析...' : '确认上传并检测')
          .width('90%')
          .height(50)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(this.selectedImageUri ? (this.isAnalyzing ? '#81C784' : '#4CAF50') : '#B0BEC5')
          .margin({ top: 30, bottom: 30 })
          .enabled(!this.isAnalyzing && this.selectedImageUri !== '')
          .onClick(() => {
            this.startDetection();
          })

        if (this.isAnalyzing) {
          Column() {
            LoadingProgress()
              .width(60)
              .height(60)
              .color('#4CAF50')
              .margin({ bottom: 10 })
            Text('AI 正在全速识别中，请稍候...')
              .fontSize(14)
              .fontColor('#78909C')
          }
          .margin({ top: 20 })
          .animation({ duration: 300 })
        }

        if (this.hasResult && !this.isAnalyzing) {
          Column() {
            Text('检测结果')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2C3E50')
              .width('90%')
              .margin({ bottom: 16 })

            ForEach(this.detectionResults, (item: DetectionResult, index: number) => {
              Row() {
                // 占位色块，模拟病害示例图片
                Stack() {
                  Text('示例')
                    .fontSize(10)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                }
                .width(60)
                .height(60)
                .backgroundColor(item.color)
                .borderRadius(8)
                .margin({ right: 15 })

                Column() {
                  Text(item.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#2C3E50')
                    .margin({ bottom: 6 })
                  Text(`置信度: ${item.confidence}`)
                    .fontSize(14)
                    .fontColor(index === 0 ? '#E53935' : '#78909C') // 第一条置信度最高，标红提示
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('90%')
              .padding(15)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
              .shadow({ radius: 5, color: 'rgba(0,0,0,0.04)', offsetY: 2 })
            })
          }
          .width('100%')
          .animation({ duration: 400, curve: Curve.EaseOut })
        }
      }
      .width('100%')
      .padding({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
    .scrollBar(BarState.Off)
  }
}
