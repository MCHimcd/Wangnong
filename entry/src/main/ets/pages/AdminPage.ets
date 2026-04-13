import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import { HttpService, NodeListItem, AdminUserInfo, OperationLogItem, OperationLogPage } from '../services/HttpService';
import { AppColors, AppFontSize, AppSpacing, AppRadius, AppShadow } from '../common/DesignToken';

/**
 * Purpose: 提供管理员使用的节点管理、用户角色管理、节点授权和操作日志查看入口。
 * Responsibilities: 在单页内切换三个管理 Tab，组织节点 CRUD、用户角色变更、节点访问授权和日志分页加载。
 * Flow: aboutToAppear() 触发 refreshAll()；页面把节点、用户和日志数据加载到本地状态，再由不同 Tab 渲染对应管理界面。
 * Dependencies: 依赖 HttpService 的管理员接口和 DesignToken。
 * Input: 当前管理员角色、各管理动作触发的表单输入与节点/用户选择。
 * Output: 管理后台 UI，以及创建节点、改角色、保存授权等后台请求。
 * Boundary: 该页假定调用方已完成管理员权限控制；页面内部不再做二次鉴权跳转。
 */
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

  // --- 操作日志 ---
  @State opLogs: OperationLogItem[] = [];
  @State opLogPage: number = 1;
  @State opLogTotal: number = 0;

  // --- 用户节点授权 ---
  @State showNodeAccessDialog: boolean = false;
  @State nodeAccessUserId: number = 0;
  @State nodeAccessUserName: string = '';
  @State nodeAccessIds: string[] = [];
  @State allNodeIds: string[] = [];

  async aboutToAppear() {
    await this.refreshAll();
  }

  private async refreshAll() {
    // Flow: 首屏统一串行刷新三类数据，保证节点授权弹窗拿到的 allNodeIds 与用户列表处于同一快照。
    this.isLoading = true;
    await this.loadNodes();
    await this.loadUsers();
    await this.loadOpLogs();
    this.isLoading = false;
  }

  private async loadNodes() {
    let list = await HttpService.getInstance().getNodes();
    if (list) {
      this.nodes = list;
      this.allNodeIds = list.map((n: NodeListItem) => n.id);
    }
  }

  private async loadUsers() {
    let list = await HttpService.getInstance().adminListUsers();
    if (list) {
      this.users = list;
    }
  }

  private async loadOpLogs() {
    let result = await HttpService.getInstance().getOperationLogs(this.opLogPage);
    if (result) {
      this.opLogs = result.items;
      this.opLogTotal = result.total;
    }
  }

  private async openNodeAccess(user: AdminUserInfo) {
    // Flow: 先记录当前用户，再拉取其已授权节点，最后打开弹窗，避免弹窗先显示后补数据导致闪动。
    this.nodeAccessUserId = user.id;
    this.nodeAccessUserName = user.userName || user.phone;
    let ids = await HttpService.getInstance().adminGetUserNodes(user.id);
    this.nodeAccessIds = ids ? ids : [];
    this.showNodeAccessDialog = true;
  }

  private async saveNodeAccess() {
    // Reason: 节点授权单独走保存动作，避免在勾选过程中频繁写后端。
    let ok = await HttpService.getInstance().adminSetUserNodes(this.nodeAccessUserId, this.nodeAccessIds);
    if (ok) {
      promptAction.showToast({ message: '授权已保存' });
      this.showNodeAccessDialog = false;
    } else {
      promptAction.showToast({ message: '保存失败' });
    }
  }

  private toggleNodeAccess(nodeId: string) {
    let idx = this.nodeAccessIds.indexOf(nodeId);
    if (idx >= 0) {
      this.nodeAccessIds = this.nodeAccessIds.filter((id: string) => id !== nodeId);
    } else {
      this.nodeAccessIds = [...this.nodeAccessIds, nodeId];
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
    // Boundary: 编辑模式只允许改名称，不允许修改节点 ID，避免现有设备绑定和主题命名失效。
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
    // Forbidden: 删除节点不可恢复，因此先通过确认框阻断误操作，再发真正删除请求。
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
          Image($r('sys.media.ohos_ic_back'))
            .width(24).height(24)
            .fillColor(AppColors.Primary)
            .onClick(() => router.back())
            .margin({ right: AppSpacing.SM })
          Text('管理后台')
            .fontSize(AppFontSize.H2)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TextPrimary)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          // 占位平衡
          Text('').width(30)
        }
        .width('100%')
        .height(56)
        .padding({ left: AppSpacing.PagePadding, right: AppSpacing.PagePadding })
        .backgroundColor(AppColors.Surface)
        .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })

        // ===== Tab 栏 =====
        Row() {
          this.TabButton('节点管理', 0)
          this.TabButton('用户管理', 1)
          this.TabButton('操作日志', 2)
        }
        .width('100%')
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.SM, bottom: AppSpacing.XS })
        .backgroundColor(AppColors.Surface)

        // ===== 内容区 =====
        if (this.currentTab === 0) {
          this.NodeManageTab()
        } else if (this.currentTab === 1) {
          this.UserManageTab()
        } else {
          this.OpLogTab()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.Background)

      // ===== 新增节点弹窗 =====
      if (this.showAddDialog) {
        this.DialogOverlay('新增节点', true)
      }
      // ===== 编辑节点弹窗 =====
      if (this.showEditDialog) {
        this.DialogOverlay('编辑节点', false)
      }
      // ===== 节点授权弹窗 =====
      if (this.showNodeAccessDialog) {
        this.NodeAccessDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ===== Tab 按钮 =====
  @Builder TabButton(label: string, index: number) {
    Text(label)
      .fontSize(AppFontSize.Body)
      .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentTab === index ? AppColors.Primary : AppColors.TextTertiary)
      .padding({ left: AppSpacing.LG, right: AppSpacing.LG, top: AppSpacing.SM, bottom: AppSpacing.SM })
      .borderRadius(AppRadius.Full)
      .backgroundColor(this.currentTab === index ? AppColors.SuccessBg : Color.Transparent)
      .onClick(() => { this.currentTab = index; })
  }

  // ===== 节点管理 Tab =====
  @Builder NodeManageTab() {
    Column() {
      // 标题 + 新增按钮
      Row() {
        Text(`共 ${this.nodes.length} 个节点`)
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
        Blank()
        Button('+ 新增')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextOnPrimary)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.Full)
          .height(34)
          .onClick(() => {
            this.dialogNodeId = '';
            this.dialogNodeName = '';
            this.showAddDialog = true;
          })
      }
      .width('100%')
      .padding({ left: AppSpacing.XL, right: AppSpacing.XL, top: AppSpacing.LG, bottom: AppSpacing.SM })

      if (this.nodes.length === 0 && !this.isLoading) {
        Column() {
          Blank()
          Text('暂无节点')
            .fontSize(AppFontSize.H3)
            .fontColor(AppColors.TextTertiary)
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
                  .fill(node.status === 'online' ? AppColors.Success : AppColors.Border)
                  .margin({ right: AppSpacing.MD })
                // 信息
                Column() {
                  Text(node.id)
                    .fontSize(AppFontSize.Body)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary)
                  Text(node.name)
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextTertiary)
                    .margin({ top: AppSpacing.XS })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 编辑
                Text('编辑')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.Primary)
                  .padding(AppSpacing.SM)
                  .onClick(() => {
                    this.editingNodeId = node.id;
                    this.dialogNodeName = node.name;
                    this.showEditDialog = true;
                  })
                // 删除
                Text('删除')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.AlertCritical)
                  .padding(AppSpacing.SM)
                  .onClick(() => this.confirmDeleteNode(node.id))
              }
              .width('100%')
              .padding(AppSpacing.PagePadding)
              .backgroundColor(AppColors.Surface)
              .borderRadius(AppRadius.MD)
              .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
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
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
      }
      .width('100%')
      .padding({ left: AppSpacing.XL, right: AppSpacing.XL, top: AppSpacing.LG, bottom: AppSpacing.SM })

      if (this.users.length === 0 && !this.isLoading) {
        Column() {
          Blank()
          Text('暂无用户数据')
            .fontSize(AppFontSize.H3)
            .fontColor(AppColors.TextTertiary)
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
                    .fontSize(AppFontSize.Body)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TextPrimary)
                  Text(user.phone)
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextTertiary)
                    .margin({ top: AppSpacing.XS })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 节点授权
                Text('授权')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.Accent)
                  .backgroundColor(AppColors.AlertInfoBg)
                  .borderRadius(AppRadius.MD)
                  .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 5, bottom: 5 })
                  .margin({ right: AppSpacing.SM })
                  .onClick(() => this.openNodeAccess(user))

                // 角色标签
                Text(user.role === 'admin' ? '管理员' : '普通用户')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(user.role === 'admin' ? AppColors.AlertWarning : AppColors.Primary)
                  .backgroundColor(user.role === 'admin' ? AppColors.AlertWarningBg : AppColors.SuccessBg)
                  .borderRadius(AppRadius.MD)
                  .padding({ left: AppSpacing.MD, right: AppSpacing.MD, top: 5, bottom: 5 })
                  .onClick(() => this.confirmChangeRole(user))
              }
              .width('100%')
              .padding(AppSpacing.PagePadding)
              .backgroundColor(AppColors.Surface)
              .borderRadius(AppRadius.MD)
              .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  // ===== 弹窗 Overlay =====
  @Builder DialogOverlay(title: string, isAdd: boolean) {
    Column() {
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
        .fontSize(AppFontSize.H2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.XL })

      if (isAdd) {
        TextInput({ placeholder: '节点 ID（如 A03_Node_03）', text: this.dialogNodeId })
          .onChange((value: string) => { this.dialogNodeId = value; })
          .height(44)
          .backgroundColor(AppColors.Background)
          .borderRadius(AppRadius.SM)
          .margin({ bottom: AppSpacing.MD })
      }

      TextInput({ placeholder: '节点名称', text: this.dialogNodeName })
        .onChange((value: string) => { this.dialogNodeName = value; })
        .height(44)
        .backgroundColor(AppColors.Background)
        .borderRadius(AppRadius.SM)
        .margin({ bottom: AppSpacing.XL })

      Row() {
        Button('取消')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .backgroundColor(AppColors.Background)
          .borderRadius(AppRadius.Full)
          .height(38)
          .layoutWeight(1)
          .margin({ right: AppSpacing.SM })
          .onClick(() => {
            this.showAddDialog = false;
            this.showEditDialog = false;
          })
        Button('确定')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextOnPrimary)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.Full)
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
    .padding(AppSpacing.XXL)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .position({ x: '7.5%', y: '30%' })
    .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.ElevatedColor, offsetY: AppShadow.ElevatedOffsetY })
  }

  // ===== 操作日志 Tab =====
  @Builder OpLogTab() {
    Column() {
      Row() {
        Text(`共 ${this.opLogTotal} 条日志`)
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
        Blank()
        if (this.opLogPage > 1) {
          Text('上一页')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.Primary)
            .padding(AppSpacing.SM)
            .onClick(async () => {
              this.opLogPage -= 1;
              await this.loadOpLogs();
            })
        }
        if (this.opLogs.length >= 20) {
          Text('下一页')
            .fontSize(AppFontSize.Caption)
            .fontColor(AppColors.Primary)
            .padding(AppSpacing.SM)
            .onClick(async () => {
              this.opLogPage += 1;
              await this.loadOpLogs();
            })
        }
      }
      .width('100%')
      .padding({ left: AppSpacing.XL, right: AppSpacing.XL, top: AppSpacing.LG, bottom: AppSpacing.SM })

      if (this.opLogs.length === 0 && !this.isLoading) {
        Column() {
          Blank()
          Text('暂无操作日志')
            .fontSize(AppFontSize.H3)
            .fontColor(AppColors.TextTertiary)
          Blank()
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.opLogs, (log: OperationLogItem) => {
            ListItem() {
              Column() {
                Row() {
                  Text(log.operationType)
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextOnPrimary)
                    .backgroundColor(AppColors.TextSecondary)
                    .borderRadius(AppRadius.SM)
                    .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 3, bottom: 3 })
                  Text(log.userName || '-')
                    .fontSize(AppFontSize.Caption)
                    .fontColor(AppColors.TextPrimary)
                    .margin({ left: AppSpacing.SM })
                    .layoutWeight(1)
                  Text(log.createdAt || '')
                    .fontSize(AppFontSize.Mini)
                    .fontColor(AppColors.TextTertiary)
                }
                .width('100%')
                .margin({ bottom: 6 })

                Text(log.detail || '-')
                  .fontSize(AppFontSize.Caption)
                  .fontColor(AppColors.TextSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .width('100%')
              .padding(AppSpacing.LG)
              .backgroundColor(AppColors.Surface)
              .borderRadius(AppRadius.MD)
              .shadow({ radius: AppShadow.CardRadius, color: AppShadow.CardColor, offsetY: AppShadow.CardOffsetY })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: AppSpacing.LG, right: AppSpacing.LG })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  // ===== 节点授权弹窗 =====
  @Builder NodeAccessDialog() {
    Column() {
      Blank()
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .backgroundColor('rgba(0,0,0,0.4)')
    .onClick(() => { this.showNodeAccessDialog = false; })

    Column() {
      Text(`节点授权 - ${this.nodeAccessUserName}`)
        .fontSize(AppFontSize.H2)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TextPrimary)
        .margin({ bottom: AppSpacing.LG })

      if (this.allNodeIds.length === 0) {
        Text('暂无可授权节点')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .margin({ bottom: AppSpacing.XL })
      } else {
        List({ space: 8 }) {
          ForEach(this.allNodeIds, (nodeId: string) => {
            ListItem() {
              Row() {
                Text(nodeId)
                  .fontSize(AppFontSize.Body)
                  .fontColor(AppColors.TextPrimary)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.nodeAccessIds.includes(nodeId) })
                  .onChange((isOn: boolean) => {
                    this.toggleNodeAccess(nodeId);
                  })
              }
              .width('100%')
              .padding({ left: AppSpacing.SM, right: AppSpacing.SM, top: 6, bottom: 6 })
            }
          })
        }
        .width('100%')
        .height(200)
        .margin({ bottom: AppSpacing.LG })
      }

      Row() {
        Button('取消')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextTertiary)
          .backgroundColor(AppColors.Background)
          .borderRadius(AppRadius.Full)
          .height(38)
          .layoutWeight(1)
          .margin({ right: AppSpacing.SM })
          .onClick(() => { this.showNodeAccessDialog = false; })
        Button('保存')
          .fontSize(AppFontSize.Body)
          .fontColor(AppColors.TextOnPrimary)
          .backgroundColor(AppColors.Primary)
          .borderRadius(AppRadius.Full)
          .height(38)
          .layoutWeight(1)
          .onClick(async () => { await this.saveNodeAccess(); })
      }
      .width('100%')
    }
    .width('85%')
    .padding(AppSpacing.XXL)
    .backgroundColor(AppColors.Surface)
    .borderRadius(AppRadius.LG)
    .position({ x: '7.5%', y: '25%' })
    .shadow({ radius: AppShadow.ElevatedRadius, color: AppShadow.ElevatedColor, offsetY: AppShadow.ElevatedOffsetY })
  }
}
