import image from '@ohos.multimedia.image';

/**
 * Purpose: 为头像裁剪页提供纯数学映射，负责把屏幕坐标转换为原图裁剪区域。
 * Responsibilities: 计算显示尺寸、限制缩放范围、吸附旋转角度，并生成 image.Region。
 * Flow: AvatarCropPage 先根据图片与容器尺寸调用 computeRegion()，再将结果传给图像裁剪与导出流程。
 * Dependencies: 依赖 @ohos.multimedia.image 的 Region 类型作为输出格式。
 * Input: 原图尺寸、视图尺寸、裁剪框直径、中心点和缩放值。
 * Output: 合法的正方形 CropRegion 和对应的 image.Region。
 * Invariant: 输出区域始终保持在源图边界内，且宽高相等，避免底层图像 API 越界。
 */
export class CropRegion {
  x: number = 0;
  y: number = 0;
  size: number = 0;
}

class DisplaySpec {
  width: number = 0;
  height: number = 0;
  offsetX: number = 0;
  offsetY: number = 0;
}

export class AvatarCropMath {
  private static clamp(value: number, min: number, max: number): number {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  private static toDisplaySpec(sourceWidth: number, sourceHeight: number, viewWidth: number, viewHeight: number): DisplaySpec {
    const spec = new DisplaySpec();
    const scale = Math.max(viewWidth / sourceWidth, viewHeight / sourceHeight);
    spec.width = sourceWidth * scale;
    spec.height = sourceHeight * scale;
    spec.offsetX = (viewWidth - spec.width) / 2;
    spec.offsetY = (viewHeight - spec.height) / 2;
    return spec;
  }

  /**
   * 将任意角度 snap 到最近的 90° 倍数 (0, 90, 180, 270)
   */
  static snapRotation(angle: number): number {
    // 标准化到 0-360
    let normalized = angle % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    // snap 到最近的 90°
    const snapped = Math.round(normalized / 90) * 90;
    return snapped % 360;
  }

  /**
   * 限制缩放比例在 min-max 范围内
   */
  static clampScale(scale: number, min: number, max: number): number {
    return AvatarCropMath.clamp(scale, min, max);
  }

  // Reason: UI 中的拖拽中心点和缩放值都基于“填充满视图”的显示结果，必须先映射回源图坐标再裁剪，否则导出的头像会与预览不一致。
  static computeRegion(
    sourceWidth: number,
    sourceHeight: number,
    viewWidth: number,
    viewHeight: number,
    frameDiameter: number,
    centerX: number,
    centerY: number,
    zoom: number
  ): CropRegion {
    const region = new CropRegion();
    const safeZoom = zoom < 1 ? 1 : zoom;
    const spec = AvatarCropMath.toDisplaySpec(sourceWidth, sourceHeight, viewWidth, viewHeight);
    const displayToSourceScale = sourceWidth / spec.width;

    const sourceCenterX = (centerX - spec.offsetX) * displayToSourceScale;
    const sourceCenterY = (centerY - spec.offsetY) * displayToSourceScale;

    const baseSize = frameDiameter * displayToSourceScale;
    const rawCropSize = Math.floor(baseSize / safeZoom);
    const minAllowed = 64;
    const maxAllowed = Math.min(sourceWidth, sourceHeight);
    const cropSize = AvatarCropMath.clamp(rawCropSize, minAllowed, maxAllowed);

    const half = cropSize / 2;
    const rawX = Math.floor(sourceCenterX - half);
    const rawY = Math.floor(sourceCenterY - half);

    const maxX = sourceWidth - cropSize;
    const maxY = sourceHeight - cropSize;

    region.x = AvatarCropMath.clamp(rawX, 0, maxX > 0 ? maxX : 0);
    region.y = AvatarCropMath.clamp(rawY, 0, maxY > 0 ? maxY : 0);
    region.size = cropSize;
    return region;
  }

  // Output: 裁剪输出统一转换为 OpenHarmony 图像裁剪接口可接受的 Region 结构。
  static toImageRegion(crop: CropRegion): image.Region {
    const mapped: image.Region = {
      x: crop.x,
      y: crop.y,
      size: {
        width: crop.size,
        height: crop.size
      }
    };
    return mapped;
  }
}
