import { promptAction } from '@kit.ArkUI';
import picker from '@ohos.file.picker';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';
import { MarkdownParser, MarkdownBlock, MarkdownSegment } from '../common/MarkdownParser';

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
        if (msg.role === 'user') {
          Text(msg.content)
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextOnPrimary)
            .lineHeight(22)
        } else {
          this.MarkdownContent(msg.content)
        }
      }
    }
    .padding(AppSpacing.MD)
    .backgroundColor(msg.role === 'user' ? AppColors.Primary : AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
    .constraintSize({ maxWidth: '75%' })
  }

  @Builder
  MarkdownContent(content: string) {
    Column({ space: 4 }) {
      ForEach(MarkdownParser.parse(content), (block: MarkdownBlock, idx: number) => {
        if (block.type === 'heading') {
          this.HeadingBlock(block)
        } else if (block.type === 'listItem') {
          this.ListItemBlock(block)
        } else if (block.type === 'orderedListItem') {
          this.OrderedListItemBlock(block)
        } else if (block.type === 'codeBlock') {
          this.CodeBlock(block)
        } else if (block.type === 'blockquote') {
          this.BlockquoteBlock(block)
        } else {
          this.ParagraphBlock(block)
        }
      }, (_block: MarkdownBlock, idx: number) => `md_${idx}`)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HeadingBlock(block: MarkdownBlock) {
    Row() {
      ForEach(block.segments, (seg: MarkdownSegment, idx: number) => {
        Text(seg.content)
          .fontSize(block.level === 1 ? AppFontSize.H1 :
            block.level === 2 ? AppFontSize.H2 : AppFontSize.H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
      }, (_seg: MarkdownSegment, idx: number) => `hs_${idx}`)
    }
    .margin({ top: AppSpacing.SM, bottom: AppSpacing.XS })
  }

  @Builder
  ListItemBlock(block: MarkdownBlock) {
    Row() {
      Text('•')
        .fontSize(AppFontSize.Body)
        .fontColor(AppColors.Primary)
        .margin({ right: AppSpacing.SM })
      this.InlineSegments(block.segments)
    }
    .margin({ left: AppSpacing.MD })
  }

  @Builder
  OrderedListItemBlock(block: MarkdownBlock) {
    Row() {
      this.InlineSegments(block.segments)
    }
    .margin({ left: AppSpacing.MD })
  }

  @Builder
  CodeBlock(block: MarkdownBlock) {
    Column() {
      if (block.language.length > 0) {
        Text(block.language)
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextTertiary)
          .margin({ bottom: AppSpacing.XS })
      }
      Scroll() {
        Text(block.content)
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextPrimary)
          .fontFamily('monospace')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding(AppSpacing.MD)
    .backgroundColor(AppColors.Divider)
    .borderRadius(AppRadius.SM)
    .margin({ top: AppSpacing.XS, bottom: AppSpacing.XS })
  }

  @Builder
  BlockquoteBlock(block: MarkdownBlock) {
    Row() {
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(AppColors.Primary)
        .borderRadius(2)
        .margin({ right: AppSpacing.SM })
      Column() {
        this.InlineSegments(block.segments)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS, right: AppSpacing.SM })
    .backgroundColor(AppColors.PrimaryBg)
    .borderRadius(AppRadius.SM)
  }

  @Builder
  ParagraphBlock(block: MarkdownBlock) {
    Row() {
      this.InlineSegments(block.segments)
    }
  }

  @Builder
  InlineSegments(segments: MarkdownSegment[]) {
    Text() {
      ForEach(segments, (seg: MarkdownSegment, idx: number) => {
        if (seg.type === 'bold') {
          Span(seg.content)
            .fontSize(AppFontSize.Body)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
        } else if (seg.type === 'italic') {
          Span(seg.content)
            .fontSize(AppFontSize.Body)
            .fontStyle(FontStyle.Italic)
            .fontColor(AppColors.TextPrimary)
        } else if (seg.type === 'boldItalic') {
          Span(seg.content)
            .fontSize(AppFontSize.Body)
            .fontWeight(FontWeight.Bold)
            .fontStyle(FontStyle.Italic)
            .fontColor(AppColors.TextPrimary)
        } else if (seg.type === 'code') {
          Span(` ${seg.content} `)
            .fontSize(AppFontSize.Caption)
            .fontFamily('monospace')
            .fontColor(AppColors.TextPrimary)
        } else {
          Span(seg.content)
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextPrimary)
        }
      }, (_seg: MarkdownSegment, idx: number) => `seg_${idx}`)
    }
    .lineHeight(22)
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
                LoadingProgress().width(20).height(20).color(AppColors.Primary).margin({ right: AppSpacing.SM })
                Text('思考中...').fontSize(AppFontSize.Body).fontColor(AppColors.TextTertiary)
              }
              .padding(AppSpacing.MD)
              .backgroundColor(AppColors.Surface)
              .borderRadius(AppRadius.LG)
              .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
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
            .fontColor(AppColors.AlertCritical)
            .margin({ left: AppSpacing.SM })
            .onClick(() => {
              this.selectedImageUri = '';
            })
          Blank()
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: 6, bottom: 6 })
        .backgroundColor(AppColors.Divider)
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
          .borderRadius(AppRadius.Full)
          .backgroundColor(AppColors.Divider)
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            void this.sendMessage();
          })

        Button('发送')
          .height(38)
          .fontSize(AppFontSize.Body)
          .borderRadius(AppRadius.MD)
          .backgroundColor(AppColors.Primary)
          .margin({ left: AppSpacing.SM })
          .enabled(!this.isSending)
          .onClick(() => {
            void this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.SM, bottom: AppSpacing.SM })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.CardColor, offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
}
