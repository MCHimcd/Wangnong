import { Node } from '../models/Node';
import { MonitorView } from './MonitorView';
import { AgriQAView } from './AgriQAView';
import { ScheduledTaskView } from './ScheduledTaskView';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

interface SidebarMenuItem {
  label: string;
  icon: string;
}

@Component
export struct HomeView {
  @ObjectLink node: Node;
  @Prop nodesList: string[] = [];
  @Prop currentNodeIndex: number = 0;
  @Prop connectionStatus: 'connected' | 'disconnected' = 'disconnected';
  @Prop mqttHeartbeatOffline: boolean = false;
  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  onSwitchNode: ((index: number) => void) | null = null;
  onAddNode: ((name: string) => void) | null = null;

  @State currentSidebarIndex: number = 0;
  @State isSidebarShow: boolean = false;

  private sidebarMenus: SidebarMenuItem[] = [
    { label: '综合监控', icon: '📊' },
    { label: '农业知识问答', icon: '🌱' },
    { label: '定时任务', icon: '⏰' },
    { label: '切换节点', icon: '🔗' }
  ];

  @Builder
  SidebarContent() {
    Column() {
      // Logo区域
      Row() {
        Image($r('app.media.app_icon'))
          .width(36)
          .height(36)
          .borderRadius(AppRadius.SM)
        Column() {
          Text('智慧农业')
            .fontSize(AppFontSize.H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextOnSidebarActive)
          Text('IoT Monitor')
            .fontSize(AppFontSize.Mini)
            .fontColor(AppColors.TextOnSidebar)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: AppSpacing.MD })
      }
      .width('100%')
      .padding({ left: AppSpacing.XL, top: AppSpacing.XXL, bottom: AppSpacing.XL })

      Divider()
        .color('rgba(255,255,255,0.12)')
        .width('80%')
        .margin({ bottom: AppSpacing.MD })

      List({ space: AppSpacing.XS }) {
        ForEach(this.sidebarMenus, (item: SidebarMenuItem, index: number) => {
          ListItem() {
            Row() {
              // 选中指示条
              Row() {}
                .width(3)
                .height(24)
                .borderRadius(2)
                .backgroundColor(this.currentSidebarIndex === index ? AppColors.Accent : 'transparent')
                .margin({ right: AppSpacing.MD })

              Text(item.icon)
                .fontSize(18)
                .margin({ right: AppSpacing.MD })

              Text(item.label)
                .fontSize(AppFontSize.Body)
                .fontColor(this.currentSidebarIndex === index ?
                  AppColors.TextOnSidebarActive : AppColors.TextOnSidebar)
                .fontWeight(this.currentSidebarIndex === index ? FontWeight.Bold : FontWeight.Normal)
            }
            .width('100%')
            .height(48)
            .alignItems(VerticalAlign.Center)
            .padding({ right: AppSpacing.LG })
            .backgroundColor(this.currentSidebarIndex === index ? AppColors.SidebarActive : 'transparent')
            .borderRadius({ topRight: AppRadius.MD, bottomRight: AppRadius.MD })
          }
          .onClick(() => {
            this.currentSidebarIndex = index;
            this.isSidebarShow = false;
          })
        }, (item: SidebarMenuItem) => item.label)
      }
      .width('100%')
      .layoutWeight(1)

      // 底部连接状态
      Row() {
        Circle({ width: AppSize.StatusDotSize, height: AppSize.StatusDotSize })
          .fill(AppColors.PrimaryLight)
          .margin({ right: AppSpacing.SM })
        Text(`${this.node.name}`)
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.TextOnSidebar)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: AppSpacing.XL, bottom: AppSpacing.XL, top: AppSpacing.MD })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.SidebarBg)
  }

  @Builder
  SwitchDeviceContent() {
    Column() {
      Text('切换节点')
        .fontSize(AppFontSize.H1)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .width('100%')
        .margin({ top: AppSpacing.LG, bottom: AppSpacing.XL })
        .padding({ left: AppSpacing.PagePadding })

      List({ space: AppSpacing.MD }) {
        ForEach(this.nodesList, (name: string, index: number) => {
          ListItem() {
            Row() {
              // 左侧状态指示
              Row() {}
                .width(4)
                .height(40)
                .borderRadius(2)
                .backgroundColor(this.currentNodeIndex === index ? AppColors.Primary : 'transparent')
                .margin({ right: AppSpacing.LG })

              Column() {
                Text(name)
                  .fontSize(AppFontSize.H3)
                  .fontWeight(this.currentNodeIndex === index ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.currentNodeIndex === index ? AppColors.Primary : AppColors.TextPrimary)
                Text(this.currentNodeIndex === index ? '当前活跃节点' : '点击切换')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.TextTertiary)
                  .margin({ top: AppSpacing.XS })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.currentNodeIndex === index) {
                Text('✓ 当前')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.Primary)
                  .backgroundColor(AppColors.PrimaryBg)
                  .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
                  .borderRadius(AppRadius.SM)
              } else {
                Button('切换', { type: ButtonType.Capsule })
                  .height(AppSize.ButtonHeightSM)
                  .fontSize(AppFontSize.Caption)
                  .backgroundColor(AppColors.Primary)
                  .onClick(() => {
                    if (this.onSwitchNode) {
                      this.onSwitchNode(index);
                    }
                  })
              }
            }
            .width('100%')
            .padding({ left: AppSpacing.SM, right: AppSpacing.LG, top: AppSpacing.MD, bottom: AppSpacing.MD })
            .backgroundColor(AppColors.Surface)
            .borderRadius(AppRadius.LG)
            .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
          }
        }, (item: string) => item)
      }
      .width('100%')
      .alignListItem(ListItemAlign.Center)
      .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
      .layoutWeight(1)

      Button('+ 添加新节点', { type: ButtonType.Capsule })
        .width('60%')
        .height(AppSize.ButtonHeight)
        .fontSize(AppFontSize.Body)
        .backgroundColor(AppColors.Primary)
        .margin({ bottom: AppSpacing.XXL })
        .onClick(() => {
          promptAction.showDialog({
            title: '添加节点',
            message: '请输入新节点名称（暂通过弹窗模拟即可）',
            buttons: [
              { text: '取消', color: AppColors.TextTertiary },
              { text: '添加模拟节点', color: AppColors.Primary }
            ]
          }).then(data => {
            if (data.index === 1) {
              if (this.onAddNode) {
                this.onAddNode(`新建节点 ${this.nodesList.length + 1}`);
              }
            }
          });
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.Background)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 主内容区（始终全宽）
      Column() {
        // 顶栏（汉堡菜单集成在内）
        Row() {
          // 汉堡按钮
          Column() {
            Line().width(18).height(2).backgroundColor(AppColors.TextOnPrimary).margin({ bottom: 3 })
            Line().width(14).height(2).backgroundColor(AppColors.TextOnPrimary).margin({ bottom: 3 })
            Line().width(18).height(2).backgroundColor(AppColors.TextOnPrimary)
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.SM)
          .margin({ right: AppSpacing.MD })
          .rotate({ x: 0, y: 0, z: 1, angle: this.isSidebarShow ? 90 : 0 })
          .animation({ duration: 300, curve: Curve.FastOutSlowIn })
          .onClick(() => {
            this.isSidebarShow = !this.isSidebarShow;
          })

          Text(this.sidebarMenus[this.currentSidebarIndex].label)
            .fontSize(AppFontSize.H2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
          Blank()
          // 节点指示
          Row() {
            Circle({ width: 6, height: 6 })
              .fill(AppColors.Primary)
              .margin({ right: AppSpacing.XS })
            Text(this.node.name)
              .fontSize(AppFontSize.Caption)
              .fontColor(AppColors.TextSecondary)
          }
          .padding({ left: AppSpacing.SM, right: AppSpacing.MD, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .backgroundColor(AppColors.PrimaryBg)
          .borderRadius(AppRadius.Full)
        }
        .width('100%')
        .height(52)
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
        .backgroundColor(AppColors.Surface)
        .shadow({ radius: 8, color: 'rgba(30,70,40,0.04)', offsetY: 2 })

        // 内容区
        Scroll() {
          Column() {
            if (this.currentSidebarIndex === 0) {
              MonitorView({
                nodeId: this.node.id,
                nodeStatus: this.node.status,
                mqttHeartbeatOffline: this.mqttHeartbeatOffline || this.connectionStatus === 'disconnected',
                sensorData: this.node.sensorData,
                nodeState: this.node.nodeState,
                sensorMeta: this.node.sensorMeta,
                equipmentMeta: this.node.equipmentMeta
              })
            } else if (this.currentSidebarIndex === 1) {
              AgriQAView()
            } else if (this.currentSidebarIndex === 2) {
              ScheduledTaskView()
            } else if (this.currentSidebarIndex === 3) {
              this.SwitchDeviceContent()
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      // 遮罩层
      if (this.isSidebarShow) {
        Row() {}
          .width('100%')
          .height('100%')
          .backgroundColor(AppColors.OverlayBg)
          .zIndex(50)
          .onClick(() => {
            this.isSidebarShow = false;
          })
      }

      // 抽屉式侧边栏（从顶栏下方开始，避免遮挡）
      Column() {
        this.SidebarContent()
      }
      .width(AppSize.SidebarWidth)
      .height('100%')
      .translate({ x: this.isSidebarShow ? 0 : -AppSize.SidebarWidth - 20, y: 0 })
      .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      .zIndex(80)
    }
  }
}
