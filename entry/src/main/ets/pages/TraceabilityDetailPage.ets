import router from '@ohos.router';
import { TraceabilityDetailNavParams, TraceabilityInfo, TraceabilityStepInfo } from '../models/TraceabilityInfo';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

/**
 * Purpose: 展示单次溯源查询的详情，包括产品信息、质检信息和流转时间线。
 * Responsibilities: 反序列化扫码页传入的 TraceabilityInfo，并按区块渲染头图、基础信息和时间线。
 * Flow: aboutToAppear() 读取 params.infoJson 并解析；loaded 为 true 后渲染滚动详情内容。
 * Dependencies: 依赖 router 获取导航参数，依赖 TraceabilityInfo 模型与 DesignToken。
 * Input: TraceabilityDetailNavParams.infoJson。
 * Output: 溯源详情页 UI。
 * Boundary: 详情页不再重复请求后端，完全基于扫码页传入的数据快照展示。
 */
@Entry
@Component
struct TraceabilityDetailPage {
  @State info: TraceabilityInfo = new TraceabilityInfo();
  @State loaded: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as TraceabilityDetailNavParams;
    if (params && params.infoJson.length > 0) {
      // Reason: 使用 JSON 字符串承载详情对象，能避免 ArkTS 路由参数在复杂对象传递上的兼容问题。
      let json = params.infoJson;
      let parsed = JSON.parse(json) as TraceabilityInfo;
      this.info = parsed;
      this.loaded = true;
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
          })
        Text('溯源详情')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .layoutWeight(1)
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .backgroundColor(AppColors.Surface)
      .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
      .alignItems(VerticalAlign.Center)

      if (!this.loaded) {
        Column() {
          Text('📦').fontSize(48).margin({ bottom: AppSpacing.MD })
          Text('暂无溯源数据').fontSize(AppFontSize.Body).fontColor(AppColors.TextTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.ProductHeader()
            this.BasicInfoCard()
            this.QualityCard()
            this.StepsTimeline()
          }
          .width('100%')
          .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }

  @Builder ProductHeader() {
    Column() {
      Row() {
        Column() {
          Text(this.info.productName)
            .fontSize(AppFontSize.H1)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
          Text(this.info.variety)
            .fontSize(AppFontSize.Body)
            .fontColor(AppColors.TextSecondary)
            .margin({ top: AppSpacing.XS })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.info.qualityGrade)
          .fontSize(AppFontSize.Body)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.Success)
          .backgroundColor(AppColors.SuccessBg)
          .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.Full)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Text('批次号：')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextTertiary)
        Text(this.info.batchCode)
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.Accent)
          .fontWeight(FontWeight.Medium)
      }
      .margin({ top: AppSpacing.SM })
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.MD)
    .margin({ top: AppSpacing.MD })
  }

  @Builder BasicInfoCard() {
    Column() {
      Text('产地信息')
        .fontSize(AppFontSize.H3)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.SM })
      this.DetailRow('产地', this.info.origin)
      this.DetailRow('农场', this.info.farmName)
      this.DetailRow('地块', this.info.plotId)
      this.DetailRow('种植日期', this.info.plantDate)
      this.DetailRow('采收日期', this.info.harvestDate)
      this.DetailRow('保质期', this.info.shelfLife)
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.MD)
    .margin({ top: AppSpacing.SM })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder QualityCard() {
    Column() {
      Text('质检信息')
        .fontSize(AppFontSize.H3)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.SM })
      this.DetailRow('质量等级', this.info.qualityGrade)
      this.DetailRow('检测证书', this.info.certNo)
      this.DetailRow('检测员', this.info.inspectorName)
      this.DetailRow('检测日期', this.info.inspectDate)
    }
    .width('100%')
    .padding(AppSpacing.LG)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.MD)
    .margin({ top: AppSpacing.SM })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder StepsTimeline() {
    if (this.info.steps.length > 0) {
      // Flow: 时间线严格按 steps 当前顺序渲染，首节点高亮，其余节点通过竖线串联形成流转链路。
      Column() {
        Text('流转记录')
          .fontSize(AppFontSize.H3)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TextPrimary)
          .margin({ bottom: AppSpacing.MD })

        ForEach(this.info.steps, (step: TraceabilityStepInfo, idx: number) => {
          Row() {
            Column() {
              Column() {}
                .width(10)
                .height(10)
                .borderRadius(5)
                .backgroundColor(idx === 0 ? AppColors.Primary : AppColors.Border)
              if (idx < this.info.steps.length - 1) {
                Column() {}
                  .width(2)
                  .layoutWeight(1)
                  .backgroundColor(AppColors.Border)
              }
            }
            .width(20)
            .alignItems(HorizontalAlign.Center)
            .height('100%')

            Column() {
              Text(step.stepName)
                .fontSize(AppFontSize.Body)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TextPrimary)
              Text(step.time)
                .fontSize(AppFontSize.Caption)
                .fontColor(AppColors.TextTertiary)
                .margin({ top: 2 })
              Text(`${step.operator} · ${step.location}`)
                .fontSize(AppFontSize.Caption)
                .fontColor(AppColors.TextSecondary)
                .margin({ top: 2 })
              if (step.remark.length > 0) {
                Text(step.remark)
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.TextTertiary)
                  .margin({ top: 2 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .padding({ left: AppSpacing.SM, bottom: AppSpacing.LG })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        })
      }
      .width('100%')
      .padding(AppSpacing.LG)
      .backgroundColor(AppColors.Surface)
      .borderRadius(AppRadius.MD)
      .margin({ top: AppSpacing.SM })
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppFontSize.Body)
        .fontColor(AppColors.TextTertiary)
        .width(80)
      Text(value)
        .fontSize(AppFontSize.Body)
        .fontColor(AppColors.TextPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: AppSpacing.SM, bottom: AppSpacing.SM })
  }
}
