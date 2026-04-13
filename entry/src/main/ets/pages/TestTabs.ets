import { promptAction } from '@kit.ArkUI';

/**
 * Purpose: 保留最小化的 Tabs 原型页，用于早期 UI 结构验证。
 * Responsibilities: 提供一个可编译的 Tabs 基础示例，方便局部实验。
 * Flow: 页面加载后直接渲染单个 TabContent，不承载真实业务状态。
 * Output: 最简 Tabs 结构。
 * Boundary: 这是测试/原型页面，不应承载正式导航逻辑。
 */
@Entry
@Component
struct TestTabs {
  build() {
    Tabs() {
      TabContent().tabBar(SubTabBarStyle.of('监控'))
    }
  }
}
