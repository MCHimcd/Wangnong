import { describe, it, expect } from '@ohos/hypium';
import { AvatarCaptureHelper } from '../../main/ets/common/AvatarCaptureHelper';

export default function avatarCaptureHelperTest() {
  describe('AvatarCaptureHelper', () => {
    it('messageForCameraError_permission_denied', 0, () => {
      const msg = AvatarCaptureHelper.messageForCameraError(201, 'permission denied');
      expect(msg).assertContain('相机权限');
    });

    it('messageForCameraError_user_cancel_returns_empty', 0, () => {
      const msg = AvatarCaptureHelper.messageForCameraError(1000500002, 'user canceled');
      expect(msg).assertEqual('');
    });

    it('messageForCameraError_simulator_or_device_not_support', 0, () => {
      const msgByCode = AvatarCaptureHelper.messageForCameraError(1001, 'camera unavailable');
      const msgByText = AvatarCaptureHelper.messageForCameraError(-1, 'not support camera in simulator');
      expect(msgByCode).assertContain('模拟器');
      expect(msgByText).assertContain('模拟器');
    });

    it('messageForCameraError_unknown', 0, () => {
      const msg = AvatarCaptureHelper.messageForCameraError(-1, 'random error');
      expect(msg).assertContain('拍照失败');
    });
  });
}
