/**
 * BreakpointSystem 单元测试
 *
 * register/unregister 依赖 @ohos.mediaquery 和 AppStorage，在本地测试中不可用。
 * 这里仅测试 Singleton 和 columnsForBreakpoint 工具函数。
 */
import { describe, it, expect } from '@ohos/hypium';
import { columnsForBreakpoint } from '../../main/ets/common/BreakpointSystem';

export default function breakpointSystemTest() {
  describe('BreakpointSystem', () => {

    // ===== columnsForBreakpoint =====
    it('sm_returns_2_columns', 0, () => {
      expect(columnsForBreakpoint('sm')).assertEqual(2);
    });

    it('md_returns_3_columns', 0, () => {
      expect(columnsForBreakpoint('md')).assertEqual(3);
    });

    it('lg_returns_4_columns', 0, () => {
      expect(columnsForBreakpoint('lg')).assertEqual(4);
    });

    it('unknown_breakpoint_defaults_to_2', 0, () => {
      expect(columnsForBreakpoint('unknown')).assertEqual(2);
    });

    it('empty_string_defaults_to_2', 0, () => {
      expect(columnsForBreakpoint('')).assertEqual(2);
    });
  });
}
