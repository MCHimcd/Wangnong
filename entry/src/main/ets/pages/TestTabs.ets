import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct TestTabs {
  build() {
    Tabs() {
      TabContent().tabBar(SubTabBarStyle.of('监控'))
    }
  }
}
