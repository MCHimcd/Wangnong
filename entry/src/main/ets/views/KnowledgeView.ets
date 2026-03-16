import { ArticleData } from '../models/ArticleData';
import router from '@ohos.router';
import { HttpService } from '../services/HttpService';

@Component
export struct KnowledgeView {
  @State articles: ArticleData[] = [];

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    let res = await HttpService.getInstance().getArticles(1, 10);
    if (res && res.data && res.data['items']) {
      let items = res.data['items'] as Record<string, string>[];
      this.articles = items.map(item => new ArticleData(
        item['id'] as string,
        item['title'] as string,
        item['date'] as string,
        item['thumbnail'] || $r('app.media.layered_image'),
        item['content'] as string || '',
        []
      ));
    } else {
      this.articles = [];
    }
  }

  build() {
    Column() {
      List({ space: 16 }) {
        ForEach(this.articles, (item: ArticleData) => {
          ListItem() {
            Row() {
              // 标题与日期
              Column() {
                Text(item.title)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ bottom: 16 })
                  .width('100%')
                  .fontColor('#333333')

                Text(item.date)
                  .fontSize(12)
                  .fontColor('#999999')
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ right: 12 })
              .height(80)

              // 缩略图
              Row()
                .width(100)
                .height(80)
                .backgroundColor('#EBEBEB')
                .borderRadius(8)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ArticleDetailPage',
                params: {
                  articleId: item.id
                }
              });
            })
          }
        }, (item: ArticleData) => item.id)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }
}
