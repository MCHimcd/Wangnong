import { MOCK_ARTICLES, ArticleData } from '../models/ArticleData';
import router from '@ohos.router';

@Component
export struct KnowledgeView {
  build() {
    Column() {
      List({ space: 16 }) {
        ForEach(MOCK_ARTICLES, (item: ArticleData) => {
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
