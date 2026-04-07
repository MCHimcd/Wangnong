import { describe, it, expect } from '@ohos/hypium';
import { AvatarCropMath, CropRegion } from '../../main/ets/common/AvatarCropMath';

export default function avatarCropMathTest() {
  describe('AvatarCropMath', () => {
    it('computeRegion_clamps_inside_source', 0, () => {
      const region = AvatarCropMath.computeRegion(
        400,
        300,
        280,
        280,
        240,
        260,
        260,
        2
      );
      expect(region.x >= 0).assertTrue();
      expect(region.y >= 0).assertTrue();
      expect(region.size > 0).assertTrue();
      expect(region.x + region.size <= 400).assertTrue();
      expect(region.y + region.size <= 300).assertTrue();
    });

    it('computeRegion_zoom_in_reduces_size', 0, () => {
      const region1 = AvatarCropMath.computeRegion(1080, 1080, 280, 280, 200, 140, 140, 1);
      const region2 = AvatarCropMath.computeRegion(1080, 1080, 280, 280, 200, 140, 140, 2);
      expect(region2.size < region1.size).assertTrue();
    });

    it('toImageRegion_maps_fields', 0, () => {
      const region = new CropRegion();
      region.x = 10;
      region.y = 20;
      region.size = 300;
      const mapped = AvatarCropMath.toImageRegion(region);
      expect(mapped.x).assertEqual(10);
      expect(mapped.y).assertEqual(20);
      expect(mapped.size.width).assertEqual(300);
      expect(mapped.size.height).assertEqual(300);
    });

    it('snapRotation_rounds_to_nearest_90', 0, () => {
      expect(AvatarCropMath.snapRotation(0)).assertEqual(0);
      expect(AvatarCropMath.snapRotation(44)).assertEqual(0);
      expect(AvatarCropMath.snapRotation(45)).assertEqual(90);
      expect(AvatarCropMath.snapRotation(89)).assertEqual(90);
      expect(AvatarCropMath.snapRotation(90)).assertEqual(90);
      expect(AvatarCropMath.snapRotation(134)).assertEqual(90);
      expect(AvatarCropMath.snapRotation(135)).assertEqual(180);
      expect(AvatarCropMath.snapRotation(180)).assertEqual(180);
      expect(AvatarCropMath.snapRotation(224)).assertEqual(180);
      expect(AvatarCropMath.snapRotation(225)).assertEqual(270);
      expect(AvatarCropMath.snapRotation(270)).assertEqual(270);
      expect(AvatarCropMath.snapRotation(314)).assertEqual(270);
      expect(AvatarCropMath.snapRotation(315)).assertEqual(0);
      expect(AvatarCropMath.snapRotation(359)).assertEqual(0);
      expect(AvatarCropMath.snapRotation(360)).assertEqual(0);
    });

    it('snapRotation_handles_negative_angles', 0, () => {
      expect(AvatarCropMath.snapRotation(-45)).assertEqual(0);
      expect(AvatarCropMath.snapRotation(-90)).assertEqual(270);
      expect(AvatarCropMath.snapRotation(-180)).assertEqual(180);
      expect(AvatarCropMath.snapRotation(-270)).assertEqual(90);
    });

    it('clampScale_within_bounds', 0, () => {
      expect(AvatarCropMath.clampScale(0.5, 1, 3)).assertEqual(1);
      expect(AvatarCropMath.clampScale(1.5, 1, 3)).assertEqual(1.5);
      expect(AvatarCropMath.clampScale(4.0, 1, 3)).assertEqual(3);
    });
  });
}
