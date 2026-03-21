import { promptAction } from '@kit.ArkUI';
import picker from '@ohos.file.picker';
import { HttpService } from '../services/HttpService';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  imageUri: string;
  timestamp: number;
}

@Component
export struct AgriQAView {
  @State messages: ChatMessage[] = [];
  @State inputText: string = '';
  @State selectedImageUri: string = '';
  @State isSending: boolean = false;
  private scroller: Scroller = new Scroller();

  private async sendMessage(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0 && this.selectedImageUri.length === 0) {
      promptAction.showToast({ message: '请输入问题或选择图片' });
      return;
    }

    const userMsg: ChatMessage = {
      role: 'user',
      content: text,
      imageUri: this.selectedImageUri,
      timestamp: Date.now()
    };
    this.messages = [...this.messages, userMsg];
    this.inputText = '';
    this.selectedImageUri = '';
    this.scrollToBottom();

    this.isSending = true;
    try {
      const reply = await HttpService.getInstance().sendAgriQA(text, userMsg.imageUri.length > 0 ? userMsg.imageUri : undefined);
      const assistantMsg: ChatMessage = {
        role: 'assistant',
        content: reply ?? '抱歉，服务暂时不可用，请稍后重试。',
        imageUri: '',
        timestamp: Date.now()
      };
      this.messages = [...this.messages, assistantMsg];
    } catch (e) {
      const errMsg: ChatMessage = {
        role: 'assistant',
        content: '网络异常，请检查后端连接后重试。',
        imageUri: '',
        timestamp: Date.now()
      };
      this.messages = [...this.messages, errMsg];
    } finally {
      this.isSending = false;
      this.scrollToBottom();
    }
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  private selectImage(): void {
    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new picker.PhotoViewPicker();
      photoPicker.select(photoSelectOptions).then(result => {
        if (result && result.photoUris && result.photoUris.length > 0) {
          this.selectedImageUri = result.photoUris[0];
        }
      });
    } catch (err) {
      promptAction.showToast({ message: '打开相册失败' });
    }
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    Column() {
      if (msg.imageUri.length > 0) {
        Image(msg.imageUri)
          .width(180)
          .height(120)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .margin({ bottom: 6 })
      }
      if (msg.content.length > 0) {
        Text(msg.content)
          .fontSize(15)
          .fontColor(msg.role === 'user' ? '#FFFFFF' : '#2C3E50')
          .lineHeight(22)
      }
    }
    .padding(12)
    .backgroundColor(msg.role === 'user' ? '#4CAF50' : '#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
    .constraintSize({ maxWidth: '75%' })
  }

  build() {
    Column() {
      // 消息列表
      List({ scroller: this.scroller, space: 12 }) {
        ForEach(this.messages, (msg: ChatMessage) => {
          ListItem() {
            Row() {
              if (msg.role === 'assistant') {
                this.MessageBubble(msg)
                Blank()
              } else {
                Blank()
                this.MessageBubble(msg)
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
          }
        }, (msg: ChatMessage, idx: number) => `${msg.timestamp}_${idx}`)

        // 加载中指示
        if (this.isSending) {
          ListItem() {
            Row() {
              Row() {
                LoadingProgress().width(20).height(20).color('#4CAF50').margin({ right: 8 })
                Text('思考中...').fontSize(14).fontColor('#78909C')
              }
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({ radius: 4, color: 'rgba(0,0,0,0.06)', offsetY: 2 })
              Blank()
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 图片预览
      if (this.selectedImageUri.length > 0) {
        Row() {
          Image(this.selectedImageUri)
            .width(60)
            .height(60)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
          Text('✕')
            .fontSize(18)
            .fontColor('#F44336')
            .margin({ left: 8 })
            .onClick(() => {
              this.selectedImageUri = '';
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .backgroundColor('#F5F5F5')
      }

      // 底部输入栏
      Row() {
        Text('🖼')
          .fontSize(24)
          .margin({ right: 8 })
          .onClick(() => {
            this.selectImage();
          })

        TextInput({ placeholder: '请输入农业问题...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor('#F5F5F5')
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            void this.sendMessage();
          })

        Button('发送')
          .height(38)
          .fontSize(15)
          .backgroundColor('#4CAF50')
          .margin({ left: 8 })
          .enabled(!this.isSending)
          .onClick(() => {
            void this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.06)', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
