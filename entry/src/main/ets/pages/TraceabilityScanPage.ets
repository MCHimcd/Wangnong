import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import picker from '@ohos.file.picker';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { customScan, scanBarcode, scanCore, detectBarcode } from '@kit.ScanKit';
import { HttpService } from '../services/HttpService';
import { TraceabilityDetailNavParams, TraceabilityInfo } from '../models/TraceabilityInfo';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';
import { TraceabilityFlowHelper } from '../common/TraceabilityFlowHelper';

@Entry
@Component
struct TraceabilityScanPage {
  @State scanText: string = '';
  @State isSubmitting: boolean = false;
  @State isScanning: boolean = false;
  @State guideText: string = '请将二维码对准扫描框';

  private guideTimerId: number = -1;
  private guideTick: number = 0;
  private lastScanCode: string = '';
  private lastScanAt: number = 0;
  private readonly scanPreviewSize: number = 300;
  private readonly scanFrameSize: number = 220;
  private scanSurfaceId: string = '';
  private scanController: XComponentController = new XComponentController();
  private customScanInitialized: boolean = false;
  private cameraPermissionGranted: boolean = false;

  aboutToAppear() {
    this.startGuideTicker();
    void this.tryStartInlineScan();
  }

  aboutToDisappear() {
    if (this.guideTimerId !== -1) {
      clearInterval(this.guideTimerId);
      this.guideTimerId = -1;
    }
    void this.stopInlineScan();
  }

  private startGuideTicker() {
    if (this.guideTimerId !== -1) {
      return;
    }
    this.guideTimerId = setInterval(() => {
      this.guideTick++;
      this.guideText = TraceabilityFlowHelper.nextGuideText(this.guideTick);
    }, 1800);
  }

  private async handleRecognizedCode(rawCode: string) {
    const normalizedCode = TraceabilityFlowHelper.normalizeCode(rawCode);
    if (!TraceabilityFlowHelper.isUsableCode(normalizedCode)) {
      promptAction.showToast({ message: '未识别到有效二维码' });
      return;
    }

    const now = Date.now();
    if (TraceabilityFlowHelper.shouldIgnoreDuplicateCode(this.lastScanCode, this.lastScanAt, normalizedCode, now, 800)) {
      return;
    }

    this.lastScanCode = normalizedCode;
    this.lastScanAt = now;
    this.scanText = normalizedCode;
    await this.submitScanResult();
  }

  private async ensureCameraPermission(): Promise<boolean> {
    if (this.cameraPermissionGranted) {
      return true;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissionList: Array<Permissions> = ['ohos.permission.CAMERA' as Permissions];
      const grantResult = await atManager.requestPermissionsFromUser(context, permissionList);

      let granted = false;
      let i = 0;
      while (i < grantResult.authResults.length) {
        if (grantResult.authResults[i] === 0) {
          granted = true;
          break;
        }
        i++;
      }

      this.cameraPermissionGranted = granted;
      return granted;
    } catch (err) {
      return false;
    }
  }

  private async tryStartInlineScan() {
    if (this.isScanning || this.scanSurfaceId.length === 0) {
      return;
    }

    const granted = await this.ensureCameraPermission();
    if (!granted) {
      this.guideText = '请在系统设置中授予相机权限';
      promptAction.showToast({ message: '未授予相机权限，无法启动扫码' });
      return;
    }

    try {
      if (!this.customScanInitialized) {
        const options: scanBarcode.ScanOptions = {
          scanTypes: [scanCore.ScanType.QR_CODE],
          enableAlbum: false,
          enableMultiMode: false
        };
        customScan.init(options);
        this.customScanInitialized = true;
      }

      const viewControl: customScan.ViewControl = {
        width: this.scanPreviewSize,
        height: this.scanPreviewSize,
        surfaceId: this.scanSurfaceId
      };

      this.isScanning = true;
      customScan.start(viewControl, (err, results) => {
        if (err) {
          this.isScanning = false;
          this.guideText = '摄像头启动失败，请检查权限';
          promptAction.showToast({ message: '摄像头启动失败，请检查权限' });
          return;
        }

        if (!results || results.length === 0) {
          return;
        }

        void this.handleRecognizedCode(results[0].originalValue);
        try {
          customScan.rescan();
        } catch (rescanErr) {
        }
      });
    } catch (err) {
      this.isScanning = false;
      this.guideText = '摄像头启动失败，请检查权限';
      promptAction.showToast({ message: '扫码相机初始化失败' });
    }
  }

  private async stopInlineScan() {
    if (!this.customScanInitialized) {
      this.isScanning = false;
      return;
    }

    try {
      await customScan.stop();
    } catch (err) {
    }

    try {
      await customScan.release();
    } catch (err) {
    }

    this.customScanInitialized = false;
    this.isScanning = false;
  }

  private async pickImageAndDecode() {
    try {
      let photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      let photoPicker = new picker.PhotoViewPicker();
      const selected = await photoPicker.select(photoSelectOptions);
      if (!selected || selected.photoUris.length === 0) {
        return;
      }

      const decodeResult = await detectBarcode.decode({ uri: selected.photoUris[0] }, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: false
      });

      if (!decodeResult || decodeResult.length === 0) {
        promptAction.showToast({ message: '图片中未识别到二维码' });
        return;
      }

      await this.handleRecognizedCode(decodeResult[0].originalValue);
    } catch (err) {
      promptAction.showToast({ message: '相册识别失败，请重试' });
    }
  }

  private async submitScanResult() {
    if (!this.scanText || this.scanText.trim().length === 0) {
      promptAction.showToast({ message: '请先识别二维码内容' });
      return;
    }
    if (this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    let result: TraceabilityInfo | null = await HttpService.getInstance().uploadTraceCode(this.scanText.trim());
    this.isSubmitting = false;

    if (!result) {
      promptAction.showToast({ message: '上传失败，请检查后端连接' });
      return;
    }

    this.guideText = '识别成功，已获取溯源信息';
    promptAction.showToast({ message: '溯源查询成功' });

    let navParams = new TraceabilityDetailNavParams();
    navParams.infoJson = JSON.stringify(result);

    router.pushUrl({
      url: 'pages/TraceabilityDetailPage',
      params: navParams
    });
  }

  private onScanSurfaceLoad() {
    this.scanSurfaceId = this.scanController.getXComponentSurfaceId();
    void this.tryStartInlineScan();
  }

  private onScanSurfaceDestroy() {
    this.scanSurfaceId = '';
    void this.stopInlineScan();
  }

  build() {
    Column() {
      Row() {
        Row() {
          Image($r('sys.media.ohos_ic_back'))
            .width(24)
            .height(24)
            .fillColor(AppColors.TextPrimary)
            .margin({ right: AppSpacing.MD })
            .onClick(() => {
              router.back();
            })
          Text('溯源码扫码')
            .fontSize(AppFontSize.H2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        Button('从相册选择')
          .height(36)
          .padding({ left: AppSpacing.MD, right: AppSpacing.MD })
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextOnPrimary)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.Full)
          .onClick(() => {
            this.pickImageAndDecode();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
      .alignItems(VerticalAlign.Center)

      Column() {
        Stack({ alignContent: Alignment.Center }) {
          XComponent({
            id: 'traceabilityScanSurface',
            type: 'surface',
            controller: this.scanController
          })
            .width(this.scanPreviewSize)
            .height(this.scanPreviewSize)
            .borderRadius(AppRadius.LG)
            .backgroundColor('#102024')
            .onLoad(() => {
              this.onScanSurfaceLoad();
            })
            .onDestroy(() => {
              this.onScanSurfaceDestroy();
            })

          Column() {}
            .width(this.scanFrameSize)
            .height(this.scanFrameSize)
            .border({ width: 2, color: AppColors.Primary })
            .borderRadius(AppRadius.MD)

          Column() {
            Text(this.isScanning ? this.guideText : '摄像头初始化中...')
              .fontSize(AppFontSize.Caption)
              .fontColor(AppColors.TextOnPrimary)
              .backgroundColor('rgba(0,0,0,0.35)')
              .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
              .borderRadius(AppRadius.Full)
          }
          .width(this.scanPreviewSize)
          .height(this.scanPreviewSize)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.End)
          .padding({ bottom: AppSpacing.MD })
        }
        .width(this.scanPreviewSize)
        .height(this.scanPreviewSize)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }
}
