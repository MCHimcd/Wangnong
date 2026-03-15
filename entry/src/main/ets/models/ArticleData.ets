export class ArticleData {
  id: string;
  title: string;
  date: string;
  thumbnail: ResourceStr;
  content: string;
  images: ResourceStr[];

  constructor(id: string, title: string, date: string, thumbnail: ResourceStr, content: string, images: ResourceStr[]) {
    this.id = id;
    this.title = title;
    this.date = date;
    this.thumbnail = thumbnail;
    this.content = content;
    this.images = images;
  }
}

export const MOCK_ARTICLES: ArticleData[] = [
  new ArticleData('1', '云端种梦智能温室系统介绍', '2024-04-10 15:48:31', $r('app.media.layered_image'), '云端种梦智能温室系统是一款融合了物联网、人工智能和大数据技术的现代农业解决方案。文章详情正文内容测试占位。', [$r('app.media.layered_image')]),
  new ArticleData('2', 'AI智能监控：农业发展的新篇章', '2024-04-05 16:37:26', $r('app.media.layered_image'), '随着科技的飞速发展，人工智能(AI)技术已经渗透到各行各业，农业也不例外。文章详情正文内容测试占位。', [$r('app.media.layered_image')]),
  new ArticleData('3', '智能温室：现代农业的绿色革命', '2024-04-05 16:37:36', $r('app.media.layered_image'), '智能温室正逐渐成为现代农业的重要组成部分，它通过精准的环境控制，实现了作物的全天候生长。文章详情正文内容测试占位。', [$r('app.media.layered_image')]),
  new ArticleData('4', '传感器：农业科技的“感知先锋”', '2024-04-05 16:37:46', $r('app.media.layered_image'), '传感器在现代农业中扮演着至关重要的角色，就像是农业系统的“眼睛”和“耳朵”。文章详情正文内容测试占位。', [$r('app.media.layered_image')])
];
