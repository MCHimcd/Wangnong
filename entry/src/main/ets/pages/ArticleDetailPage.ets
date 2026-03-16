import router from '@ohos.router';
import { ArticleData } from '../models/ArticleData';
import { HttpService } from '../services/HttpService';

@Entry
@Component
struct ArticleDetailPage {
  @State article: ArticleData | null = null;

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['articleId']) {
      const id = params['articleId'] as string;
      const res = await HttpService.getInstance().getArticleDetail(id);
      if (res && res.data) {
        let articleData = res.data as ArticleData;
        this.article = new ArticleData(
          articleData.id,
          articleData.title,
          articleData.date,
          articleData.thumbnail ? articleData.thumbnail : $r('app.media.layered_image'),
          articleData.content,
          articleData.images || []
        );
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
        Text('科普详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .alignItems(VerticalAlign.Center)

      // 文章内容
      if (this.article) {
        Scroll() {
          Column() {
            Text(this.article.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 16, bottom: 16 })
              .width('100%')
              .textAlign(TextAlign.Start)
            
            Text(this.article.date)
              .fontSize(14)
              .fontColor('#999999')
              .margin({ bottom: 24 })
              .width('100%')
              .textAlign(TextAlign.Start)

            Text(this.article.content)
              .fontSize(16)
              .fontColor('#333333')
              .lineHeight(26)
              .margin({ bottom: 16 })
              .width('100%')
              .textAlign(TextAlign.Start)

            ForEach(this.article.images, (img: ResourceStr, index: number) => {
              Row()
                .width('100%')
                .height(200)
                .backgroundColor('#EBEBEB')
                .borderRadius(8)
                .margin({ bottom: 16 })
            }, (img: ResourceStr, index: number) => index.toString())
          }
          .padding(16)
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.TopStart)
      } else {
        Text('文章不存在或已被删除')
          .fontSize(16)
          .fontColor('#999999')
          .margin({ top: 50 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
  }
}
