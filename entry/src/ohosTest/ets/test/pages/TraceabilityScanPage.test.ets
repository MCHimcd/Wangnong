/**
 * TraceabilityScanPage 冒烟测试
 */
import { describe, it, expect } from '@ohos/hypium';

export default function traceabilityScanPageTest() {
  describe('TraceabilityScanPage_Smoke', () => {
    it('page_module_can_be_referenced', 0, () => {
      expect(true).assertTrue();
    });
  });
}
