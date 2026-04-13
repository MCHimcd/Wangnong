/**
 * Purpose: 将底层拍照异常转换为适合页面直接展示的用户提示文案。
 * Responsibilities: 识别取消操作、权限问题、模拟器/不支持环境，并返回统一提示。
 * Flow: 页面捕获拍照异常后调用 messageForCameraError()；内部先归一化 message，再按错误类型短路匹配。
 * Dependencies: 供 ProfileView、AvatarCropPage 等头像采集入口复用。
 * Input: 相机 API 返回的错误码与错误消息。
 * Output: 可直接显示的提示文案；空字符串表示用户主动取消，无需提示。
 * Boundary: 这里只做错误归类，不执行权限申请或拍照重试。
 */
export class AvatarCaptureHelper {
  static messageForCameraError(code: number, message: string): string {
    const normalizedMessage = message.toLowerCase();

    // 用户主动取消 — 不提示
    if (code === 1000500002 || normalizedMessage.indexOf('cancel') !== -1) {
      return '';
    }

    // 权限问题
    if (code === 201 || normalizedMessage.indexOf('permission') !== -1 || normalizedMessage.indexOf('denied') !== -1) {
      return '未授予相机权限，请在系统设置中允许后重试';
    }

    // 模拟器/不支持的环境
    if (AvatarCaptureHelper.isLikelySimulatorOrUnsupported(code, normalizedMessage)) {
      return '当前环境可能不支持拍照（常见于模拟器），请在真机测试或改用从相册选择';
    }

    return '拍照失败，请重试';
  }

  // Reason: 模拟器和无摄像头设备的报错来源不稳定，因此同时匹配错误码和关键词，避免页面层重复维护兼容分支。
  private static isLikelySimulatorOrUnsupported(code: number, normalizedMessage: string): boolean {
    // 模拟器常见错误码
    if (code === 1001 || code === 1000500001 || code === 7400101 || code === 7400102 || code === 7400201) {
      return true;
    }

    // 关键词匹配
    const keywords = ['not support', 'simulator', 'camera unavailable', 'no camera', 'device not found',
      'unsupported', 'emulator', 'invalid camera'];
    let i = 0;
    while (i < keywords.length) {
      if (normalizedMessage.indexOf(keywords[i]) !== -1) {
        return true;
      }
      i++;
    }

    return false;
  }
}
