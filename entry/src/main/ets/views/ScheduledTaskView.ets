import { promptAction } from '@kit.ArkUI';
import {
  HttpService,
  ScheduledTaskItem,
  CreateTaskRequest,
  NodeListItem
} from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow, AppSize } from '../common/DesignToken';

@Component
export struct ScheduledTaskView {
  @State tasks: ScheduledTaskItem[] = [];
  @State nodes: NodeListItem[] = [];
  @State isLoading: boolean = false;
  @State showCreateDialog: boolean = false;

  @State dTaskName: string = '';
  @State dNodeId: string = '';
  @State dEquipmentKey: string = 'water_pump';
  @State dAction: string = 'turn_on';
  @State dBrightness: number = 100;
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
        fontColor: AppColors.AlertCritical,
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
    this.dTaskName = '';
    this.dEquipmentKey = 'water_pump';
    this.dAction = 'turn_on';
    this.dBrightness = 100;
    this.dHour = 8;
    this.dMinute = 0;
    this.dRepeatDays = '1,2,3,4,5,6,7';
  }

  formatTime(hour: number, minute: number): string {
    return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
  }

  formatRepeatDays(days: string): string {
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

  @Builder
  TaskCard(task: ScheduledTaskItem) {
    Column() {
      Row() {
        Column() {
          Text(task.taskName)
            .fontSize(AppFontSize.H3)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TextPrimary)
          Text(`${this.getEquipmentName(task.equipmentKey)} · ${task.action === 'turn_on' ? '开启' : task.action === 'set_brightness' ? '亮度调节' : '关闭'}`)
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.TextSecondary)
            .margin({ top: AppSpacing.XS })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: task.enabled })
          .selectedColor(AppColors.Primary)
          .onChange((isOn: boolean) => { this.toggleTask(task.id); })
          .width(50).height(28)
      }
      .width('100%')

      Row() {
        // 大时间数字
        Text(this.formatTime(task.hour, task.minute))
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(task.enabled ? AppColors.Primary : AppColors.TextTertiary)

        Blank()

        Column() {
          Row() {
            Text('🔁')
              .fontSize(AppFontSize.Caption)
              .margin({ right: AppSpacing.XS })
            Text(this.formatRepeatDays(task.repeatDays))
              .fontSize(AppFontSize.Caption)
              .fontColor(AppColors.TextTertiary)
          }

          Row() {
            Text('📍')
              .fontSize(AppFontSize.Caption)
              .margin({ right: AppSpacing.XS })
            Text(task.nodeId)
              .fontSize(AppFontSize.Caption)
              .fontColor(AppColors.TextTertiary)
          }
          .margin({ top: AppSpacing.XS })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .margin({ top: AppSpacing.MD })
      .alignItems(VerticalAlign.Bottom)

      // 底部操作条
      Row() {
        Blank()
        Text('删除')
          .fontSize(AppFontSize.Caption)
          .fontColor(AppColors.AlertCritical)
          .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: AppSpacing.XS, bottom: AppSpacing.XS })
          .borderRadius(AppRadius.SM)
          .onClick(() => { this.confirmDelete(task); })
      }
      .width('100%')
      .margin({ top: AppSpacing.SM })
    }
    .width('100%')
    .padding(AppSpacing.CardPadding)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
    .opacity(task.enabled ? 1.0 : 0.55)
  }

  @Builder
  CreateDialog() {
    Column() {
      Blank()
        .width('100%')
        .height('100%')
        .onClick(() => { this.showCreateDialog = false; })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor(AppColors.OverlayBg)

    Scroll() {
      Column() {
        Text('新建定时任务')
          .fontSize(AppFontSize.H2)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TextPrimary)
          .margin({ bottom: AppSpacing.LG })

        TextInput({ placeholder: '任务名称', text: this.dTaskName })
          .onChange((value: string) => { this.dTaskName = value; })
          .height(AppSize.InputHeight)
          .backgroundColor(AppColors.Background)
          .borderRadius(AppRadius.SM)
          .margin({ bottom: AppSpacing.MD })

        Text('选择节点').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
          .margin({ bottom: AppSpacing.XS }).width('100%')
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
          .height(40).width('100%').margin({ bottom: AppSpacing.MD })

        Text('设备').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
          .margin({ bottom: AppSpacing.XS }).width('100%')
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
          .height(40).width('100%').margin({ bottom: AppSpacing.MD })

        Text('操作').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
          .margin({ bottom: AppSpacing.XS }).width('100%')
        if (this.dEquipmentKey === 'led_light') {
          Select([
            { value: '开启' } as SelectOption,
            { value: '关闭' } as SelectOption,
            { value: '设置亮度' } as SelectOption
          ])
            .selected(this.dAction === 'turn_on' ? 0 : this.dAction === 'turn_off' ? 1 : 2)
            .value(this.dAction === 'turn_on' ? '开启' : this.dAction === 'turn_off' ? '关闭' : '设置亮度')
            .onSelect((index: number) => {
              if (index === 0) {
                this.dAction = 'turn_on';
              } else if (index === 1) {
                this.dAction = 'turn_off';
              } else {
                this.dAction = 'set_brightness';
              }
            })
            .height(40).width('100%').margin({ bottom: AppSpacing.MD })

          if (this.dAction === 'set_brightness') {
            Text('亮度 ' + this.dBrightness + '%')
              .fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
              .margin({ bottom: AppSpacing.XS }).width('100%')
            Slider({
              value: this.dBrightness,
              min: 1,
              max: 100,
              step: 1,
              style: SliderStyle.OutSet
            })
              .blockColor(AppColors.Primary)
              .trackColor(AppColors.Divider)
              .selectedColor(AppColors.PrimaryLight)
              .width('100%')
              .onChange((value: number, mode: SliderChangeMode) => {
                this.dBrightness = Math.round(value);
              })
              .margin({ bottom: AppSpacing.MD })
          }
        } else {
          Select([{ value: '开启' } as SelectOption, { value: '关闭' } as SelectOption])
            .selected(0)
            .value(this.dAction === 'turn_on' ? '开启' : '关闭')
            .onSelect((index: number) => {
              this.dAction = index === 0 ? 'turn_on' : 'turn_off';
            })
            .height(40).width('100%').margin({ bottom: AppSpacing.MD })
        }

        Text('执行时间').fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
          .margin({ bottom: AppSpacing.XS }).width('100%')
        Row() {
          TextInput({ placeholder: '时', text: this.dHour.toString() })
            .onChange((value: string) => { this.dHour = parseInt(value) || 0; })
            .width(60).height(40).backgroundColor(AppColors.Background).borderRadius(AppRadius.SM)
            .type(InputType.Number)
          Text(':').fontSize(AppFontSize.H2).margin({ left: AppSpacing.SM, right: AppSpacing.SM })
          TextInput({ placeholder: '分', text: this.dMinute.toString() })
            .onChange((value: string) => { this.dMinute = parseInt(value) || 0; })
            .width(60).height(40).backgroundColor(AppColors.Background).borderRadius(AppRadius.SM)
            .type(InputType.Number)
        }.margin({ bottom: AppSpacing.MD })

        Text('重复日 (逗号分隔 1-7, 空=每天)')
          .fontSize(AppFontSize.Caption).fontColor(AppColors.TextSecondary)
          .margin({ bottom: AppSpacing.XS }).width('100%')
        TextInput({ placeholder: '1,2,3,4,5,6,7', text: this.dRepeatDays })
          .onChange((value: string) => { this.dRepeatDays = value; })
          .height(40).backgroundColor(AppColors.Background).borderRadius(AppRadius.SM)
          .margin({ bottom: AppSpacing.LG })

        Row() {
          Button('取消').fontSize(AppFontSize.Body).fontColor(AppColors.TextSecondary)
            .backgroundColor(AppColors.Background)
            .borderRadius(AppRadius.Full).height(AppSize.ButtonHeightSM).layoutWeight(1)
            .margin({ right: AppSpacing.MD })
            .onClick(() => { this.showCreateDialog = false; this.resetDialog(); })
          Button('创建').fontSize(AppFontSize.Body).fontColor(AppColors.TextOnPrimary)
            .backgroundColor(AppColors.Primary)
            .borderRadius(AppRadius.Full).height(AppSize.ButtonHeightSM).layoutWeight(1)
            .onClick(async () => { await this.doCreate(); })
        }.width('100%')
      }
      .width('100%')
      .padding(AppSpacing.XXL)
      .backgroundColor(AppColors.Surface)
      .borderRadius(AppRadius.XL)
    }
    .width('85%')
    .constraintSize({ maxHeight: '70%' })
    .position({ x: '7.5%', y: '10%' })
    .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.ElevatedColor, offsetY: AppShadow.ElevatedOffsetY })
  }

  build() {
    Stack() {
      Column() {
        // Header 行
        Row() {
          Text('定时任务')
            .fontSize(AppFontSize.H2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
          Blank()
          Button('+ 新建', { type: ButtonType.Capsule })
            .height(AppSize.ButtonHeightSM)
            .fontSize(AppFontSize.Body)
            .backgroundColor(AppColors.Primary)
            .onClick(() => { this.showCreateDialog = true; })
        }
        .width('100%')
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding,
          top: AppSpacing.MD, bottom: AppSpacing.MD })

        if (this.tasks.length === 0 && !this.isLoading) {
          Column() {
            Text('⏰').fontSize(48).margin({ bottom: AppSpacing.MD })
            Text('暂无定时任务')
              .fontSize(AppFontSize.H3).fontColor(AppColors.TextTertiary)
            Text('点击「+ 新建」创建定时任务')
              .fontSize(AppFontSize.Caption).fontColor(AppColors.TextTertiary)
              .margin({ top: AppSpacing.SM })
          }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          List({ space: AppSpacing.MD }) {
            ForEach(this.tasks, (task: ScheduledTaskItem) => {
              ListItem() {
                this.TaskCard(task)
              }
            }, (task: ScheduledTaskItem) => task.id.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding, top: AppSpacing.MD })
        }
      }
      .width('100%')
      .height('100%')

      if (this.showCreateDialog) {
        this.CreateDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}
