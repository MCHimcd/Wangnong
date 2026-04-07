import { describe, it, expect } from '@ohos/hypium';
import { TraceabilityFlowHelper } from '../../main/ets/common/TraceabilityFlowHelper';

export default function traceabilityFlowHelperTest() {
  describe('TraceabilityFlowHelper', () => {
    it('normalizeCode_trim_and_uppercase', 0, () => {
      const code = TraceabilityFlowHelper.normalizeCode('  trace_abc_001  ');
      expect(code).assertEqual('TRACE_ABC_001');
    });

    it('isUsableCode_empty_returns_false', 0, () => {
      expect(TraceabilityFlowHelper.isUsableCode('')).assertFalse();
      expect(TraceabilityFlowHelper.isUsableCode('   ')).assertFalse();
    });

    it('nextGuideText_cycles', 0, () => {
      const t0 = TraceabilityFlowHelper.nextGuideText(0);
      const t1 = TraceabilityFlowHelper.nextGuideText(1);
      expect(t0 !== t1).assertTrue();
    });

    it('shouldIgnoreDuplicateCode_same_code_within_window', 0, () => {
      const ignored = TraceabilityFlowHelper.shouldIgnoreDuplicateCode(
        'TRACE_001',
        1000,
        'TRACE_001',
        1500,
        800
      );
      expect(ignored).assertTrue();
    });

    it('shouldIgnoreDuplicateCode_different_or_overtime_not_ignored', 0, () => {
      const differentCodeIgnored = TraceabilityFlowHelper.shouldIgnoreDuplicateCode(
        'TRACE_001',
        1000,
        'TRACE_002',
        1200,
        800
      );
      const overtimeIgnored = TraceabilityFlowHelper.shouldIgnoreDuplicateCode(
        'TRACE_001',
        1000,
        'TRACE_001',
        2000,
        800
      );
      expect(differentCodeIgnored).assertFalse();
      expect(overtimeIgnored).assertFalse();
    });
  });
}
