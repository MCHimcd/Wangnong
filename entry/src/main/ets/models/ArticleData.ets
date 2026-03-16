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
