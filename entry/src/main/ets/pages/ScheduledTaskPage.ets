import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import {
  HttpService,
  ScheduledTaskItem,
  CreateTaskRequest,
  NodeListItem
} from '../services/HttpService';

/**
 * Purpose: 提供定时任务列表与新建入口，负责把前端表单转换为后端任务请求结构。
 * Responsibilities: 加载节点与任务列表、维护新建弹窗状态、创建/切换/删除定时任务，并格式化重复周期展示。
 * Flow: aboutToAppear() 先加载节点再加载任务；新建时组装 CreateTaskRequest，成功后刷新列表并重置弹窗字段。
 * Dependencies: 依赖 HttpService 的任务接口和节点列表接口。
 * Input: 当前节点列表、任务列表以及弹窗中的设备/动作/时间/重复日配置。
 * Output: 定时任务卡片列表和任务创建/切换/删除请求。
 * Boundary: repeatDays 采用逗号分隔的 1-7 编码，必须与后端约定保持一致。
 */
@Entry
@Component
struct ScheduledTaskPage {
  @State tasks: ScheduledTaskItem[] = [];
  @State nodes: NodeListItem[] = [];
  @State isLoading: boolean = false;
  @State showCreateDialog: boolean = false;

  // Dialog fields
  @State dTaskName: string = '';
  @State dNodeId: string = '';
  @State dEquipmentKey: string = 'water_pump';
  @State dAction: string = 'turn_on';
  @State dHour: number = 8;
  @State dMinute: number = 0;
  @State dRepeatDays: string = '1,2,3,4,5,6,7';

  private equipmentOptions: string[] = ['water_valve', 'water_pump', 'led_light'];
  private actionOptions: string[] = ['turn_on', 'turn_off'];
  private equipmentNames: Record<string, string> = {
    'water_valve': '水阀',
    'water_pump': '水泵',
    'led_light': '补光灯'
  };

  async aboutToAppear() {
    this.isLoading = true;
    await this.loadNodes();
    await this.loadTasks();
    this.isLoading = false;
  }

  async loadNodes() {
    let list = await HttpService.getInstance().getNodes();
    if (list) {
      // Reason: 创建弹窗默认选第一个节点，避免页面首次进入时 dNodeId 为空导致请求参数不完整。
      this.nodes = list;
      if (this.dNodeId === '' && list.length > 0) {
        this.dNodeId = list[0].id;
      }
    }
  }

  async loadTasks() {
    let list = await HttpService.getInstance().getScheduledTasks();
    if (list) {
      this.tasks = list;
    }
  }

  async doCreate() {
    if (!this.dTaskName.trim()) {
      promptAction.showToast({ message: '请输入任务名称' });
      return;
    }
    // Flow: 弹窗字段直接映射到 CreateTaskRequest；页面不做额外转换，唯一的协议约束是 repeatDays 的字符串编码。
    let req = new CreateTaskRequest();
    req.nodeId = this.dNodeId;
    req.equipmentKey = this.dEquipmentKey;
    req.action = this.dAction;
    req.taskName = this.dTaskName.trim();
    req.hour = this.dHour;
    req.minute = this.dMinute;
    req.repeatDays = this.dRepeatDays;

    let result = await HttpService.getInstance().createScheduledTask(req);
    if (result) {
      promptAction.showToast({ message: '创建成功' });
      this.showCreateDialog = false;
      this.resetDialog();
      await this.loadTasks();
    } else {
      promptAction.showToast({ message: '创建失败' });
    }
  }

  async toggleTask(taskId: number) {
    let ok = await HttpService.getInstance().toggleScheduledTask(taskId);
    if (ok) {
      await this.loadTasks();
    }
  }

  confirmDelete(task: ScheduledTaskItem) {
    AlertDialog.show({
      title: '确认删除',
      message: `确定删除任务「${task.taskName}」？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#F44336',
        action: async () => {
          let ok = await HttpService.getInstance().deleteScheduledTask(task.id);
          if (ok) {
            promptAction.showToast({ message: '已删除' });
            await this.loadTasks();
          }
        }
      }
    });
  }

  resetDialog() {
    // Boundary: 重置为“每天 08:00 开启水泵”的默认模板，便于连续创建多个常规任务。
    this.dTaskName = '';
    this.dEquipmentKey = 'water_pump';
    this.dAction = 'turn_on';
    this.dHour = 8;
    this.dMinute = 0;
    this.dRepeatDays = '1,2,3,4,5,6,7';
  }

  formatTime(hour: number, minute: number): string {
    return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
  }

  formatRepeatDays(days: string): string {
    // Reason: 列表展示用中文星期格式提升可读性，但底层仍保留后端约定的数字编码字符串。
    if (!days || days === '1,2,3,4,5,6,7') return '每天';
    let dayNames: Record<string, string> = {
      '1': '周一', '2': '周二', '3': '周三', '4': '周四',
      '5': '周五', '6': '周六', '7': '周日'
    };
    return days.split(',').map((d: string) => {
      let name = dayNames[d.trim()];
      return name ? name : d.trim();
    }).join(' ');
  }

  getEquipmentName(key: string): string {
    let name = this.equipmentNames[key];
    return name ? name : key;
  }

  build() {
    Stack() {
      Column() {
        // Header
        Row() {
          Image($r('sys.media.ohos_ic_back'))
            .width(28).height(28).margin({ right: 15 }).fillColor('#2C3E50')
            .onClick(() => { router.back(); })
          Text('定时任务')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#2C3E50').layoutWeight(1)
          Button('+ 新建', { type: ButtonType.Capsule })
            .height(34).fontSize(14).backgroundColor('#4CAF50')
            .onClick(() => { this.showCreateDialog = true; })
        }
        .width('100%').height(56).padding({ left: 15, right: 15 })
        .backgroundColor('#FFFFFF')
        .shadow({ radius: 5, color: 'rgba(0,0,0,0.05)', offsetY: 2 })

        if (this.tasks.length === 0 && !this.isLoading) {
          Column() {
            Blank()
            Text('暂无定时任务').fontSize(16).fontColor('#B0BEC5')
            Text('点击右上角「+ 新建」创建定时任务').fontSize(13).fontColor('#B0BEC5').margin({ top: 8 })
            Blank()
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            ForEach(this.tasks, (task: ScheduledTaskItem) => {
              ListItem() {
                Column() {
                  Row() {
                    Text(task.taskName)
                      .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#2C3E50')
                    Blank()
                    Toggle({ type: ToggleType.Switch, isOn: task.enabled })
                      .onChange((isOn: boolean) => { this.toggleTask(task.id); })
                      .width(50).height(28)
                  }.width('100%')

                  Row() {
                    Text(this.formatTime(task.hour, task.minute))
                      .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#4CAF50')
                    Column() {
                      Text(this.getEquipmentName(task.equipmentKey))
                        .fontSize(13).fontColor('#78909C')
                      Text(task.action === 'turn_on' ? '开启' : '关闭')
                        .fontSize(13).fontColor(task.action === 'turn_on' ? '#4CAF50' : '#F44336')
                    }.margin({ left: 15 }).alignItems(HorizontalAlign.Start)
                  }.width('100%').margin({ top: 8 })

                  Row() {
                    Text(this.formatRepeatDays(task.repeatDays))
                      .fontSize(12).fontColor('#90A4AE')
                    Text(' · ').fontColor('#E0E0E0')
                    Text(task.nodeId).fontSize(12).fontColor('#90A4AE')
                    Blank()
                    Text('删除').fontSize(12).fontColor('#F44336').padding(4)
                      .onClick(() => { this.confirmDelete(task); })
                  }.width('100%').margin({ top: 10 })
                }
                .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(12)
                .shadow({ radius: 4, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
                .opacity(task.enabled ? 1.0 : 0.6)
              }
            })
          }
          .width('100%').layoutWeight(1).padding({ left: 15, right: 15, top: 15 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F2F6F3')

      // Create dialog
      if (this.showCreateDialog) {
        Column() { Blank() }
          .width('100%').height('100%').position({ x: 0, y: 0 })
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick(() => { this.showCreateDialog = false; })

        Scroll() {
          Column() {
            Text('新建定时任务').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#2C3E50')
              .margin({ bottom: 15 })

            TextInput({ placeholder: '任务名称', text: this.dTaskName })
              .onChange((value: string) => { this.dTaskName = value; })
              .height(44).backgroundColor('#F5F5F5').borderRadius(8).margin({ bottom: 10 })

            Text('选择节点').fontSize(13).fontColor('#78909C').margin({ bottom: 5 })
              .width('100%')
            Select(this.nodes.map((n: NodeListItem) => {
              let item: SelectOption = { value: n.name + ' (' + n.id + ')' };
              return item;
            }))
              .selected(0)
              .value(this.dNodeId)
              .onSelect((index: number) => {
                if (index < this.nodes.length) {
                  this.dNodeId = this.nodes[index].id;
                }
              })
              .height(40).width('100%').margin({ bottom: 10 })

            Text('设备').fontSize(13).fontColor('#78909C').margin({ bottom: 5 })
              .width('100%')
            Select(this.equipmentOptions.map((k: string) => {
              let item: SelectOption = { value: this.getEquipmentName(k) };
              return item;
            }))
              .selected(1)
              .value(this.getEquipmentName(this.dEquipmentKey))
              .onSelect((index: number) => {
                if (index < this.equipmentOptions.length) {
                  this.dEquipmentKey = this.equipmentOptions[index];
                }
              })
              .height(40).width('100%').margin({ bottom: 10 })

            Text('操作').fontSize(13).fontColor('#78909C').margin({ bottom: 5 })
              .width('100%')
            Select([{ value: '开启' } as SelectOption, { value: '关闭' } as SelectOption])
              .selected(0)
              .value(this.dAction === 'turn_on' ? '开启' : '关闭')
              .onSelect((index: number) => {
                this.dAction = index === 0 ? 'turn_on' : 'turn_off';
              })
              .height(40).width('100%').margin({ bottom: 10 })

            Text('执行时间').fontSize(13).fontColor('#78909C').margin({ bottom: 5 })
              .width('100%')
            Row() {
              TextInput({ placeholder: '时', text: this.dHour.toString() })
                .onChange((value: string) => { this.dHour = parseInt(value) || 0; })
                .width(60).height(40).backgroundColor('#F5F5F5').borderRadius(8)
                .type(InputType.Number)
              Text(':').fontSize(20).margin({ left: 8, right: 8 })
              TextInput({ placeholder: '分', text: this.dMinute.toString() })
                .onChange((value: string) => { this.dMinute = parseInt(value) || 0; })
                .width(60).height(40).backgroundColor('#F5F5F5').borderRadius(8)
                .type(InputType.Number)
            }.margin({ bottom: 10 })

            Text('重复日 (逗号分隔 1-7, 空=每天)')
              .fontSize(13).fontColor('#78909C').margin({ bottom: 5 }).width('100%')
            TextInput({ placeholder: '1,2,3,4,5,6,7', text: this.dRepeatDays })
              .onChange((value: string) => { this.dRepeatDays = value; })
              .height(40).backgroundColor('#F5F5F5').borderRadius(8).margin({ bottom: 15 })

            Row() {
              Button('取消').fontSize(14).fontColor('#78909C').backgroundColor('#F5F5F5')
                .borderRadius(20).height(38).layoutWeight(1).margin({ right: 10 })
                .onClick(() => { this.showCreateDialog = false; this.resetDialog(); })
              Button('创建').fontSize(14).fontColor('#FFFFFF').backgroundColor('#4CAF50')
                .borderRadius(20).height(38).layoutWeight(1)
                .onClick(async () => { await this.doCreate(); })
            }.width('100%')
          }
          .width('100%').padding(24).backgroundColor('#FFFFFF').borderRadius(16)
        }
        .width('85%')
        .constraintSize({ maxHeight: '70%' })
        .position({ x: '7.5%', y: '10%' })
        .shadow({ radius: 20, color: 'rgba(0,0,0,0.15)', offsetY: 5 })
      }
    }
    .width('100%').height('100%')
  }
}
