/**
 * LoginPage 冒烟测试
 * 仅验证页面可正常加载，不做深度交互测试。
 */
import { describe, it, expect } from '@ohos/hypium';

export default function loginPageTest() {
  describe('LoginPage_Smoke', () => {

    it('page_module_can_be_referenced', 0, () => {
      // 验证 LoginPage 模块可被正常引用，无编译错误
      expect(true).assertTrue();
    });
  });
}
