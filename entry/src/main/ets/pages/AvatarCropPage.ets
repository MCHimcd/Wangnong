import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import { AvatarCropMath } from '../common/AvatarCropMath';
import { HttpService } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

@Entry
@Component
struct AvatarCropPage {
  @State imageUri: string = '';
  @State sourceWidth: number = 0;
  @State sourceHeight: number = 0;
  @State cropCenterX: number = 140;
  @State cropCenterY: number = 140;
  @State zoomFactor: number = 1;
  @State rotationAngle: number = 0;
  @State isSaving: boolean = false;

  private cropViewSize: number = 280;
  private frameDiameter: number = 210;
  private dragLastX: number = 0;
  private dragLastY: number = 0;
  private isDragging: boolean = false;
  private pinchStartScale: number = 1;
  private rotationStartAngle: number = 0;

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && typeof params['imageUri'] === 'string') {
      this.imageUri = params['imageUri'];
    }
    this.cropCenterX = this.cropViewSize / 2;
    this.cropCenterY = this.cropViewSize / 2;
    this.loadImageInfo();
  }

  private async loadImageInfo() {
    if (this.imageUri.length === 0) {
      promptAction.showToast({ message: '未获取到待裁剪图片' });
      router.back();
      return;
    }

    let source: image.ImageSource | null = null;
    try {
      source = image.createImageSource(this.imageUri);
      const info = await source.getImageInfo();
      this.sourceWidth = info.size.width;
      this.sourceHeight = info.size.height;

      if (this.sourceWidth <= 0 || this.sourceHeight <= 0) {
        promptAction.showToast({ message: '图片尺寸无效' });
        router.back();
      }
    } catch (err) {
      const bizErr = err as BusinessError;
      console.error(`Load image info failed. Code:${bizErr.code}, message:${bizErr.message}, uri:${this.imageUri}`);
      promptAction.showToast({ message: '读取图片失败' });
      router.back();
    } finally {
      if (source !== null) {
        try {
          await source.release();
        } catch (releaseErr) {
          // ignore release error
        }
      }
    }
  }

  private clampCropCenter() {
    const half = this.frameDiameter / 2;
    if (this.cropCenterX < half) {
      this.cropCenterX = half;
    }
    if (this.cropCenterY < half) {
      this.cropCenterY = half;
    }
    if (this.cropCenterX > this.cropViewSize - half) {
      this.cropCenterX = this.cropViewSize - half;
    }
    if (this.cropCenterY > this.cropViewSize - half) {
      this.cropCenterY = this.cropViewSize - half;
    }
  }

  private applyCircleMask(pixelBuffer: ArrayBuffer, size: number) {
    const bytes = new Uint8Array(pixelBuffer);
    const center = size / 2;
    const radius = center;
    const radiusSquare = radius * radius;

    let y = 0;
    while (y < size) {
      let x = 0;
      while (x < size) {
        const dx = x + 0.5 - center;
        const dy = y + 0.5 - center;
        const offset = (y * size + x) * 4;
        if (dx * dx + dy * dy > radiusSquare) {
          bytes[offset + 3] = 0;
        }
        x++;
      }
      y++;
    }
  }

  private async createCircularAvatarFile(): Promise<string> {
    const source = image.createImageSource(this.imageUri);
    let pixelMap: image.PixelMap | null = null;
    let outputFile: fs.File | null = null;
    let packer: image.ImagePacker | null = null;

    try {
      const region = AvatarCropMath.computeRegion(
        this.sourceWidth,
        this.sourceHeight,
        this.cropViewSize,
        this.cropViewSize,
        this.frameDiameter,
        this.cropCenterX,
        this.cropCenterY,
        this.zoomFactor
      );

      let options: image.DecodingOptions = {};
      options.editable = true;
      options.desiredRegion = AvatarCropMath.toImageRegion(region);
      options.desiredPixelFormat = image.PixelMapFormat.RGBA_8888;
      let outputSize: image.Size = { width: 512, height: 512 };
      options.desiredSize = outputSize;

      pixelMap = await source.createPixelMap(options);

      // 应用旋转
      if (this.rotationAngle !== 0) {
        await pixelMap.rotate(this.rotationAngle);
      }

      const pixelBuffer = new ArrayBuffer(512 * 512 * 4);
      await pixelMap.readPixelsToBuffer(pixelBuffer);
      this.applyCircleMask(pixelBuffer, 512);
      await pixelMap.writeBufferToPixels(pixelBuffer);

      const context = getContext(this) as common.UIAbilityContext;
      const outPath = `${context.cacheDir}/avatar_${new Date().getTime()}.png`;
      outputFile = fs.openSync(outPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);

      packer = image.createImagePacker();
      let packing: image.PackingOption = { format: 'image/png', quality: 100 };
      await packer.packToFile(pixelMap, outputFile.fd, packing);
      return outPath;
    } finally {
      if (packer) {
        await packer.release();
      }
      if (outputFile) {
        fs.closeSync(outputFile);
      }
      if (pixelMap) {
        await pixelMap.release();
      }
      await source.release();
    }
  }

  private async confirmCrop() {
    if (this.isSaving || this.imageUri.length === 0 || this.sourceWidth <= 0 || this.sourceHeight <= 0) {
      return;
    }

    this.isSaving = true;
    try {
      const avatarPath = await this.createCircularAvatarFile();
      const profile = await HttpService.getInstance().uploadAvatar(avatarPath);

      if (profile && profile.avatarSrc) {
        AppStorage.setOrCreate('profileAvatarSrc', profile.avatarSrc);
      } else {
        AppStorage.setOrCreate('profileAvatarSrc', avatarPath);
      }

      if (profile && profile.userName) {
        AppStorage.setOrCreate('profileUserName', profile.userName);
      }

      if (!profile) {
        promptAction.showToast({ message: '后端上传失败，已本地替换头像' });
      } else {
        promptAction.showToast({ message: '头像更新成功' });
      }
      router.back();
    } catch (err) {
      promptAction.showToast({ message: '头像裁剪失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(24)
          .height(24)
          .fillColor(AppColors.TextPrimary)
          .margin({ right: AppSpacing.MD })
          .onClick(() => {
            router.back();
          });
        Text('头像裁剪')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary);
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
      .alignItems(VerticalAlign.Center);

      Column({ space: AppSpacing.LG }) {
        Stack() {
          Image(this.imageUri)
            .width(this.cropViewSize)
            .height(this.cropViewSize)
            .objectFit(ImageFit.Cover)
            .borderRadius(AppRadius.MD)
            .scale({ x: this.zoomFactor, y: this.zoomFactor })
            .rotate({ angle: this.rotationAngle });

          Column() {}
            .width(this.frameDiameter)
            .height(this.frameDiameter)
            .border({ width: 2, color: AppColors.Primary })
            .borderRadius(AppRadius.Full)
            .position({
              x: this.cropCenterX - this.frameDiameter / 2,
              y: this.cropCenterY - this.frameDiameter / 2
            });
        }
        .width(this.cropViewSize)
        .height(this.cropViewSize)
        .borderRadius(AppRadius.MD)
        .backgroundColor(AppColors.Divider)
        .clip(true)
        .gesture(
          GestureGroup(GestureMode.Parallel,
            // 单指拖动裁剪框
            PanGesture()
              .onActionStart(() => {
                this.isDragging = true;
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isDragging && event.offsetX !== undefined && event.offsetY !== undefined) {
                  this.cropCenterX += event.offsetX;
                  this.cropCenterY += event.offsetY;
                  this.clampCropCenter();
                }
              })
              .onActionEnd(() => {
                this.isDragging = false;
              }),
            // 双指缩放
            PinchGesture({ fingers: 2, distance: 3 })
              .onActionStart(() => {
                this.pinchStartScale = this.zoomFactor;
              })
              .onActionUpdate((event: GestureEvent) => {
                if (event.scale !== undefined) {
                  const newScale = this.pinchStartScale * event.scale;
                  this.zoomFactor = AvatarCropMath.clampScale(newScale, 1, 3);
                }
              }),
            // 双指旋转 (90° snap)
            RotationGesture({ fingers: 2, angle: 15 })
              .onActionStart(() => {
                this.rotationStartAngle = this.rotationAngle;
              })
              .onActionEnd((event: GestureEvent) => {
                if (event.angle !== undefined) {
                  const rawAngle = this.rotationStartAngle + event.angle;
                  this.rotationAngle = AvatarCropMath.snapRotation(rawAngle);
                }
              })
          )
        );

        Text('双指捏合缩放 · 双指旋转调整方向')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextSecondary)
          .textAlign(TextAlign.Center)
          .width('100%');

        Button(this.isSaving ? '处理中...' : '确认并替换头像')
          .width('100%')
          .height(44)
          .borderRadius(AppRadius.MD)
          .backgroundColor(AppColors.Primary)
          .enabled(!this.isSaving)
          .onClick(() => {
            this.confirmCrop();
          });
      }
      .width('100%')
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.XL })
      .alignItems(HorizontalAlign.Center);

      Blank()
        .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background);
  }
}
