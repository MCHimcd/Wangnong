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
