/**
 * Purpose: 收敛溯源码扫描流程中的轻量规则，避免页面直接散落字符串和时间窗逻辑。
 * Responsibilities: 规范化扫码结果、判断可用性、轮播引导语，并过滤短时间重复识别。
 * Flow: TraceabilityScanPage 在相机识别和手动输入后调用这些静态方法决定是否继续发起查询。
 * Dependencies: 由溯源扫描页面直接调用，不依赖外部服务。
 * Input: 原始二维码文本、步骤计数、上次识别状态和时间戳。
 * Output: 规范化后的编码、引导文案或重复识别判断结果。
 * Boundary: 这里只处理前端交互层规则，不验证后端业务含义。
 */
export class TraceabilityFlowHelper {
  private static readonly guideTexts: string[] = [
    '请将二维码对准扫描框',
    '保持稳定，系统正在识别',
    '光线不足时请靠近二维码'
  ];

  static normalizeCode(raw: string): string {
    return raw.trim().toUpperCase();
  }

  static isUsableCode(code: string): boolean {
    return code.trim().length > 0;
  }

  static nextGuideText(step: number): string {
    const idx = step % TraceabilityFlowHelper.guideTexts.length;
    return TraceabilityFlowHelper.guideTexts[idx];
  }

  // Reason: 扫码回调可能在同一帧附近多次命中同一结果，默认 800ms 窗口用于抑制重复导航和重复请求。
  static shouldIgnoreDuplicateCode(
    lastCode: string,
    lastAtMs: number,
    currentCode: string,
    nowMs: number,
    windowMs: number = 800
  ): boolean {
    if (lastCode.length === 0 || currentCode.length === 0) {
      return false;
    }
    return lastCode === currentCode && nowMs - lastAtMs < windowMs;
  }
}
