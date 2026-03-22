import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService, NodeListItem, AdminUserInfo } from '../services/HttpService';

@Entry
@Component
struct AdminPage {
  @State currentTab: number = 0;
  @State nodes: NodeListItem[] = [];
  @State users: AdminUserInfo[] = [];
  @State isLoading: boolean = false;
  @StorageLink('userRole') myRole: string = 'user';

  // --- 节点弹窗 ---
  @State showAddDialog: boolean = false;
  @State showEditDialog: boolean = false;
  @State dialogNodeId: string = '';
  @State dialogNodeName: string = '';
  @State editingNodeId: string = '';

  async aboutToAppear() {
    await this.refreshAll();
  }

  private async refreshAll() {
    this.isLoading = true;
    await this.loadNodes();
    await this.loadUsers();
    this.isLoading = false;
  }

  private async loadNodes() {
    let list = await HttpService.getInstance().getNodes();
    if (list) {
      this.nodes = list;
    }
  }

  private async loadUsers() {
    let list = await HttpService.getInstance().adminListUsers();
    if (list) {
      this.users = list;
    }
  }

  // ===== 节点操作 =====
  private async doAddNode() {
    if (!this.dialogNodeId.trim() || !this.dialogNodeName.trim()) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }
    let ok = await HttpService.getInstance().adminCreateNode(
      this.dialogNodeId.trim(), this.dialogNodeName.trim());
    if (ok) {
      promptAction.showToast({ message: '创建成功' });
      this.showAddDialog = false;
      this.dialogNodeId = '';
      this.dialogNodeName = '';
      await this.loadNodes();
    } else {
      promptAction.showToast({ message: '创建失败（节点ID可能已存在）' });
    }
  }

  private async doEditNode() {
    if (!this.dialogNodeName.trim()) {
      promptAction.showToast({ message: '名称不能为空' });
      return;
    }
    let ok = await HttpService.getInstance().adminUpdateNode(
      this.editingNodeId, this.dialogNodeName.trim());
    if (ok) {
      promptAction.showToast({ message: '更新成功' });
      this.showEditDialog = false;
      this.dialogNodeName = '';
      await this.loadNodes();
    } else {
      promptAction.showToast({ message: '更新失败' });
    }
  }

  private confirmDeleteNode(nodeId: string) {
    AlertDialog.show({
      title: '确认删除',
      message: `确定删除节点 ${nodeId}？此操作不可恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#F44336',
        action: async () => {
          let ok = await HttpService.getInstance().adminDeleteNode(nodeId);
          if (ok) {
            promptAction.showToast({ message: '已删除' });
            await this.loadNodes();
          } else {
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    });
  }

  // ===== 用户操作 =====
  private confirmChangeRole(user: AdminUserInfo) {
    let newRole = user.role === 'admin' ? 'user' : 'admin';
    let action = newRole === 'admin' ? '提升为管理员' : '降为普通用户';
    AlertDialog.show({
      title: '修改角色',
      message: `确定将「${user.userName || user.phone}」${action}？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确认',
        action: async () => {
          let ok = await HttpService.getInstance().adminUpdateUserRole(user.id, newRole);
          if (ok) {
            promptAction.showToast({ message: '角色已更新' });
            await this.loadUsers();
          } else {
            promptAction.showToast({ message: '操作失败' });
          }
        }
      }
    });
  }

  build() {
    Stack() {
      Column() {
        // ===== 顶部导航 =====
        Row() {
          Text('←')
            .fontSize(22)
            .fontColor('#4CAF50')
            .onClick(() => router.back())
            .width(40)
          Text('管理后台')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2C3E50')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          // 占位平衡
          Text('').width(40)
        }
        .width('100%')
        .height(56)
        .padding({ left: 15, right: 15 })
        .backgroundColor('#FFFFFF')

        // ===== Tab 栏 =====
        Row() {
          this.TabButton('节点管理', 0)
          this.TabButton('用户管理', 1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 5 })
        .backgroundColor('#FFFFFF')

        // ===== 内容区 =====
        if (this.currentTab === 0) {
          this.NodeManageTab()
        } else {
          this.UserManageTab()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F6F3')

      // ===== 新增节点弹窗 =====
      if (this.showAddDialog) {
        this.DialogOverlay('新增节点', true)
      }
      // ===== 编辑节点弹窗 =====
      if (this.showEditDialog) {
        this.DialogOverlay('编辑节点', false)
      }
    }
    .width('100%')
    .height('100%')
  }

  // ===== Tab 按钮 =====
  @Builder TabButton(label: string, index: number) {
    Text(label)
      .fontSize(15)
      .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentTab === index ? '#4CAF50' : '#90A4AE')
      .padding({ left: 20, right: 20, top: 10, bottom: 10 })
      .borderRadius(20)
      .backgroundColor(this.currentTab === index ? '#E8F5E9' : Color.Transparent)
      .onClick(() => { this.currentTab = index; })
  }

  // ===== 节点管理 Tab =====
  @Builder NodeManageTab() {
    Column() {
      // 标题 + 新增按钮
      Row() {
        Text(`共 ${this.nodes.length} 个节点`)
          .fontSize(14)
          .fontColor('#78909C')
        Blank()
        Button('+ 新增')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#4CAF50')
          .borderRadius(20)
          .height(34)
          .onClick(() => {
            this.dialogNodeId = '';
            this.dialogNodeName = '';
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 10 })

      if (this.nodes.length === 0 && !this.isLoading) {
        Column() {
          Blank()
          Text('暂无节点')
            .fontSize(16)
            .fontColor('#B0BEC5')
          Blank()
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.nodes, (node: NodeListItem) => {
            ListItem() {
              Row() {
                // 状态指示
                Circle({ width: 10, height: 10 })
                  .fill(node.status === 'online' ? '#4CAF50' : '#BDBDBD')
                  .margin({ right: 12 })
                // 信息
                Column() {
                  Text(node.id)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#2C3E50')
                  Text(node.name)
                    .fontSize(13)
                    .fontColor('#78909C')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 编辑
                Text('编辑')
                  .fontSize(13)
                  .fontColor('#4CAF50')
                  .padding(8)
                  .onClick(() => {
                    this.editingNodeId = node.id;
                    this.dialogNodeName = node.name;
                    this.showEditDialog = true;
                  })
                // 删除
                Text('删除')
                  .fontSize(13)
                  .fontColor('#F44336')
                  .padding(8)
                  .onClick(() => this.confirmDeleteNode(node.id))
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 15, right: 15 })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  // ===== 用户管理 Tab =====
  @Builder UserManageTab() {
    Column() {
      Row() {
        Text(`共 ${this.users.length} 个用户`)
          .fontSize(14)
          .fontColor('#78909C')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 10 })

      if (this.users.length === 0 && !this.isLoading) {
        Column() {
          Blank()
          Text('暂无用户数据')
            .fontSize(16)
            .fontColor('#B0BEC5')
          Blank()
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.users, (user: AdminUserInfo) => {
            ListItem() {
              Row() {
                // 用户信息
                Column() {
                  Text(user.userName || '未命名')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#2C3E50')
                  Text(user.phone)
                    .fontSize(13)
                    .fontColor('#78909C')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 角色标签
                Text(user.role === 'admin' ? '管理员' : '普通用户')
                  .fontSize(12)
                  .fontColor(user.role === 'admin' ? '#E65100' : '#4CAF50')
                  .backgroundColor(user.role === 'admin' ? '#FFF3E0' : '#E8F5E9')
                  .borderRadius(12)
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .onClick(() => this.confirmChangeRole(user))
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 15, right: 15 })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  // ===== 弹窗 Overlay =====
  @Builder DialogOverlay(title: string, isAdd: boolean) {
    Column() {
      // 遮罩
      Blank()
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(0,0,0,0.4)')
    .onClick(() => {
      this.showAddDialog = false;
      this.showEditDialog = false;
    })

    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2C3E50')
        .margin({ bottom: 20 })

      if (isAdd) {
        TextInput({ placeholder: '节点 ID（如 A03_Node_03）', text: this.dialogNodeId })
          .onChange((value: string) => { this.dialogNodeId = value; })
          .height(44)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ bottom: 12 })
      }

      TextInput({ placeholder: '节点名称', text: this.dialogNodeName })
        .onChange((value: string) => { this.dialogNodeName = value; })
        .height(44)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .margin({ bottom: 20 })

      Row() {
        Button('取消')
          .fontSize(14)
          .fontColor('#78909C')
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .height(38)
          .layoutWeight(1)
          .margin({ right: 10 })
          .onClick(() => {
            this.showAddDialog = false;
            this.showEditDialog = false;
          })
        Button('确定')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#4CAF50')
          .borderRadius(20)
          .height(38)
          .layoutWeight(1)
          .onClick(async () => {
            if (isAdd) {
              await this.doAddNode();
            } else {
              await this.doEditNode();
            }
          })
      }
      .width('100%')
    }
    .width('85%')
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .position({ x: '7.5%', y: '30%' })
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.15)', offsetY: 5 })
  }
}
