import { Node } from '../models/Node';
import { MonitorView } from './MonitorView';
import { AgriQAView } from './AgriQAView';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

@Component
export struct HomeView {
  @ObjectLink node: Node;
  @Prop nodesList: string[] = [];
  @Prop currentNodeIndex: number = 0;
  
  onSwitchNode: ((index: number) => void) | null = null;
  onAddNode: ((name: string) => void) | null = null;

  @State currentSidebarIndex: number = 0;
  @State isSidebarShow: boolean = false;

  private sidebarMenus: string[] = [
    '综合监控',
    '农业知识问答',
    '定时任务',
    '切换节点'
  ];

  @Builder
  SidebarContent() {
    Column() {
      // 占位块，确保内容不被绝对定位的按钮遮挡，替换掉文字
      Blank().height(80)

      List({ space: 15 }) {
        ForEach(this.sidebarMenus, (item: string, index: number) => {
          ListItem() {
            Text(item)
              .fontSize(16)
              .fontColor(this.currentSidebarIndex === index ? '#4CAF50' : '#FFFFFF')
              .fontWeight(this.currentSidebarIndex === index ? FontWeight.Bold : FontWeight.Normal)
              .width('100%')
              .padding({ left: 20, top: 15, bottom: 15 })
              .backgroundColor(this.currentSidebarIndex === index ? '#FFFFFF' : 'transparent')
              .borderRadius({ topLeft: 25, bottomLeft: 25 })
          }
          .onClick(() => {
            this.currentSidebarIndex = index;
            this.isSidebarShow = false;
          })
        }, (item: string) => item)
      }
      .width('100%')
      .padding({ left: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#4CAF50')
  }

  @Builder
  PlaceholderContent(title: string) {
    Column() {
      Blank()
      Text('功能暂未开放')
        .fontSize(16)
        .fontColor('#90A4AE')
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F6F3')
  }

  @Builder
  SwitchDeviceContent() {
    Column() {
      Text('切换节点')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#2C3E50')
        .margin({ top: 10, bottom: 20 })

      List({ space: 10 }) {
        ForEach(this.nodesList, (name: string, index: number) => {
          ListItem() {
            Row() {
              Text(name)
                .fontSize(18)
                .fontWeight(this.currentNodeIndex === index ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.currentNodeIndex === index ? '#4CAF50' : '#2C3E50')
              Blank()
              if (this.currentNodeIndex === index) {
                Text('当前')
                  .fontSize(14)
                  .fontColor('#4CAF50')
                  .backgroundColor('#E8F5E9')
                  .padding(5)
                  .borderRadius(8)
              } else {
                Button('切换')
                  .height(30)
                  .fontSize(14)
                  .backgroundColor('#4CAF50')
                  .onClick(() => {
                    if (this.onSwitchNode) {
                      this.onSwitchNode(index);
                    }
                  })
              }
            }
            .width('90%')
            .padding(15)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
          }
        }, (item: string) => item)
      }
      .width('100%')
      .alignListItem(ListItemAlign.Center)
      .layoutWeight(1)

      Button('添加新节点', { type: ButtonType.Capsule })
        .width('80%')
        .height(45)
        .backgroundColor('#4CAF50')
        .margin({ bottom: 40 })
        .onClick(() => {
          promptAction.showDialog({
            title: '添加节点',
            message: '请输入新节点名称（暂通过弹窗模拟即可）',
            buttons: [
              { text: '取消', color: '#90A4AE' },
              { text: '添加模拟节点', color: '#4CAF50' }
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
    .backgroundColor('#F2F6F3')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Text(this.sidebarMenus[this.currentSidebarIndex])
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C3E50')
          Blank()
          Text(`当前: ${this.node.name}`).fontSize(14).fontColor('#78909C')
        }
        .width('100%')
        .height(56)
        .padding({ left: 15, right: 15 })
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })

        Scroll() {
          Column() {
            if (this.currentSidebarIndex === 0) {
              MonitorView({
                nodeId: this.node.id,
                sensorData: this.node.sensorData,
                nodeState: this.node.nodeState,
                sensorMeta: this.node.sensorMeta,
                equipmentMeta: this.node.equipmentMeta
              })
            } else if (this.currentSidebarIndex === 1) {
              AgriQAView()
            } else if (this.currentSidebarIndex === 2) {
              // 点击后跳转到独立的定时任务页面
              Column() {
                Blank()
                Button('进入定时任务管理', { type: ButtonType.Capsule })
                  .width('60%').height(44).fontSize(16).backgroundColor('#4CAF50')
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/ScheduledTaskPage' });
                  })
                Blank()
              }.width('100%').height('100%').justifyContent(FlexAlign.Center)
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

      if (this.isSidebarShow) {
        Row() {}
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.28)')
          .zIndex(50)
          .onClick(() => {
            this.isSidebarShow = false;
          })
      }

      Column() {
        this.SidebarContent()
      }
      .width(220)
      .height('100%')
      .translate({ x: this.isSidebarShow ? 0 : -240, y: 0 })
      .animation({ duration: 300, curve: Curve.FastOutSlowIn })
      .zIndex(80)
      .onClick(() => {})

      // 绝对定位的悬浮控制按钮
      Row() {
        Column() {
          Line().width(18).height(2).backgroundColor('#4CAF50').margin({ bottom: 4 })
          Line().width(18).height(2).backgroundColor('#4CAF50').margin({ bottom: 4 })
          Line().width(18).height(2).backgroundColor('#4CAF50')
        }
        .width(20)
        .height(20)
        .justifyContent(FlexAlign.Center)
        // 根据状态决定方向，横(0) 和 竖(90)
        .rotate({ x: 0, y: 0, z: 1, angle: this.isSidebarShow ? 90 : 0 })
        .animation({ duration: 300, curve: Curve.FastOutSlowIn })
        
        Text('导航')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4CAF50')
          .margin({ left: 6 })
      }
      .backgroundColor('#E8F5E9')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin({ top: 12, left: 15 })
      .zIndex(100)
      .onClick(() => {
        this.isSidebarShow = !this.isSidebarShow;
      })
    }
  }
}
